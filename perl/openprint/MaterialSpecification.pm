package openprint::MaterialSpecification;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Material;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'Material_Specifications';
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

%transforms = (
);
%defaults = (
);

1;
__END__
