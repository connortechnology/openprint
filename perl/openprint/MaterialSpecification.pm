use strict;
package openprint::MaterialSpecification;
our @ISA = qw( openprint::Object );
use openprint ();
use openprint::Material;
require sql;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$table = 'material_specifications';
$serial = 'materialspecification_id_seq';
%fields = (
	'id'			=>	'id',
	'material_id'	=>	'material_id',
	'min'			=>	'min',
	'max'			=>	'max',
	'units'			=>	'units',
	'name'			=>	'name',
	'value'			=>	'value',
	'interpolate'	=>	'interpolate',
);

$debug = 0;

1;
__END__
