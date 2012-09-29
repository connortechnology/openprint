use strict;
use openprint ();
require openprint::Location_Type;
require openprint::Asset;
require openprint::Photo_Album;
package openprint::Location;
our @ISA = qw( openprint::Object );
require Geo::Coder::Googlev3;
require Geo::IP;

use constant PI => atan2(1,1)*4;
# 3.14159265358979;
use JSON ();
use LWP::UserAgent ();
use HTTP::Request ();

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );
$debug = 1;
$table = 'locations';
$serial = 'locations_id_seq';
%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'description'	=>	'description',
	'short'			=>	'short',
	'parent_id'		=>	'parent_id',
	'coordinates'	=>	'coordinates',
	'updated_on'	=>	'updated_on',
	'created_on'	=>	'created_on',
	# type refers to state/country/postalcode, etc... to help search the location db in other ways
	'type_id'		=>	'type_id',
	'type'			=>	undef,
	'created_by'	=>	'created_by',
	'postalcode'	=>	'postalcode',
	'address'		=>	'address',
	'latitude'		=>	'latitude',
	'longitude'		=>	'longitude',
	'url'			=>	'url',	
	'asset_id'		=>	'asset_id',
	'album_id'		=>	'album_id',
	'deleted'		=>	'deleted',
);
%find_fields = (
	'type'	=>	'(SELECT name FROM Location_Types WHERE location_types.id = locations.type_id)',
);
%transforms = (
	'parent_id'		=>	[ 's/\D//g' ],
	'postalcode'	=>	[ 'tr/[a-z]/[A-Z]/' ],
    'name'			=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
    'address'		=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
    'postalcode'	=> [ 's/\s*//' ],
	'latitude'		=>	[ 's/[^\-\d\.]//g' ],
	'longitude'		=>	[ 's/[^\-\d\.]//g' ],
);
%defaults = (
	'created_by'	=>	q`$session{user_id}`,
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'parent_id'		=>	undef,
	'type_id'		=>	undef,
	'latitude'		=>	undef,
	'longitude'		=>	undef,
	'asset_id'		=>	undef,
	'album_id'		=>	undef,
	'deleted'		=>	'0',
	'name'			=>	undef,
);

sub children {
	return openprint::Location->find( 'parent_id' => $_[0]{'id'} );
} # end sub children

sub get_all_children {
	my @results;
	
	foreach my $child ( $_[0]->children() ) {
		# Prevent infinite loop
		next if sets::isin( $child->id(), [ map { $_->id() } @results ] );
		push @results, $child, $child->get_all_children();
	} # end foreach child
	return @results;
} # end sub get_all_children

sub parent {
$openprint::log->error("use of deprecated method");
	return new openprint::Location( $_[0]{'parent_id'}) if $_[0]{'parent_id'};
} # end sub parent
sub Parent {
	return new openprint::Location( $_[0]{'parent_id'}) if $_[0]{'parent_id'};
} # end sub parent
sub Root {
	my $P = shift;
	while ( $P->parent_id() ) {
		$P = $P->Parent();
	} # end while 
	return $P;
} # end sub Root

sub Parents {
	
	if ( ( ! $_[0]{'id'} ) or ! $_[0]{'parent_id'} ) {
		return ();
	} else {
		return $_[0]->Parent(), $_[0]->Parent()->Parents();
	} # end if
} # end sub Parents

sub Type {
	return new openprint::Location_Type( $_[0]{'type_id'} );
} # end sub Type

sub type {
	if ( @_ > 1 ) {
		my $Type = openprint::Location_Type->find_one('name lc'=>lc openprint::Location_Type->transform('name',$_[1]));
		if ( ! $Type ) {
			$Type = new openprint::Location_Type();
			$Type->save({'name'=>$_[1]});
		} # end if
#$openprint::log->debug("Type: " . $Type->to_string() );
		$_[0]{'type_id'} = $Type->id();
		$_[0]{'type'} = $Type->name();
	} elsif ( ( ! defined $_[0]{'type'} ) and $_[0]{'type_id'} ) {
		$_[0]{'type'} = $_[0]->Type()->name();
	} # end if
#$openprint::log->debug("Location::type " . $_[0]->to_string() );
	return $_[0]{'type'};
} # end sub type

