package openprint::MaterialCategory;
@ISA = qw( openprint::Object );
require openprint::Material;

use strict;

use openprint;

use vars qw( $table $serial $log $dbh %fields );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'Material_Categories';
$serial = 'material_categories_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);

sub Materials {
	my $self = shift;
	return openprint::Material->find( 'category_id'=>$$self{'id'} );
} # end sub project_types

 1;
__END__
