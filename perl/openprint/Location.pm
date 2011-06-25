use strict;
use openprint ();
require openprint::Location_Type;
package openprint::Location;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults %hierarchy );
$debug = 1;
$table = 'locations';
$serial = 'locations_id_seq';
%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
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
);
%find_fields = (
	'type'	=>	'(SELECT name FROM Location_Types WHERE location_types.id = locations.type_id)',
);
%transforms = (
	'postalcode'	=>	[ 'tr/[a-z]/[A-Z]/' ],
	'name'			=>	[ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
	'created_by'	=>	q`$session{user_id}`,
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'parent_id'		=>	undef,
	'type_id'		=>	undef,
);
%hierarchy = (
	'country'	=>	undef,	
	'state' =>	'country',
	'city'	=>	'state',
);

sub children {
	my $self = shift;
	return openprint::Location->find( 'parent_id' => $$self{'id'} );
} # end sub children

sub get_all_children {
	my $self = shift;
	my @results;
	
	foreach my $child ( $self->children() ) {
		# Prevent infinite loop
		next if sets::isin( $child->id(), [ map { $_->id() } @results ] );
		push @results, $child, $child->get_all_children();
	} # end foreach child
	return @results;
} # end sub get_all_children

sub parent {
	my $self = shift;
	return new openprint::Location( $$self{'parent_id'}) if $$self{'parent_id'};
} # end sub parent
sub Parent {
	my $self = shift;
	return new openprint::Location( $$self{'parent_id'}) if $$self{'parent_id'};
} # end sub parent
sub Root {
	my $self = shift;
	my $P = $self;
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
		my $Type = openprint::Location_Type->find_one('name_lc'=>lc $_[1]);
		if ( ! $Type ) {
			$Type = new openprint::Location_Type();
			$Type->save({'name'=>$_[1]});
		} # end if
		$_[0]{'type_id'} = $Type->id();
		$_[0]{'type'} = $Type->name();
	} # end if
	if ( ( ! defined $_[0]{'type'} ) and $_[0]{'type_id'} ) {
		$_[0]{'type'} = $_[0]->Type()->name();
	} # end if
	return $_[0]{'type'};
} # end sub type

# find an ancestor that fits some criteria, so if we wanted to find the city that something is located in, we could call this with a tpye of city
sub ancestor {
	my $self = shift;
	return if ! @_;
	my ( $value ) = $self->get( $_[0] );
	if ( sets::isin( $value, $_[1] ) ) {
		return $self;
	} else {
		$openprint::log->debug( "Location: $_[0] ($_[0]) ($value) != $_[1]($$self{$_[1]})");
	} # end if
	if ( $$self{'parent_id'} ) {
		return $self->Parent()->ancestor( @_ );
	} # end if
	return;
} # end sub ancestor


1;
__END__
