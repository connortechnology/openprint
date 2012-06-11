use strict;
require Date::Parse;
require Date::Format;
require openprint::Event_Category;
require openprint::Comment;
require openprint::Event_Attendance;
require openprint::Event_Invitation;

package openprint::Event;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );
$debug = 1;
$table = 'events';
$serial = 'events_id_seq';

%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'created_by'	=>	'created_by',
	'starting_on'	=>	'starting_on',
	'ending_on'		=>	'ending_on',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'deleted'		=>	'deleted',
	'location_id'	=>	'location_id',
	'info'			=>	'info',
	'time_associated'	=>	'time_associated',
	'category_id'	=>	'category_id',
	'category'		=>	undef,
	#'asset_id'		=>	'asset_id',
	# Photo album for the event, created on first photo upload
	'album_id'		=>	'album_id', 
);
%find_fields = (
	'attending'=>	'(SELECT user_id FROM event_attendance WHERE event_id=events.id AND attending=true)',
	#'attending'=>	'(SELECT attending FROM event_attendance WHERE event_id=events.id)',
	'name+info'	=>	q`name || info`,
);

%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'starting_on'	=>	undef,
	'ending_on'		=>	undef,
	'location_id'	=>	undef,
	#'asset_id'		=>	undef,
	'time_associated'	=> 0,
	'created_by'		=> q`$openprint::session{'user_id'}`,
	'deleted'			=> 0,
);

sub category {
	if ( @_ > 1 ) {
		my $new = openprint::Event_Category->transform('name',$_[1]);
		if ( $new ) {
			my $Category = openprint::Event_Category->find_one('name lc'=>lc $new );
			if ( ! $Category ) {
				$Category = new openprint::Event_Category();
				$Category->save({'name'=>$_[1]})
			} # end if	
			$_[0]{'category_id'} = $Category->id();
			return $Category->name();
		} else {
			$_[0]{'category_id'} = undef;
		} # end if	
	} # end if
	return new openprint::Event_Category( $_[0]{'category_id'} )->name();
} # end sub category
sub Category {
	return new openprint::Event_Category( $_[0]{'category_id'} );
} # end sub Category

sub where {
	if ( ! $_[0]{'where'} ) {
		my $L = $_[0]->Location();
		$_[0]{'where'} .= '<a href="/location/view.html?location_id='.$L->id().'">';
		$_[0]{'where'} .= $L->name().'<br/>';
		if ( $L->address() or $L->postalcode() ) {
			$_[0]{'where'} .= $L->address() . ', '.$L->postalcode().'<br/>';
		} # end if
		$_[0]{'where'} .= join(', ', map { $_->name() } $L->Parents() );
		$_[0]{'where'} .= '</a>';
		if ( $L->url() ) {
			$_[0]{'where'} .= '<br/><a target="_blank" href="'.$L->url().'">'.$L->url().'</a>';
		} # end if
	} # end if
	return $_[0]{'where'};
} # end sub where

sub Asset {
	if ( ! $_[0]{'Asset'} ) {
		my $Album = $_[0]->Album();
		if ( $$Album{'thumbnail_id'} ) {
			$_[0]{'Asset'} = new openprint::Asset( $$Album{'thumbnail_id'} );
		} elsif ( my @Photos = $Album->Photos() ) {
			$_[0]{'Asset'} = $Photos[0]->Asset();;
		} else {
			$_[0]{'Asset'} = new openprint::Asset();
		} # end if
	} # end if
	return $_[0]{'Asset'};
} # end sub Asset

sub location {
	if ( @_ > 1 ) {
		my $Location = openprint::Location->find_one('name_lc'=>lc $_[1]);
		if ( ! $Location ) {
			$Location = new openprint::Location();
			$Location->save({'name'=>$_[1]});
		} # end if
		$_[0]{'location_id'} = $Location->id();
		return $Location->name();
	} # end if
	return new openprint::Location( $_[0]{'location_id'} )->name();
} # end if

sub Photos {
	if ( ! $_[0]{'album_id'} ) {
		return ();
	} # end if
	return $_[0]->Album()->Photos( );
} # end sub Photos

sub Album {
	return new openprint::Photo_Album( $_[0]{'album_id'} );
} # end sub Album

sub can_edit {
	if ( $_[0]{'id'} and ( $openprint::session{'user_id'} == $_[0]{'created_by'} or $openprint::session{'user_type'} eq 'A' ) ) {
		return 1;
	} # end if
	return 0;
} # end sub can_edit

sub can_view {
	return 1 if ! $_[0]{'id'};
	return 1 if $openprint::session{'user_type'} eq 'A';
	return 1 if $_[0]{'user_id'} == $openprint::session{'user_id'};
	my $Privacy = $_[0]->Privacy();
	return 1 if ! $$Privacy{'id'};
	return $Privacy->can_view();
} # end sub can_view

sub Comments {
	return openprint::Comment->find({'object_type'=>'openprint::Event','object_id'=>$_[0]{'id'}});
} # end sub Comments

sub Attendance {
	if ( ! $_[0]{'Attendance'} ) {
		@{$_[0]{'Attendance'}} = openprint::Event_Attendance->find('event_id'=>$_[0]{'id'});
	} # end if
	return @{$_[0]{'Attendance'}};
} # end sub Attendance

sub Created_By {
	return new openprint::User( $_[0]{'created_by'} );
}

