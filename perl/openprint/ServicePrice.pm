package openprint::ServicePrice;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;
require openprint::logs;

my $debug = 1;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'tbl_Service_prices';
$serial = 'serviceprices_id_seq';

%fields = (
	'id'			=>	'id',
	'pricelist_id'	=>	'lnglistindex',
	'service_id'	=>	'lngserviceindex',
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
	'cost'			=>	0,
	'markup'		=>	0,
	'price'			=>	0,
);

sub find {
	my %params = @_;
	my $sql = 'SELECT * FROM tbl_Service_Prices WHERE 1>0';
	my @values;

	if ( $params{'pricelist_id'} ) {
		$sql .= ' AND lngpricelistindex=?';
		push @values, $params{'pricelist_id'};
	} # end if
	if ( $params{'Pricelist'} ) {
		$sql .= ' AND lnglistindex=?';
		push @values, $params{'Pricelist'}->id();
	} # end if
	if ( $params{'service_id'} ) {
		$sql .= ' AND lngserviceindex=?';
		push @values, $params{'service_id'};
	} # end if
	if ( $params{'Service'} ) {
		$sql .= ' AND lngserviceindex=?';
		push @values, $params{'Service'}->id();
	} # end if
	if ( $params{'equipment_id'} ) {
		$sql .= ' AND lngEquipmentIndex=?';
		push @values, $params{'equipment_id'};
	} # end if
	if ( $params{'Equipment'} ) {
		if ( $params{'Equipment'}->id() ) {
		$sql .= ' AND lngEquipmentIndex=?';
		push @values, $params{'Equipment'}->id();
		} else {
		$sql .= ' AND lngEquipmentIndex IS NULL';
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading Service Price ($sql) (@values) Reason: " . $openprint::dbh->errstr );
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Service Price ($sql) (@values) " . @$data );
	} # end if
	return map { new openprint::ServicePrice( $_->{id}, $_ ) } @$data;
} # end sub find

sub next {
	my $self = shift;
	return new openprint::ServicePrice( sql::execute( undef,undef, q{SELECT MIN(id) WHERE id > ?}, $$self{'id'} ) );
} # end sub next

1;

__END__
~       
