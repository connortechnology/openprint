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

sub history {
	if ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Event = new openprint::Event( $param{'event_id'} );
		$variable{'error'} .= $Event->destroy();
		%param = ();
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
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

sub list {
} # end sub list

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
	my $Event = $variable{'Event'} = new openprint::Event( $param{'event_id'} );
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
	} # end if
} # end sub view

sub _view {
	my $Event = $variable{'Event'} = new openprint::Event( $param{'event_id'} );
	$Event->set( \%param );
} # end sub _view

sub _attendance {
	my $Event = $variable{'Event'} = new openprint::Event( $param{'event_id'} );
	if ( exists $param{'attending'} ) {
		my $Attending = new openprint::Event_Attendance( {'event_id'=>$param{'event_id'}, 'user_id'=>$session{'user_id'} } );
$log->debug("Got: " . $Attending->to_string() );
		$variable{'error'} .= $Attending->save({
			'event_id'	=>	$param{'event_id'},
			'user_id'	=>	$session{'user_id'},
			'attending'	=>	$param{'attending'},
		});
	} # end if
} # end sub _attendance

1;
__END__
