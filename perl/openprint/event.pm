package openprint::event;

use strict;
use LWP::UserAgent;
use openprint;
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

sub history {
	if ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Event = new openprint::Event( $param{'event_id'} );
		$variable{'error'} .= $Event->destroy();
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		my $Event = new openprint::Event( $param{'event_id'} );
		$variable{'error'} .= $Event->destroy();
	} # end if

	if ( ( ! $session{'/event/history.html?lastupdated'} ) or ( time - $session{'/event/history.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/event/history.html', 'created_on_start', -31 );
		ssi::setup_date_select( '/event/history.html', 'created_on_end', '' );
		ssi::setup_date_select( '/event/history.html', 'starting_on_start', 0 );
		ssi::setup_date_select( '/event/history.html', 'starting_on_end', '' );
	} # end if
	ssi::save_params( '/event/history.html', ( 
				'created_on_start_year','created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'starting_on_start_year','starting_on_start_month','starting_on_start_day',
				'starting_on_end_year','starting_on_end_month','starting_on_end_day',
				'company_id', 'category_id' ) );
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
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/event/search.html', ( 
				'starting_on_start_year','starting_on_start_month','starting_on_start_day',
				'starting_on_end_year','starting_on_end_month','starting_on_end_day',
				'user_id', 'category_id' ) );
	} # end if
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
				'user_id', 'category_id' ) );
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
	if ( $param{'function'} eq 'Save' ) {
		$param{'company_id'} = $session{'company_id'} if ! $param{'company_id'};
		$param{'starting_on'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'starting_on_year','starting_on_month','starting_on_day','starting_on_hour','starting_on_minute'} );
		$param{'ending_on'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'ending_on_year','ending_on_month','ending_on_day','ending_on_hour','ending_on_minute'} );
		if ( $param{'category_id'} ) {
			delete $param{'category'};
		} else {
			delete $param{'category_id'};
		} # end if
		my $parent_id;
		if ( $param{'country'} ) {
			my $Country = openprint::Location->find_one('name_lc'=> lc $param{'country'}, 'type'=>'country' );
			if ( ! $Country ) {
				$Country = new openprint::Location();
				$variable{'error'} .= $Country->save({'name'=>$param{'country'}, 'type'=>'country'});
			} # end if
			$parent_id = $param{'country_id'} = $Country->id();
		} # end if
		if ( $param{'state'} ) {
			my $State = openprint::Location->find_one('name_lc'=> lc $param{'state'}, 'type'=>['state','province']);
			if ( ! $State ) {
				$State = new openprint::Location();
				$variable{'error'} .= $State->save({'name'=>$param{'state'}, 'type'=>'state', 'parent_id'=>$param{'country_id'}});
			} # end if
			$parent_id = $param{'state_id'} = $State->id();
		} # end if
		if ( $param{'city'} ) {
			my $City = openprint::Location->find_one('name_lc'=> lc $param{'city'}, 'type'=>'city');
			if ( ! $City ) {
				$City = new openprint::Location();
				$variable{'error'} .= $City->save({'name'=>$param{'city'}, 'type'=>'city', 'parent_id'=>$param{'state_id'}});
			} # end if
			$parent_id = $param{'city_id'} = $City->id();
		} # end if
		if ( $param{'location'} ) {
			my $Location = openprint::Location->find_one('name_lc'=> lc $param{'location'} );
			if ( ( ! $Location ) or 
					( $Location->address() and $param{'address'} and ( $Location->address() ne $param{'address'} ) ) or
					( $Location->postalcode() and $param{'postalcode'} and ( $Location->postalcode() ne $param{'postalcode'} ) ) or
					( $Location->parent_id() != $parent_id )
			   ) {
				$Location = new openprint::Location();
				$variable{'error'} .= $Location->save({
						'name'			=>	$param{'location'}, 
						'parent_id'		=>	$parent_id, 
						'type'			=>	'place', 
						'address'		=>	$param{'address'},
						'postalcode'	=>	$param{'postalcode'},
						});
			
			} else {
				my %change;
				$change{'address'} = $param{'address'} if $param{'address'} and ! $Location->address();
				$change{'postalcode'} = $param{'postalcode'} if $param{'postalcode'} and ! $Location->postalcode();
				if ( %change ) {
					$variable{'error'} .= $Location->save( \%change );
				} # end if
			} # end if
			$param{'location_id'} = $Location->id();
		} # end if
		if ( ( ! $param{'event_id'} ) and ( $_ = openprint::Event->find_one('location_id'=>$param{'location_id'}, 'starting_on'=>$param{'starting_on'}, 'name'=>$param{'name'} ) ) ) {
			$variable{'Event'} = $Event = $_;
			$variable{'error'} .= 'An event with that name at that place at that time already exists.';
		} else {
			$variable{'error'} .= $Event->save(\%param);
			new openprint::Log()->save({'action'=>'Create Event', 'object'=>'Event','object_id'=>$Event->id()});
		} # end if
	} elsif ( $param{'filename'} ) {
		my $Album = $Event->Album();
		if ( ! $Album->id() ) {
			$variable{'error'} .= $Album->save({'name'=>'Photos for ' . $Event->name()});
			$variable{'error'} .= $Event->save({'album_id'=>$Album->id()});
		} # end if
		$variable{'error'} = $Album->upload( 'filename' );
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
		} # end if
	} # end if
} # end sub view

sub _view {
	my $Event = $variable{'Event'} = new openprint::Event( $param{'event_id'} );
	$Event->set( \%param );
} # end sub _view

sub _photos {
	my $Event = $variable{'Event'} = new openprint::Event( $param{'event_id'} );
	if ( $param{'action'} eq 'delete' ) {
		my $Photo = new openprint::Photo_in_Album( {'album_id'=>$$Event{'album_id'}, 'asset_id'=>$param{'asset_id'} } );
		$Photo->delete();
	} # end if
} # end sub _photos

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
