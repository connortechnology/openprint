use strict;
package openprint::event;

use LWP::UserAgent ();
use openprint ();
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::Event;
require openprint::Event_Category;
require openprint::Event_Attendance;
require openprint::Asset;
require openprint::Photo_Album;
require openprint::Photo_in_Album;
require openprint::Location;
require Email::Valid;

sub history {
	if ( $param{'btnFunction'} eq 'Destroy' ) {
		$param{'event_id'} =~ s/\D//g;
		my $Event = new openprint::Event( $param{'event_id'} );
		$variable{'error'} .= $Event->destroy();
		%param = ();
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$param{'event_id'} =~ s/\D//g;
		my $Event = new openprint::Event( $param{'event_id'} );
		$variable{'error'} .= $Event->delete();
		%param = ();
	} # end if

	_history();
	if ( ( ! $session{'/event/history.html?lastupdated'} ) or ( time - $session{'/event/history.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/event/history.html', 'created_on_start', -31 );
		ssi::setup_date_select( '/event/history.html', 'created_on_end', '' );
		ssi::setup_date_select( '/event/history.html', 'starting_on_start', 0 );
		ssi::setup_date_select( '/event/history.html', 'starting_on_end', '' );
	} # end if
} # end sub history

sub _history {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/event/history.html', ( 
				'created_on_start_year','created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'starting_on_start_year','starting_on_start_month','starting_on_start_day',
				'starting_on_end_year','starting_on_end_month','starting_on_end_day',
				'employee_id','company_id', 'category_id' ) );
	} # end if
} # end sub _history

sub search {
	_search();
	if ( ( ! $session{'/event/search.html?lastupdated'} ) or ( time - $session{'/event/search.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/event/search.html', 'starting_on_start', 0 );
		ssi::setup_date_select( '/event/search.html', 'starting_on_end', '' );
	} # end if
	my $Location = new openprint::User($session{'user_id'})->Location() if $session{user_id};
	if ( ! ( $Location and $Location->id() ) ) {
		$Location = openprint::Location::from_ip( $ENV{'REMOTE_ADDR'} );
	} # end if
	if ( $Location and $Location->id() ) {
		my $Country = $Location->ancestor('type'=>'country');
		my $State = $Location->ancestor('type'=>'state');

		$session{'/event/search.html?country_id'} = $Country->id() if $Country and ! exists $session{'/event/search.html?country_id'};
		$session{'/event/search.html?state_id'} = $State->id() if $State and ! exists $session{'/event/search.html?state_id'};
	} # end if
} # end sub search
sub _search {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/event/search.html', ( 
				'starting_on_start_year','starting_on_start_month','starting_on_start_day',
				'starting_on_end_year','starting_on_end_month','starting_on_end_day',
				'user_id', 'category_id', 'country_id', 'state_id', 'city_id' ) );
	} # end if
} # end sub _history

sub edit {
	$variable{'Event'} = new openprint::Event( $param{'event_id'} );
	if ( $param{'btnFunction'} eq 'Copy' ) {
		$variable{'Event'} = $variable{'Event'}->copy();
		$variable{'error'} .= $variable{'Event'}->save();
	} # end if
} # end sub edit

sub _locations {
} # end sub _locations

