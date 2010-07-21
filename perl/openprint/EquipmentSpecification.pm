package openprint::EquipmentSpecification;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Equipment;
require sql;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 0;
$table = 'tbl_Equipment_Specifications';
$serial = 'tbl_equipment_specifications_id_seq';

%fields = (
	'id'			=>	'id',
	'equipment_id'	=>	'lngequipmentindex',
	'min'			=>	'dblmin',
	'max'			=>	'dblmax',
	'units'			=>	'strunits',
	'name'			=>	'strname',
	'value'			=>	'strvalue',
	'interpolate'	=>	'interpolate',
);
%transforms = (
	'min' => [ 's/[^\d\.]//g' ],
	'max' => [ 's/[^\d\.]//g' ],
);
%defaults = (
	'min'	=>	undef,
	'max'	=>	undef,
);

sub Equipment {
	my $self = shift;
	return new openprint::Equipment( $$self{equipment_id} );
} # end sub Equipment

1;
__END__
