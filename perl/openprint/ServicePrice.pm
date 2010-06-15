package openprint::ServicePrice;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;
require openprint::logs;
use openprint;
use vars qw( %variable %session %param %config $log $dbh %fields %transforms %defaults );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'Service_Prices';
$serial = 'serviceprices_id_seq';

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
~       