sub category {
	my $Category = $variable{'Category'} = new openprint::Event_Category( $param{'category_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $Category->save(\%param);
        if ( $param{'filename'} ) {
            my $upload = $r->upload('filename');
            if ( ! $upload ) {
                $variable{'error'} .= "There was no upload for $param{'filename'}<br/>";
            } else {
				my $path = '/images/event_categories/' . $Category->id() . '_' . $param{'filename'};
                if ( ! $upload->link( $config{'SkinPath'} . $path ) ) {
                    $variable{'error'} .= "There was an error saving file $param{'filename'} to $config{SkinPath}$path : $!<br/>";
#$Asset->save({'filename'=>''});
                } else {
                    $variable{'error'} .= $Category->save({'image_filename'=>$path});
                    $variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
                } # end if
            } # end if
		} else {
			$log->debug("No image uploaded");
        } # end if

	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $Category->delete();
	} # end if
} # end sub category

sub view {
	$param{event_id} =~ s/\D//g;
	$param{user_id} =~ s/\D//g;
	if ( $param{user_id} ) {
		$variable{User} = new openprint::User( $param{user_id} );
	} else {
		$variable{User} = new openprint::User( $session{user_id} );
	} # end if
	my $Event = $variable{'Event'} = new openprint::Event( $param{'event_id'} );
	if ( ! $Event->can_view( $param{user_id} ? $param{user_id} : $session{user_id} ) ) {
		return misc::error( $log, $dbh, \%variable, 'Access Denied', 'You are not authorized to view this event.' );
	} else {
		$log->debug("Can view it.");
	} # end if
	if ( $param{'action'} eq 'Delete' ) {
		$variable{'error'} .= $Event->delete();
	} elsif ( $param{'action'} eq 'Undelete' ) {
		$variable{'error'} .= $Event->undelete();
		
	} elsif ( $param{'function'} eq 'Save' ) {
		$param{'company_id'} = $session{'company_id'} if ! $param{'company_id'};
		$param{'created_by'} = $session{'user_id'} if ! $param{'created_by'};
		$param{'starting_on'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'starting_on_year','starting_on_month','starting_on_day','starting_on_hour','starting_on_minute'} );
		$param{'ending_on'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'ending_on_year','ending_on_month','ending_on_day','ending_on_hour','ending_on_minute'} );
		if ( $param{'category_id'} ) {
			delete $param{'category'};
		} elsif ( $param{'category'} ) {
			delete $param{'category_id'};
		} else {
			delete $param{'category'};
			delete $param{'category_id'};
		} # end if
		my $Location = openprint::Location::save_location( \%param );
		$variable{'error'} .= $Location if ref $Location ne 'openprint::Location';

		if ( ( ! $param{'event_id'} ) and ( $_ = openprint::Event->find_one(
			( $Location ? ( 'location_id'=>$Location->id() ) : () ),
			, 'starting_on'=>$param{'starting_on'}, 'name lc'=> lc openprint::Event->transform('name', $param{'name'} ) ) ) ) {
			$variable{'Event'} = $Event = $_;
			$variable{'error'} .= 'An event with that name at that place at that time already exists.';
		} else {
			$param{'location_id'} = $Location->id() if $Location;
			$variable{'error'} .= $Event->save(\%param);
			(new openprint::Log())->save({'action'=>($param{'event_id'} ? 'Update Event' : 'Create Event'), 'object_type'=>'openprint::Event','object_id'=>$Event->id()});
		} # end if
		if ( ! $variable{'error'} ) {
			my $Privacy = $Event->Privacy();
			$variable{'error'} .= $Privacy->save( {
					map { $_, $param{'privacy_'.$_} } ( 'mode','user_id','relationship_type_id','usergroup_id' )
				} );
		} # en dif ! error
		if ( ! $variable{'error'} ) {
			$variable{'ExternalRedirect'} = '/event/view.html?event_id='.$Event->id();
		} # end if
	} elsif ( $param{function} eq 'Send' ) {
		$variable{'error'} .= $Event->send_invitations();
	} # end if function
} # end sub view

sub _view {
	my $Event = $variable{'Event'} = new openprint::Event( $param{'event_id'} );
	$Event->set( \%param );
} # end sub _view

sub _attendance {
	my $Event = $variable{Event} = new openprint::Event( $param{'event_id'} );
	$param{user_id} =~ s/\D//g;
	if ( $param{user_id} ) {
		$variable{User} = new openprint::User( $param{user_id} );
	} else {
		$variable{User} = new openprint::User( $session{user_id} );
	} # end if
	if ( exists $param{'attending'} ) {
		my $Attending = new openprint::Event_Attendance( {'event_id'=>$param{event_id}, 'user_id'=>$param{user_id} } );
$log->debug("Got: " . $Attending->to_string() );
		$variable{'error'} .= $Attending->save({
			'event_id'	=>	$param{event_id},
			'user_id'	=>	$param{user_id},
			'attending'	=>	$param{attending},
		});
	} # end if
} # end sub _attendance

sub _invitation_popup {
	$variable{'Event'} = new openprint::Event( $param{'event_id'} );
} # end sub _invitation_popup

