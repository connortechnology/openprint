package openprint::ServicePrice;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;


use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'Service_Prices';
$serial = 'service_prices_id_seq';

%fields = (
	'id'			=>	'id',
	'owner_id'		=>	'owner_id',
	'pricelist_id'	=>	'pricelist_id',
	'service_id'	=>	'service_id',
	'equipment_id'	=>	'equipment_id',
	'min'			=>	'min',
	'max'			=>	'max',
	'units'			=>	'units',
	'cost'			=>	'cost',
	'markup'		=>	'markup',
	'price'			=>	'price',
	'discountable'	=>	'discountable',
	'interpolate'	=>	'interpolate',
	'supplier_id'	=>	'supplier_id',
);

%transforms = (
	'min' => [ 's/(\d*)/$1/g' ],
	'max' => [ 's/(\d*)/$1/g' ],
	'cost' => [ 's/[^\d\.]//g' ],
	'price' => [ 's/[^\d\.]//g' ],
	'markup' => [ 's/[^\d\.]//g' ],
);
%defaults = (
	'min'			=>	undef,
	'max'			=>	undef,
	'equipment_id'	=>	undef,
	'supplier_id'	=>	undef,
	'cost'			=>	0,
	'markup'		=>	0,
	'price'			=>	0,
);

sub next {
	my $self = shift;
	return new openprint::ServicePrice( sql::execute( undef,undef, q{SELECT MIN(id) WHERE id > ?}, $$self{'id'} ) );
} # end sub next

1;
__END__