# find an ancestor that fits some criteria, so if we wanted to find the city that something is located in, we could call this with a tpye of city
# It's recursive of course
sub ancestor {
	my $self = shift;
	return if ! @_;
	my ( $value ) = $self->get( $_[0] );
	if ( sets::isin( $value, $_[1] ) ) {
		#$openprint::log->debug( "Returning Location: $_[0] ($$self{name}) ($value) != $_[1]");
		return $self;
	#} else {
		#$openprint::log->debug( "nA Location: $_[0] ($$self{name}) ($value) != $_[1]");
	} # end if
	if ( $$self{'parent_id'} ) {
#$openprint::log->debug("Recursing" );
		return $self->Parent()->ancestor( @_ );
	} # end if
	return;
} # end sub ancestor

# Figures out a given type's parent type should be, so city->state, etc.
sub parent_type {
	my $type;
	if ( $_[0] eq 'openprint::Location' ) {
		$type = $_[1];
	} else { 
		$type = $_[0]->type();
	} # end if
	if ( $type eq 'country' ) {
		return undef;
	} elsif ( $type eq 'state' ) {
		return 'country';
	} elsif ( $type eq 'city' ) {
		return 'state';
	} elsif ( $type eq 'place' ) {
		return 'city';
	} # end if
} # end sub parent_type

sub child_type {
	my $type;
	if ( $_[0] eq 'openprint::Location' ) {
		$type = $_[1];
	} else { 
		$type = $_[0]->type();
	} # end if
	if ( $type eq 'country' ) {
		return 'state';
	} elsif ( $type eq 'state' ) {
		return 'city';
	} elsif ( $type eq 'city' ) {
		return 'place';
	} elsif ( $type eq 'place' ) {
		return undef;
	} # end if
} # end sub child_type

sub latitude {
	if ( @_ > 1 ) {
		$_[0]{'latitude'} = $_[1];
	} # end if
	return $_[0]{'latitude'};
}
sub longitude {
	if ( @_ > 1 ) {
		$_[0]{'longitude'} = $_[1];
	} # end if
	return $_[0]{'longitude'};
}

sub get_latitude_and_longitude {
	my $coder = Geo::Coder::Googlev3->new();
my $string = join(',',$_[0]->name(),$_[0]->address(), $_[0]->postalcode(), map{$_->name()}$_[0]->Parents());
$string =~ s/ /+/g;
$openprint::log->debug('Get: ' . $string );
	my $location = $coder->geocode( location => $string );
	if ( ! $location ) {
		$openprint::log->error("No location for $string");
		return;
	} # enmdif 
	$openprint::log->warn("No placemrk" . Data::Dumper::Dumper( $location ) );

	my $use = 0;
	if ( $$location{'Point'} ) {
		my $Point = $$location{'Point'};
		my $coordinates = $$Point{'coordinates'};
		$_[0]{'latitude'} = openprint::Location->transform('latitude', @{$coordinates}[0] );
		$_[0]{'longitude'} = openprint::Location->transform('longitude', @{$coordinates}[1] );
		return 1;
	} elsif ( $$location{'geometry'} ) {
		if ( $$location{'geometry'}{'location'} ) {
			$_[0]{'latitude'} = openprint::Location->transform('latitude',  $$location{'geometry'}{'location'}{'lat'} );
			$_[0]{'longitude'} = openprint::Location->transform('longitude',  $$location{'geometry'}{'location'}{'lng'} );
			return 1;
		} # end if
	
	} else {
		my $Address = $$location{'AddressDetails'};
		if ( $$Address{'Country'} ) {
			my $Country = $$Address{'Country'};
			if ( $$Country{'AdministrativeArea'} ) {
				my $AdministrativeArea = $$Country{'AdministrativeArea'};
				if ( $$AdministrativeArea{'SubAdministrativeArea'} ) {
					$openprint::log->debug('Have Sub AdministrativeArea');
					$AdministrativeArea = $$AdministrativeArea{'SubAdministrativeArea'};
					$openprint::log->debug(Data::Dumper::Dumper($AdministrativeArea));
				} # end if

				if ( $$AdministrativeArea{'Locality'} ) {
					my $Locality = $$AdministrativeArea{'Locality'};
					if ( $_[0]{'postalcode'} ) {
						if ( $$Locality{'PostalCode'} ) {
							$openprint::log->debug("Have Postal code" . $$Locality{'PostalCode'}{'PostalCodeNumber'});

							if ( $$Locality{'PostalCode'}{'PostalCodeNumber'} eq $_[0]{'postalcode'} ) {
								$use = 1;
							} # end if
						} else {
							$openprint::log->debug("No PostalCode");
						} # en dif
					} # en dif postalcode
				} else {
					$openprint::log->debug("No Locality");
				} # end if
			} else {
				$openprint::log->debug("No Administrative Area");
			} # end if
		} else {
			$openprint::log->debug("No Coutry");
		} # end if

		if ( $use ) {
			my $Point = $$location{'Point'};
			my $coordinates = $$Point{'coordinates'};
			$_[0]{'latitude'} = openprint::Location->transform('latitude', @{$coordinates}[0] );
			$_[0]{'longitude'} = openprint::Location->transform('longitude', @{$coordinates}[1] );
	$openprint::log->debug("Resulting coords: $_[0]{'latitude'}, $_[0]{'longitude'}");
			$_[0]->save();
			return 1;
		} # end if
	} # end if
	return 0;
} # end sub get_latitude_longitude


