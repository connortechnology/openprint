package openprint::Location;
@ISA = qw( openprint::Object );

use strict;
use openprint ();
use vars qw( %variable $log $dbh );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'locations';
$serial = 'locations_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'parent_id'	=>	'parent_id',
	'coordinates'	=>	'coordinates',
	'updated_on'	=>	'updated_on',
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

1;
__END__
