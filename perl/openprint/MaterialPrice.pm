package openprint::MaterialPrice;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;
require openprint::logs;


use vars qw( $debug $table $serial %defaults %transforms %fields );
$debug = 1;
$table = 'tbl_Material_Prices';
$serial = 'materialprices_id_seq';

%fields = (
	'id'			=>  'id',
	'pricelist_id'	=>	'lnglistindex',
	'material_id'	=>	'lngmaterialindex',
	'equipment_id'	=>	'lngequipmentindex',
	'min'			=>	'lngmin',
	'max'			=>	'lngmax',
	'units'			=>	'strunits',
	'cost'			=>	'dblcost',
	'markup'		=>	'dblmarkup',
	'price'			=>	'dblprice',
	'discountable'	=>	'ysndiscountable',
	'interpolate'	=>	'interpolate',
);
%transforms = (
	'min'		=>	[ 's/[^\d\.\-]//g' ],
	'max'		=>	[ 's/[^\d\.\-]//g' ],
	'cost'		=>	[ 's/[^\d\.\-]//g' ],
	'markup'	=>	[ 's/[^\d\.\-]//g' ],
	'price'		=>	[ 's/[^\d\.\-]//g' ],
);
%defaults = (
	'min'			=>	undef,
	'max'			=>	undef,
	'cost'			=>	0,
	'markup'		=>	0,
	'price'			=>	0,
	'equipment_id'	=>	undef,
);

sub next {
	my $self = shift;
	return new openprint::MaterialPrice( sql::execute( undef,undef, q{SELECT MIN(id) FROM 'tbl_material_prices WHERE id > ?}, $$self{'id'} ) );
} # end sub next

1;
__END__
