use strict;
package openprint::MaterialPrice;
our @ISA = qw( openprint::Object );

require sql;
require openprint::Object;

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

sub price {
	if ( @_ > 1 ) {
		$_[0]{'price'} = $_[1];
	} # end if
	if ( ! defined $_[0]{'price'} ) {
		$_[0]{'price'} = sprintf( '%.2f', $_[0]{'cost'} * ( 1+($_[0]{'markup'}/100) ) );
	} # end if
	return $_[0]{'price'};
} # end sub price

sub Pricelist {
	return new openprint::Pricelist( $_[0]{'pricelist_id'} );
}
sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

sub Material {
	return new openprint::Material( $_[0]{'material_id'} );
} # end sub Material

1;
__END__