sub html {
	my $Event = $_[0];
	my $html = sprintf(q`
			<div class="Event">
			<div class="Assets"><a class="medium %6$s" href="/event/view.html?event_id=%1$d"><img alt="" src="%7$s"/></a></div>
			<div class="Name"><a href="/event/view.html?event_id=%1$d">%2$s</a></div>
			<div class="Category"><a href="/event/view.html?event_id=%1$d">%3$s</a></div>
			<div class="When">%4$s</div>
			<div class="Where">%5$s</div>
			`, $Event->id(), ssi::html_escape($Event->name()), $Event->Category()->name(),
                    $Event->time_string(),
                    $Event->where(),
			$Event->Asset()->layout(),
			$Event->Asset()->medium_url(),
			);
	my @Comments = $Event->Comments();
	$html .= sprintf(q`<div class="comments">This event has %s.</div>`, ( @Comments == 1 ? '1 comment' : @Comments . ' comments' ) );
	$html .= '</div>';
	return $html;
} # end  sub html

sub Location {
	if ( ! $_[0]{'Location'} ) {
	$_[0]{'Location'} = new openprint::Location( $_[0]{'location_id'} );
	} # end if
	return $_[0]{'Location'};
} # end sub Location

sub time_string {
	if ( @_ > 1 ) {
		$_[0]{'time_string'} = $_[1];
	}
	if ( ! $_[0]{'time_string'} ) {
		my $time_string;
		my $starting_on_seconds = Date::Parse::str2time($_[0]{'starting_on'});
		my $ending_on_seconds = Date::Parse::str2time($_[0]{'ending_on'});
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		my ($ssec,$smin,$shour,$smday,$smon,$syear,$swday,$syday,$sisdst) = localtime($starting_on_seconds);
		my ($esec,$emin,$ehour,$emday,$emon,$eyear,$ewday,$eyday,$eisdst) = localtime($ending_on_seconds);
		if ( $syear == $year and $smon == $mon and $smday == $mday ) {
			# starts today
			$time_string .= 'today';
			if ( $_[0]{'time_associated'} ) {
				$time_string .= ' at '.Date::Format::time2str( '%l:%M%P', $starting_on_seconds );
			} # end if
		} elsif ( $_[0]{'time_associated'} ) {
			$time_string .= Date::Format::time2str( '%a, %h %d %Y at %l:%M%P', $starting_on_seconds );
		} else {
			$time_string .= Date::Format::time2str( '%a, %h %d %Y', $starting_on_seconds );
		} # end if
		$time_string .= ' until ';
		if ( $eyear == $syear and (($eyday == $syday ) or ( $eyday == $syday+1 and $ehour < 7) ) ) {
			$time_string .= Date::Format::time2str( '%l:%M%P', $ending_on_seconds );
		} elsif ( $_[0]{'time_associated'} ) {
			$time_string .= Date::Format::time2str( '%a, %h %d %Y at %l:%M%P', $ending_on_seconds );
		} else {
			$time_string .= Date::Format::time2str( '%a, %h %d %Y', $ending_on_seconds );
		} # end if
		$_[0]{'time_string'} = $time_string;
	} # end if
	return $_[0]{'time_string'};
} # end sub time_string

sub thumbnail_id {
	return undef;
} # end sub thumbnail_id

sub thumbnail_html {
	if ( ! $_[0]{'thumbnail_html'} ) {
		my $Asset = $_[0]->Asset();
		if ( $Asset and $$Asset{'id'} ) {
			$_[0]{'thumbnail_html'} = sprintf('<a href="/event/view.html?event_id=%1$d" class="thumbnail"><img src="%2$s" alt="%3$s" title="%3$s" /></a>',
					$_[0]{'id'}, $Asset->thumbnail_url(), $_[0]->name() );
		} # end if
	} # end if
	return $_[0]{'thumbnail_html'};
} # end sub thumbnail_html

sub asset_html {
	if ( ! $_[0]{'asset_html'} ) {
		my $Album = new openprint::Photo_Album( $_[0]{'album_id'} );
		my $Thumbnail = $Album->Thumbnail() if $Album and $$Album{'id'};

		if ( $Thumbnail and $$Thumbnail{'asset_id'} ) {
			$_[0]{'asset_html'} = sprintf('<a class="Asset" href="/event/view.html?event_id=%1$d"><img src="%2$s" alt="%3$s" title="%3$s" /></a>',
					$_[0]{'id'}, $Thumbnail->Asset()->url(), $_[0]->name() );
		} # end if
	} # end if
	return $_[0]{'asset_html'};
} # end sub asset_html

sub upload {
	my $self = shift;
	my $Album = $self->Album();
	if ( ! $Album->id() ) {
		$Album->save({ 'Photos for event: ' . $$self{'name'} });
		$self->save({'album_id'=>$Album->id()});
	} # end if
	return $Album->upload( @_ );
} # end sub upload

sub view_url {
	return '/event/view.html?event_id='.$_[0]{'id'};
} # end sub view_url

sub invited_user_ids {
	return map { $_->user_id() } openprint::Event_Invitation->find('event_id'=>$_[0]{'id'});
} # end sub invited_user_ids

sub Invitations {
	return openprint::Event_Invitation->find('event_id'=>$_[0]{'id'});
} # end sub Invitations

1;
__END__
