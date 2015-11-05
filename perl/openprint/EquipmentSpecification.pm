use strict;
package openprint::EquipmentSpecification;
our @ISA = qw( openprint::Object );
require openprint::Equipment;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'tbl_Equipment_Specifications';
$serial = 'tbl_equipment_specifications_id_seq';

%fields = (
	id				=>	'id',
	equipment_id	=>	'lngequipmentindex',
	min				=>	'dblmin',
	max				=>	'dblmax',
	units			=>	'strunits',
	name			=>	'strname',
	value			=>	'strvalue',
	interpolate		=>	'interpolate',
);
%transforms = (
	min		=> [ 's/[^\d\.]//g' ],
	max		=> [ 's/[^\d\.]//g' ],
	name	=> [ 's/^\s+//', 's/\s+$//' ],
	value	=> [ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
	min	=>	undef,
	max	=>	undef,
);

sub Equipment {
	return new openprint::Equipment( $_[0]{equipment_id} );
} # end sub Equipment

1;
__END__
