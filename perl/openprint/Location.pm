use strict;
use openprint ();
require openprint::Location_Type;
require openprint::Asset;
require openprint::Photo_Album;
package openprint::Location;
our @ISA = qw( openprint::Object );

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
	'name'			=>	[ 's/^\s+//', 's/\s+$//' ],
	'latitude'		=>	[ 's/[^\d\.]//g' ],
	'longitude'		=>	[ 's/[^\d\.]//g' ],
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
$openprint::log->debug("Type: " . $Type->to_string() );
		$_[0]{'type_id'} = $Type->id();
		$_[0]{'type'} = $Type->name();
	} elsif ( ( ! defined $_[0]{'type'} ) and $_[0]{'type_id'} ) {
		$_[0]{'type'} = $_[0]->Type()->name();
	} # end if
$openprint::log->debug("Location::type " . $_[0]->to_string() );
	return $_[0]{'type'};
} # end sub type

# find an ancestor that fits some criteria, so if we wanted to find the city that something is located in, we could call this with a tpye of city
# It's recursive of course
sub ancestor {
	my $self = shift;
	return if ! @_;
	my ( $value ) = $self->get( $_[0] );
	if ( sets::isin( $value, $_[1] ) ) {
		$openprint::log->debug( "Returning Location: $_[0] ($$self{name}) ($value) != $_[1]");
		return $self;
	} else {
		$openprint::log->debug( "nA Location: $_[0] ($$self{name}) ($value) != $_[1]");
	} # end if
	if ( $$self{'parent_id'} ) {
$openprint::log->debug("Recursing" );
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
	my $ua = LWP::UserAgent->new;
	$ua->agent("IntelligentQuote/0.1 ");
# Create a request
$openprint::log->debug('Get: ' . join(',',$_[0]->name(),$_[0]->address(), $_[0]->postalcode(), map{$_->name()}$_[0]->Parents()));
	my $req = HTTP::Request->new(GET => 'http://maps.google.com/maps/geo?q='.join(',',$_[0]->name(),map{$_->name()}$_[0]->Parents()) );
# Pass request to the user agent and get a response back
	my $res = $ua->request($req);
	my $json = JSON::decode_json( $res->content );
#$openprint::log->debug( $res->content );
	if ( $$json{'Placemark'} ) {
		$openprint::log->warn("Placemrk" . Data::Dumper::Dumper( $json ) );
		my $PlaceMark = $$json{'Placemark'}[0];
		my $Point = $$PlaceMark{'Point'};
		my $coordinates = $$Point{'coordinates'};
		$_[0]{'latitude'} = openprint::Location->transform('latitude', @{$coordinates}[0] );
		$_[0]{'longitude'} = openprint::Location->transform('longitude', @{$coordinates}[1] );
$openprint::log->debug("Resulting coords: $_[0]{'latitude'}, $_[0]{'longitude'}");
		return 1;
	} else {
		$openprint::log->warn("No placemrk" . Data::Dumper::Dumper( $json ) );
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

sub Asset {
    if ( ! $_[0]{'Asset'} ) {
        my $Album = $_[0]->Album();
        if ( $$Album{'asset_id'} ) {
            $_[0]{'Asset'} = new openprint::Asset( $$Album{'asset_id'} );
        } elsif ( $$Album{'album_id'} and my @Photos = $Album->Photos() ) {
            $_[0]{'Asset'} = $Photos[0];
        } else {
            $_[0]{'Asset'} = new openprint::Asset();
        } # end if
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
		$_[0]{'where'} .= join(', ', map { $_->name() } $L, $L->Parents() );
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
			( $parent_id ? ( 'parent_id'=>$parent_id ) : () ),
			);
		if ( ( ! $Location ) or 
				( $Location->address() and $$param{'address'} and ( $Location->address() ne openprint::Location->transform('address',$$param{'address'}) ) ) or
				( $Location->postalcode() and $$param{'postalcode'} and ( $Location->postalcode() ne openprint::Location->transform('address',$$param{'postalcode'}) ) ) or
				( $Location->parent_id() != $parent_id )
		   ) {
			$Location = new openprint::Location();
			$error .= $Location->save({
					'name'			=>	$$param{'location'}, 
					'parent_id'		=>	$parent_id, 
					'type'			=>	'place', 
					'address'		=>	$$param{'address'},
					'postalcode'	=>	$$param{'postalcode'},
					});
		
		} else {
			my %change;
			$change{'address'} = $$param{'address'} if $$param{'address'} and ! $Location->address();
			$change{'postalcode'} = $$param{'postalcode'} if $$param{'postalcode'} and ! $Location->postalcode();
			if ( %change ) {
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
1;
__END__
