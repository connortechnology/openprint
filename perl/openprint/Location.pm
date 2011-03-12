package openprint::Location;
@ISA = qw( openprint::Object );

use strict;
use openprint ();
use vars qw( %variable $log $dbh );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;

use vars qw( $table $serial %fields %find_fields %transforms %defaults );
$table = 'locations';
$serial = 'locations_id_seq';
%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'parent_id'		=>	'parent_id',
	'coordinates'	=>	'coordinates',
	'updated_on'	=>	'updated_on',
	# type refers to state/country/postalcode, etc... to help search the location db in other ways
	'type_id'		=>	'type_id',
);
%find_fields = (
	'type'	=>	'(SELECT name FROM Location_Types WHERE location_types.id = locations.type_id)',
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

1;
__END__
