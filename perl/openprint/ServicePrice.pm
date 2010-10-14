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

sub find {
	my %params = @_;
	my $sql = 'SELECT * FROM Service_Prices WHERE 1>0';
	my @values;

	if ( $params{'pricelist_id'} ) {
		$sql .= ' AND pricelist_id=?';
		push @values, $params{'pricelist_id'};
	} # end if
	if ( $params{'Pricelist'} ) {
		$sql .= ' AND pricelist_id=?';
		push @values, $params{'Pricelist'}->id();
	} # end if
	if ( $params{'service_id'} ) {
		$sql .= ' AND service_id=?';
		push @values, $params{'service_id'};
	} # end if
	if ( $params{'Service'} ) {
		$sql .= ' AND service_id=?';
		push @values, $params{'Service'}->id();
	} # end if
	if ( $params{'equipment_id'} ) {
		$sql .= ' AND equipment_id=?';
		push @values, $params{'equipment_id'};
	} # end if
	if ( $params{'Equipment'} ) {
		if ( $params{'Equipment'}->id() ) {
			$sql .= ' AND equipment_id=?';
			push @values, $params{'Equipment'}->id();
		} else {
			$sql .= ' AND equipment_id IS NULL';
		} # end if
	} # end if
	if ( $params{'supplier_id'} ) {
		$sql .= ' AND supplier_id=?';
		push @values, $params{'supplier_id'};
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

sub Pricelist {
return new openprint::Pricelist( $_[0]{'pricelist_id'} );
}
sub Equipment {
return new openprint::Equipment( $_[0]{'equipment_id'} );
}
sub Service {
return new openprint::Service( $_[0]{'service_id'} );
}

1;

__END__
~       
