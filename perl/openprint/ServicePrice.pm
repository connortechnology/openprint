package openprint::ServicePrice;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;
require openprint::logs;
use Math::Round qw(nearest);

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;

%fields = (
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
%defaults = (
	'min'	=>	undef,
	'max'	=>	undef,
	'cost'	=>	undef,
	'markup'	=>	undef,
	'price'		=>	undef,
	'discountable'	=>	1,
	'interpolate'	=>	0,
);

%transforms = (
	'min'	=>	[ 's/[^\d\.\-]//g' ],
	'max'	=>	[ 's/[^\d\.\-]//g' ],
	'cost'	=>	[ 's/[^\d\.\-]//g' ],
	'markup'	=>	[ 's/[^\d\.\-]//g' ],
	'price'	=>	[ 's/[^\d\.\-]//g' ],
);

sub find {
	if ( $_[0] eq 'openprint::ServicePrice' ) {
		shift;
	} # end if
	my %params = @_;
	my $sql = 'SELECT * FROM tbl_Service_Prices WHERE 1>0';
	my @values;

	if ( $params{'pricelist_id'} ) {
		$sql .= ' AND lnglistindex=?';
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

sub price {
    if ( @_ > 1 ) {
        $_[0]{'price'} = $_[1];
    } # end if
    if ( ! defined $_[0]{'price'} ) {
        $_[0]{'price'} = Math::Round::nearest( 0.01, $_[0]{'cost'} * ( 1+($_[0]{'markup'}/100) ) );
    } # end if
    return $_[0]{'price'};
} # end sub price

sub markup {
	if ( @_ > 1 ) {
		$_[0]{'markup'} = $_[1];
		$_[0]->price( undef );
	} # end if
	return $_[0]{'markup'};
} # end sub markup
sub cost {
	if ( @_ > 1 ) {
		$_[0]{'cost'} = $_[1];
		$_[0]->price( undef );
	} # end if
	return $_[0]{'cost'};
} # end sub cost
sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

1;
__END__
