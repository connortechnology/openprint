package openprint::MaterialPrice;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;
require openprint::logs;

my $debug = 1;

use vars qw( $table $serial %defaults %transforms %fields );
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

sub find {
	if ( $_[0] eq 'openprint::MaterialPrice' ) {
		shift;
	}
	my %params = @_;
	my $sql = 'SELECT * FROM tbl_Material_Prices WHERE 1>0';
	my @values;

	if ( $params{'pricelist_id'} ) {
		$sql .= ' AND lnglistindex=?';
		push @values, $params{'pricelist_id'};
	} # end if
	if ( $params{'Pricelist'} ) {
		$sql .= ' AND lnglistindex=?';
		push @values, $params{'Pricelist'}->id();
	} # end if
	if ( $params{'material_id'} ) {
		$sql .= ' AND lngmaterialindex=?';
		push @values, $params{'material_id'};
	} # end if
	if ( $params{'Material'} ) {
		$sql .= ' AND lngmaterialindex=?';
		push @values, $params{'Material'}->id();
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
		$openprint::log->debug("Error loading Material Price ($sql) (@values) Reason: " . $openprint::dbh->errstr );
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Material Price ($sql) (@values) " . @$data );
	} # end if
	return map { new openprint::MaterialPrice( $_->{id}, $_ ) } @$data;
} # end sub find

sub save {
	my ( $self, $param ) = @_;

	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, "SELECT nextval('materialprices_id_seq')" );
		sql::insert( undef, undef, 'tbl_Material_Prices',
				'id',					$$self{'id'},
				'lngListIndex',			$$self{'pricelist_id'},
				'lngMaterialIndex',		$$self{'material_id'},
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
		sql::update( undef, undef, 'tbl_Material_Prices', ['id=?', $$self{'id'}],
				'lngListIndex',			$$self{'pricelist_id'},
				'lngMaterialIndex',		$$self{'material_id'},
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
