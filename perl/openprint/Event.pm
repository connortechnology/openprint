use strict;
require openprint::Event_Category;
require openprint::Comment;
require openprint::Event_Attendance;
package openprint::Event;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %transforms %defaults );
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
		my $Category = openprint::Event_Category->find_one('name_lc'=>lc$_[1]);
		if ( ! $Category ) {
			$Category = new openprint::Event_Category();
			$Category->save({'name'=>$_[1]})
		} # end if	
		$_[0]{'category_id'} = $Category->id();
		return $Category->name();
	} # end if
	return new openprint::Event_Category( $_[0]{'category_id'} )->name();
} # end sub category
sub Category {
	return new openprint::Event_Category( $_[0]{'category_id'} );
} # end sub Category

sub where {
	return join(', ', map { $_->name() } $_[0]->Location(), $_[0]->Location()->Parents() );
} # end sub where

sub Asset {
	if ( ! $_[0]{'Asset'} ) {
		my $Album = $_[0]->Album();
		if ( $$Album{'thumbnail_id'} ) {
			$_[0]{'Asset'} = new openprint::Asset( $$Album{'thumbnail_id'} );
		} elsif ( my @Photos = $Album->Photos() ) {
			$_[0]{'Asset'} = $Photos[0];
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
			<a class="thumbnail" href="/event/view.html?event_id=%1$d"><img alt="" src="%2$s"/></a>
			<span class="name"><a href="/event/view.html?event_id=%1$d">%3$s</a></span>
			<span class="when">%4$s</span>
			`, $Event->id(),
			$Event->Asset()->thumbnail_url(),
			ssi::htmlize($Event->name()),
			( $Event->starting() ? Date::Format::time2str($openprint::config{'DateTimeFormat'}, Date::Parse::str2time( $Event->published_on() ) ) : '' ),

			);
	my @Comments = $Event->Comments();
	$html .= sprintf(q`<div class="comments">This event has %s.</div>`, ( @Comments == 1 ? '1 comment' : @Comments . ' comments' ) );
	$html .= '</div>';
	return $html;
} # end  sub html

sub Location {
	return new openprint::Location( $_[0]{'location_id'} );
} # end sub Location

1;
__END__