sub distance {
$openprint::log->debug("distance: @_");
	shift @_ if $_[0] eq 'openprint::Location';
	shift @_ if ref $_[0] eq 'openprint::Location';

	my ($lat1, $lon1, $lat2, $lon2, $unit) = @_;
	my $theta = $lon1 - $lon2;
	my $dist = sin(deg2rad($lat1)) * sin(deg2rad($lat2)) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * cos(deg2rad($theta));
	$dist  = acos($dist);
	$dist = rad2deg($dist);
	$dist = $dist * 60 * 1.1515;
$openprint::log->debug("Calcing distance from $lat1,$lon1 to $lat2,$lon2 units: $unit, dist: $dist");
	if ($unit eq "K") {
		$dist = $dist * 1.609344;
	} elsif ($unit eq "N") {
		$dist = $dist * 0.8684;
	}
	return ($dist);
}

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#:::  This function get the arccos function using arctan function   :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
sub acos {
	return atan2(sqrt(1 - $_[0]**2), $_[0]);
}

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#:::  This function converts decimal degrees to radians             :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
sub deg2rad {
	return ($_[0] * PI / 180);
}

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#:::  This function converts radians to decimal degrees             :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
sub rad2deg {
	return ($_[0] * 180 / PI);
}

sub thumbnail_id {
	if ( ! exists $_[0]{'thumbnail_id'} ) {
        my $Album = $_[0]->Album();
        if ( $$Album{'thumbnail_id'} ) {
			$_[0]{'thumbnail_id'} = $$Album{'thumbnail_id'};
        } elsif ( $$Album{'id'} and my @Photos = $Album->Photos() ) {
            $_[0]{'thumbnail_id'} = $Photos[0]->asset_id();
        } # end if
	} # end if
	return $_[0]{'thumbnail_id'};
} # end sub thumbnail_id

sub Asset {
    if ( ! $_[0]{'Asset'} ) {
		$_[0]{'Asset'} = new openprint::Asset( $_[0]->thumbnail_id() );
    } # end if
    return $_[0]{'Asset'};
} # end sub Asset

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

sub where {
	if ( ! $_[0]{'where'} ) {
		my $L = $_[0];
		$_[0]{'where'} = '<a href="/location/view.html?location_id='.$L->id().'">';
		$_[0]{'where'} .= join(', ', map { $_->name() } $L->Parents() );
		if ( $L->address() or $L->postalcode() ) {
			$_[0]{'where'} .= '<br/>' . $L->address() . ', '.$L->postalcode();
		} # end if
		$_[0]{'where'} .= '</a>';
		if ( $L->url() ) {
			$_[0]{'where'} .= '<br/><a target="_blank" href="'.$L->url().'">'.$L->url().'</a>';
		} # end if
	} # end if
	return $_[0]{'where'};
} # end sub where

