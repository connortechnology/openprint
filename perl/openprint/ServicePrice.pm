package openprint::ServicePrice;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;
require openprint::logs;

my $debug = 1;

my %fields = (
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

sub load {
	my ( $self, $data ) = @_;

	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Service_Prices WHERE id=?', {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};

} # end sub load

sub delete {
	my $self = shift;

	sql::execute( undef, undef, 'DELETE FROM tbl_Service_Prices WHERE id=?', $$self{'id'} );
	openprint::logs::insertLogRecord('13', "Service Price ID: " . $$self{'id'},);
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, "SELECT nextval('serviceprices_id_seq')" );
		sql::insert( undef, undef, 'tbl_Service_Prices',
				'id',					$$self{'id'},
				'lngListIndex',			$$self{'pricelist_id'},
				'lngServiceIndex',		$$self{'service_id'},
				'lngEquipmentIndex', 	$$self{'equipment_id'} eq '' ? undef : $$self{'equipment_id'},
				'lngMin',				$$self{'min'} eq '' ? undef : $$self{'min'},
				'lngMax',				$$self{'max'} eq '' ? undef : $$self{'max'},
				'strUnits',				$$self{'units'},
				'dblCost',				1*$$self{'cost'},
				'dblMarkup',			1*$$self{'markup'},
				'dblPrice',				1*$$self{'price'},
				'ysnDiscountable',		$$self{'discountable'},
				);
	} else {
		sql::update( undef, undef, 'tbl_Service_Prices', ['id=?', $$self{'id'}],
				'lngListIndex',			$$self{'pricelist_id'},
				'lngServiceIndex',		$$self{'service_id'},
				'lngEquipmentIndex', 	$$self{'equipment_id'} eq '' ? undef : $$self{'equipment_id'},
				'lngMin',				$$self{'min'} eq '' ? undef : $$self{'min'},
				'lngMax',				$$self{'max'} eq '' ? undef : $$self{'max'},
				'strUnits',				$$self{'units'},
				'dblCost',				1*$$self{'cost'},
				'dblMarkup',			1*$$self{'markup'},
				'dblPrice',				1*$$self{'price'},
				'ysnDiscountable',		$$self{'discountable'},
				);
	} # end if
} # end sub save

sub next {
	my $self = shift;
	return new openprint::ServicePrice( sql::execute( undef,undef, q{SELECT MIN(Index) WHERE Index > ?}, $$self{'id'} ) );
} # end sub next

1;

__END__
~       
