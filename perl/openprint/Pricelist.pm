package openprint::Pricelist;
@ISA = qw(openprint::Object);

use strict;

require sql;
require openprint::MaterialPrice;
require openprint::ServicePrice;
require openprint::PaperPrice;
require openprint::Currency;
require openprint::logs;
use openprint ();

sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::Pricelist( $params{'id'} );
	} else {
		my @values;
		my $sql = q{SELECT index FROM Pricelists WHERE 1>0};
		if ( $params{'name'} ) {
			$sql .= q{ AND name =?};
			push @values, $params{'name'};
		} # end if
		$sql .= " ORDER BY $params{'order'}" if $params{'order'};
		return map { new openprint::Pricelist( $_ ) } sql::execute( $openprint::log, $openprint::dbh, $sql, @values );
	} # end if

} # end sub find

sub load {
	my $self = shift;
	@$self{'id','name','Description', 'currency_id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT index, name, Description, CurrencyIndex FROM Pricelists WHERE Index=?}, $$self{'id'} );
} # end sub load

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM tbl_Service_Prices WHERE lngListIndex=?}, $$self{id} );
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM tbl_Material_Prices WHERE lngListIndex=?}, $$self{id} );
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Paper_Prices WHERE lngListIndex=?}, $$self{id} );
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Product_Prices WHERE pricelist_id=?}, $$self{id} );
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Pricelists WHERE Index=?}, $$self{id} );
	sql::end_transaction( $openprint::dbh, $ac );
	openprint::logs::insertLogRecord('9', "Price List Index: " . $$self{id},);
} # end sub delete

sub save {
	my ( $self, $param ) = @_;
	if ( $param ) {
		$$self{'name'} = $$param{'Name'};
		$$self{'description'} = $$param{'Description'};
		$$self{'currency_id'} = $$param{'Currency'};
	} # end if
	my @sql = (
		'name', $$self{'name'}, 'Description', $$self{'description'}, 'CurrencyIndex', $$self{'currency_id'},
);
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('PricelistIndex_seq'::text)} );
		sql::insert( $openprint::log, $openprint::dbh, 'Pricelists', 'Index', $$self{'id'}, @sql );
		openprint::logs::insertLogRecord('30', "Price List Index: " . $$self{'id'} . " - " . $$self{'name'},);
	} else { #save
		sql::update( $openprint::log, $openprint::dbh, 'Pricelists', "Index = $$self{'id'}",@sql );
		openprint::logs::insertLogRecord('31', "Price List Index: " . $$self{'id'} . " - " . $$self{'name'},);
	} # end if
} # end sub save

sub getPrices {
	my ( $self, $type ) = @_;

	my @prices;
	if ( ( ! $type ) or $type eq 'Material' ) {
		my @indexes = sql::execute( $openprint::log, $openprint::dbh, q{SELECT id FROM tbl_Material_Prices WHERE lngListIndex=?}, $$self{'id'} );
		while ( @indexes ) {
			push @prices, new openprint::MaterialPrice( shift @indexes );
		} # end while
	} # end if

	if ( ( ! $type ) or $type eq 'Service' ) {
		my @indexes = sql::execute( $openprint::log, $openprint::dbh, q{SELECT id FROM tbl_Service_Prices WHERE lngListIndex=?}, $$self{'id'} );
		while ( @indexes ) {
			push @prices, new openprint::ServicePrice( shift @indexes );
		} # end while
	} # end if
	if ( ( ! $type ) or $type eq 'Paper' ) {
		push @prices, openprint::PaperPrice::find( 'pricelist_id'=>$$self{'id'} );
	} # end if
	if ( ( ! $type ) or $type eq 'Product' ) {
		my @indexes = sql::execute( $openprint::log, $openprint::dbh, q{SELECT id FROM Product_Prices WHERE pricelist_id=?}, $$self{'id'} );
		while ( @indexes ) {
			push @prices, new openprint::ProductPrice( $openprint::log, $openprint::dbh, shift @indexes );
		} # end while
	} # end if
	return @prices;
	
} # end sub getPrices

sub Next {
	my $self = shift;
	my $New = new openprint::Pricelist( sql::execute( $openprint::log, $openprint::dbh, q{SELECT MIN(Index) FROM pricelists WHERE Index > ?}, $$self{'id'} ) );
	if ( ! $New->id() ) {
		$New = new openprint::Pricelist( sql::execute( $openprint::log, $openprint::dbh, q{SELECT MAX(Index) FROM pricelists WHERE Index <=?},  $$self{'id'} ) );
	} # end if
	return $New;
} # end sub next
sub Previous {
	my $self = shift;
	my $New = new openprint::Pricelist( sql::execute( $openprint::log, $openprint::dbh, q{SELECT MAX(Index) FROM pricelists WHERE Index < ?}, $$self{'id'} ) );
	if ( ! $New->id() ) {
		$New = new openprint::Pricelist( sql::execute( $openprint::log, $openprint::dbh, q{SELECT MIN(Index) FROM pricelists WHERE Index >=?},  $$self{'id'} ) );
	} # end if
	return $New;
} # end sub prev

sub currency {
	my $self = shift;
	return new openprint::Currency( $$self{'currency_id'} );
} # end sub currency

1;

__END__
~       