sub _invitation_users {
	my $Event = $variable{'Event'} = new openprint::Event( $param{'event_id'} );
	my $Privacy = $Event->Privacy();
	my $privacy_users = $Privacy->user_id();
	if ( $param{'action'} eq 'set' ) {
		my %old = map { $_->user_id(), $_ } $Event->Invitations();
		my @remove_users = sets::exclude( ref $param{'user_id'} eq 'ARRAY' ? $param{user_id} : [ $param{user_id} ], [ keys %old ] );
		foreach my $user_id ( @remove_users ) {
			$old{$user_id}->delete();
		} # end foreach
		@{$privacy_users} = sets::exclude( \@remove_users, $privacy_users );
		if ( $param{user_id} ) {
			my @new_users = sets::exclude( [ keys %old ], ref $param{user_id} eq 'ARRAY' ? $param{user_id} : [ $param{user_id} ] );
			foreach my $user_id ( @new_users ) {
				$variable{'error'} .= (new openprint::Event_Invitation())->save({event_id=>$param{event_id}, user_id=>$user_id});
			} # end foreach
			@{$privacy_users} = sets::union( @$privacy_users, @new_users );
		} # end if
		$variable{'error'} .= $Privacy->save({user_id=>$privacy_users});
	} elsif ( $param{'action'} eq 'add' ) {
		if ( ! openprint::Event_Invitation->find_one(event_id=>$param{event_id}, user_id=>$param{user_id}) ) {
			new openprint::Event_Invitation()->save({event_id=>$param{event_id}, user_id=>$param{user_id}});
			$variable{'error'} .= $Privacy->save({user_id=>[ sets::union( @$privacy_users, $param{user_id} ) ] });
			#$Event->invited_user_ids(undef);
		} # end if
	} elsif ( $param{action} eq 'add by relationship' ) {
		if ( $param{relationship_id} ) {
			my %old = map { $_->user_id(), $_ } $Event->Invitations();
			my @new_users;
			foreach my $R ( openprint::User_Relationship->find( type_id=>$param{relationship_id}, user_id1=>$session{user_id} ) ) {
				next if $old{$$R{user_id1}} or $old{$$R{user_id2}};
				my $Invite = new openprint::Event_Invitation();
				$Invite->save({event_id=>$param{event_id}, user_id=>$$R{user_id2}});
				push @new_users, $$R{user_id2};
				$openprint::log->debug("Adding user " . $Invite->User()->name() );
			} # end foreach R
			foreach my $R ( openprint::User_Relationship->find( type_id=>$param{relationship_id}, user_id2=>$session{user_id} ) ) {
				next if $old{$$R{user_id1}} or $old{$$R{user_id2}};
				my $Invite = new openprint::Event_Invitation();
				$Invite->save({event_id=>$param{event_id}, user_id=>$$R{user_id1}});
				push @new_users, $$R{user_id1};
				$openprint::log->debug("Adding user " . $Invite->User()->name() );
			} # end foreach R
			$variable{'error'} .= $Privacy->save({user_id=>[ sets::union( @$privacy_users, @new_users ) ] });
		} # end if
	} elsif ( $param{'email'} ) {
		foreach my $address ( misc::trim(split(',',$param{email})) ) {
			if ( ! Email::Valid->address( $address ) ) {
				$variable{'error'} .= $address . ' is not a valid email address.<br/>';
				next;
			} # end if
			my $User = openprint::User->find_one('email lc'=>lc $address);
			if ( ! $User ) {
				$User = new openprint::User();
				$User->save({email=>$address});
			} # end if
			if ( ! openprint::Event_Invitation->find_one(event_id=>$param{event_id}, user_id=>$$User{id}) ) {
				new openprint::Event_Invitation()->save({event_id=>$param{event_id}, user_id=>$$User{id}});
				$variable{'error'} .= $Privacy->save({user_id=>[ @$privacy_users, $$User{id} ] });
#$Event->invited_user_ids(undef);
			} # end if
		} # end foreach address
	} # end if
} # end sub _invitation_users

sub _user_name {
} # end sub _user_name

1;
__END__