# Takes a hash, probably %param, and does all the saving neccessary, returns a Location object.
# If no location name is given, returns the parent. So if in an event I specified Toronto, then the location would be Toronto
sub save_location {
	my $param = $_[0];
	my $parent_id;
	my $error;

	if ( $$param{'country'} ) {
		my $Country = openprint::Location->find_one('name_lc'=> lc $$param{'country'}, 'type'=>'country' );
		if ( ! $Country ) {
			$Country = new openprint::Location();
			$error .= $Country->save({'name'=>$$param{'country'}, 'type'=>'country'});
		} # end if
		$parent_id = $$param{'country_id'} = $Country->id();
	} elsif ( $$param{'country_id'} ) {
		$parent_id = $$param{'country_id'};
	} # end if
	if ( $$param{'state'} ) {
		my $State = openprint::Location->find_one('name_lc'=> lc $$param{'state'}, 'type'=>['state','province']);
		if ( ! $State ) {
			$State = new openprint::Location();
			$error .= $State->save({'name'=>$$param{'state'}, 'type'=>'state', 'parent_id'=>$$param{'country_id'}});
		} # end if
		$parent_id = $$param{'state_id'} = $State->id();
	} elsif ( $$param{'state_id'} ) {
		$parent_id = $$param{'state_id'};
	} # end if
	if ( $$param{'city'} ) {
		my $City = openprint::Location->find_one('name_lc'=> lc $$param{'city'}, 'type'=>'city');
		if ( ! $City ) {
			$City = new openprint::Location();
			$error .= $City->save({'name'=>$$param{'city'}, 'type'=>'city', 'parent_id'=>$$param{'state_id'}});
		} # end if
		$parent_id = $$param{'city_id'} = $City->id();
	} elsif ( $$param{'city_id'} ) {
		$parent_id = $$param{'city_id'};
	} # end if
	my $Location;

	if ( $$param{'location'} ) {
		$Location = openprint::Location->find_one('name_lc'=> lc openprint::Location->transform('name',$$param{'location'}),
			( $$param{'address'} ? ( 'address lc'=>lc openprint::Location->transform('address',$$param{'address'}) ) : () ),
			( $parent_id ? ( 'parent_id'=>$parent_id ) : () ),
			);
		if ( ( ! $Location ) and $$param{'address'} ) {
		$Location = openprint::Location->find_one('name_lc'=> lc openprint::Location->transform('name',$$param{'location'}),
			( $parent_id ? ( 'parent_id'=>$parent_id ) : () ),
			);
		} # end if
		if ( ( ! $Location ) or 
				( $Location->address() and $$param{'address'} and ( $Location->address() ne openprint::Location->transform('address',$$param{'address'}) ) ) or
				( $Location->postalcode() and $$param{'postalcode'} and ( $Location->postalcode() ne openprint::Location->transform('postalcode',$$param{'postalcode'}) ) ) or
				( $Location->parent_id() != $parent_id )
		   ) {
#$openprint::log->debug("Blah");
#$openprint::log->debug('No location') if ! $Location;
#$openprint::log->debug("Address: $$Location{address} $$param{address} " . openprint::Location->transform('address',$$param{'address'}) );
#$openprint::log->debug("PostalCode: $$Location{postalcode} $$param{postalcode} " . openprint::Location->transform('postalcode',$$param{'postalcode'}) );
			# Different from what we have in db, add new
			$Location = new openprint::Location();
			$error .= $Location->save({
					'name'			=>	$$param{'location'}, 
					'parent_id'		=>	$parent_id, 
					($$param{'type_id'}?('type_id'=>$$param{'type_id'}):('type'			=>	'place')), 
					'address'		=>	$$param{'address'},
					'postalcode'	=>	$$param{'postalcode'},
					});
		
		} else {
			my %change;
			$change{'address'} = $$param{'address'} if $$param{'address'} and ! $Location->address();
			$change{'postalcode'} = $$param{'postalcode'} if $$param{'postalcode'} and ! $Location->postalcode();
			if ( %change ) {
$openprint::log->debug("Change:");
				$error .= $Location->save( \%change );
			} # end if
		} # end if
	} elsif ( $$param{'location_id'} ) {
		$Location = new openprint::Location( $$param{'location_id'} );
	} elsif ( $parent_id ) {
		$Location = new openprint::Location( $parent_id );
	} # end if
	return $error if $error;
	return $Location;
} # end sub save_location

sub googlemap_html {
	if ( ! exists $_[0]{'googlemap_html'} ) {
		$_[0]{'googlemap_html'} = sprintf('<iframe src="http://maps.google.com/maps?f=q&hl=en&ll=%1$s,%2$s&q=%3$s&z=13&output=embed" style="width: 100%; height:400px;"></iframe>', 
				$_[0]->latitude(), $_[0]->longitude(), join('+',$_[0]->name(), $_[0]->address(), ( $_[0]->postalcode() ? $_[0]->postalcode() : () ), map{$_->name()} ( $_[0]->Parents() ) ) );
	} # end if
	return $_[0]{'googlemap_html'};
} # end sub googlemap_html

