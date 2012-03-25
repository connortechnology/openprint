use strict;
package openprint::location;

require openprint::Location;
use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub _load_location {
} # end sub _load_location

sub _locations {
} # end sub _locations

sub list {
} # end sub list

sub _action {
} # end sub _action

sub edit {
	my $Location = $variable{'Location'} = new openprint::Location( $param{'location_id'} );
} # end sub edit

sub view {
	my $Location = $variable{'Location'} = new openprint::Location( $param{'location_id'} );
	if ( $param{'function'} eq 'Save' ) {
		my $parent_id;
		if ( $param{'country'} ) {
			my $Country = openprint::Location->find_one('name lc'=> lc $param{'country'}, 'type'=>'country' );
			if ( ! $Country ) {
				$Country = new openprint::Location();
				$variable{'error'} .= $Country->save({'name'=>$param{'country'}, 'type'=>'country'});
			} # end if
			$parent_id = $param{'country_id'} = $Country->id();
		} elsif ( $param{'country_id'} ) {
			$parent_id = $param{'country_id'};
		} # end if
		if ( $param{'state'} ) {
			my $State = openprint::Location->find_one('name lc'=> lc $param{'state'}, 'type'=>['state','province']);
			if ( ! $State ) {
				$State = new openprint::Location();
				$variable{'error'} .= $State->save({'name'=>$param{'state'}, 'type'=>'state', 'parent_id'=>$param{'country_id'}});
			} # end if
			$parent_id = $param{'state_id'} = $State->id();
		} elsif ( $param{'state_id'} ) {
			$parent_id = $param{'state_id'};
		} # end if
		if ( $param{'city'} ) {
			my $City = openprint::Location->find_one('name lc'=> lc $param{'city'}, 'type'=>'city');
			if ( ! $City ) {
				$City = new openprint::Location();
				$variable{'error'} .= $City->save({'name'=>$param{'city'}, 'type'=>'city', 'parent_id'=>$param{'state_id'}});
			} # end if
			$parent_id = $param{'city_id'} = $City->id();
		} elsif ( $param{'city_id'} ) {
			$parent_id = $param{'city_id'};
		} # end if
			
		if ( ( $_ = openprint::Location->find_one(
			( $param{'location_id'} ? ( 'id !='=>$param{'location_id'} ) : () ),
			'name lc'=> lc openprint::Location->transform('name',$param{'name'}), ) ) ) {
			$variable{'error'} .= 'A location with that name at that place already exists.';
		} else {
			if ( $param{'url'} ) {
				if ( ! ( $param{'url'} =~ /^https?:\/\//i ) ) {
					$param{'url'} = 'http://'.$param{'url'};
				} # end if
			} # end if
			$variable{'error'} .= $Location->save({
					'name'			=>	$param{'name'}, 
					'description'	=>	$param{'description'},
					'parent_id'		=>	$parent_id, 
					'type'			=>	'place', 
					'address'		=>	$param{'address'},
					'postalcode'	=>	$param{'postalcode'},
					'url'			=>	$param{'url'},
					'latitude'		=>	$param{'latitude'},
					'longitude'		=>	$param{'longitude'},
					});
			(new openprint::Log())->save({'action'=>($param{'location_id'} ? 'Update Location' : 'Create Location'), 'object'=>'Location','object_id'=>$Location->id()});
		} # end if
	} elsif ( $param{'filename'} ) {
		my $Album = $Location->Album();
		if ( ! $Album->id() ) {
			$variable{'error'} .= $Album->save({'name'=>'Photos for ' . $Location->name()});
			$variable{'error'} .= $Location->save({'album_id'=>$Album->id()});
		} # end if
		$variable{'error'} = $Album->upload( 'filename' );
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
		} # end if
	} # end if
} # end sub view

sub _photos {
	my $Location = $variable{'Location'} = new openprint::Location( $param{'location_id'} );
	if ( $param{'action'} eq 'delete' ) {
		my $Photo = openprint::Photo_in_Album->find_one( {'album_id'=>$$Location{'album_id'}, 'asset_id'=>$param{'asset_id'} } );
		$variable{'error'} .= $Photo->delete() if $Photo->id();
	} # end if
} # end sub _photos

sub search {
	_search();
	#if ( ( ! $session{'/event/search.html?lastupdated'} ) or ( time - $session{'/event/search.html?lastupdated'} ) > ( 12*60*60 ) ) {
		#ssi::setup_date_select( '/event/search.html', 'starting_on_start', 0 );
		#ssi::setup_date_select( '/event/search.html', 'starting_on_end', '' );
	#} # end if
} # end sub search
sub _search {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/location/search.html', ( 
				#'starting_on_start_year','starting_on_start_month','starting_on_start_day',
				#'starting_on_end_year','starting_on_end_month','starting_on_end_day',
				'type_id', 'user_id', 'category_id', 'country_id', 'state_id', 'city_id' ) );
	} # end if
} # end sub _search
1;
__END__