sub from_ip {
	my $gi = Geo::IP->open("/var/lib/geoip/GeoLiteCity.dat");
	my $record = $gi->record_by_name(@_ ? $_[0] : $ENV{'REMOTE_ADDR'});
	return if ! $record;

	my $ac = sql::start_transaction( $openprint::dbh );
	$openprint::dbh->do( 'LOCK TABLE Orders IN SHARE ROW EXCLUSIVE MODE' ) or $openprint::log->error( $openprint::dbi->errstr() );
	my $Country = openprint::Location->find_one('type'=>'country','name lc'=>lc $record->country_name());
	if ( ! $Country ) {
		$Country = new openprint::Location();
		$Country->save({'name'=>$record->country_name(),'type'=>'country'});
	} # end if

	my $State = openprint::Location->find_one('type'=>'state','name lc'=>lc $record->region_name(),'parent_id'=>$Country->id());
	if ( ! $State ) {
		$State = new openprint::Location();
		$State->save({'name'=>$record->region_name(),'type'=>'state','parent_id'=>$Country->id()});
	} # end if
	my $City = openprint::Location->find_one('type'=>'city','name lc'=>lc $record->city(),'parent_id'=>$State->id());

	if ( ! $City ) {
		$City = new openprint::Location();
		$City->save({'name'=>$record->city(),'type'=>'city','parent_id'=>$State->id()});
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	return $City;
} # end sub from_ip

sub upload {
	my $self = shift;
	my $Album = $self->Album();
	if ( ! $Album->id() ) {
		$Album->save({ 'Photos for location: ' . $$self{'name'} });
		$self->save({'album_id'=>$Album->id()});
	} # end if
	return $Album->upload( @_ );
} # end sub upload

sub filters {
	my ( $prefix, $selected, $options ) = @_;

	my $option_string;
	if ( $$options{onSuccess} ) {
		$option_string = 'onSuccess: function(){' . $$options{onSuccess}.'}';
	} # end if
	if ( $option_string ) {
		$option_string = ',{'.$option_string.'}';
	} # end if

	my ( $country_id, $state_id, $city_id );
	if ( ref $selected eq 'openprint::Location' ) {
		$_ = $selected->ancestor('country');
		$country_id = $_->id() if $_;
		$_ = $selected->ancestor('state');
		$state_id = $_->id() if $_;
		$_ = $selected->ancestor('city');
		$city_id = $_->id() if $_;
	} elsif ( ref $selected eq 'HASH' ) {
		( $country_id, $state_id, $city_id ) = @$selected{'country','state','city'};
	} elsif ( ref $selected eq 'ARRAY' ) {
		( $country_id, $state_id, $city_id ) = @$selected;
	} # end if	
    my $html = '<li><label>Country</label>';
    my @Countries = openprint::Location->find(order=>'lower(name)',type=>'country');
    $html .= ssi::select( [ '', 'All', map { $_->id(), $_->name() } @Countries ], $country_id, { name=>'country_id', id=>'country_id', onchange=>qq`Location_onchange( this, 'country'$option_string );` } );

    $html .= '</li><li><label>';
	my $Country = new openprint::Location($country_id);
	if ( $Country->name() eq 'Canada' ) {
		$html .= 'Province';
	} elsif ( $Country->name() eq 'United States' ) {
		$html .= 'State';
	} else {
		$html .= 'State/Province';
	} # end if
	$html .= '</label>';
    my @States = openprint::Location->find(order=>'lower(name)',type=>'state',
			( sets::isin( $country_id, [ map { $_->id() } @Countries ] ) ? ( 'parent_id'=>$country_id ) : () ),
			);
    $html .= ssi::select( [ '', 'All', map { $_->id(), $_->name() } @States ], $state_id, { name=>'state_id', id=>'state_id', onchange=>qq`Location_onchange( this, 'state'$option_string );"` } );

    $html .= '</li><li><label>City</label>';
    my @Cities = openprint::Location->find('order'=>'lower(name)','type'=>'city',
        ( sets::isin( $state_id, [ map { $_->id() } @States ] ) ? ( 'parent_id'=>$state_id ) : () ),
    );
    $html .= ssi::select( [ '', 'All', map { $_->id(), $_->name() } @Cities ], $city_id, { name=>'city_id', id=>'city_id', onchange=>qq`Location_onchange( this, 'city'$option_string );` } );
	$html .= '</li>';

    return $html;
} # end sub filters
1;
__END__
