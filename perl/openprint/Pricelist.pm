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

my $debug = 1;
use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'pricelists';
$serial = 'pricelists_id_seq';
%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'owner_id'		=>	'owner_id',
	'currency_id'	=>	'currency_id',
	'description'	=>	'description',
	'deleted'		=>	'deleted',
);

sub destroy {
	my $self = shift;

	my @PaperPrices = $self->getPrices('Paper');
	my $ac = sql::start_transaction( $openprint::dbh );
	sql::update( undef, undef, 'companies', ['pricelist_id=?', $$self{'id'}], 'pricelist_id', undef );
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Service_Prices WHERE pricelist_id=?}, $$self{id} );
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM tbl_Material_Prices WHERE lngListIndex=?}, $$self{id} );
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Paper_Prices WHERE lngListIndex=?}, $$self{id} ) if @PaperPrices;
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Product_Prices WHERE pricelist_id=?}, $$self{id} );
    sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Pricelists WHERE id=?}, $$self{id} );
	sql::end_transaction( $openprint::dbh, $ac );
	openprint::logs::insertLogRecord('9', "Price List Index: " . $$self{id},);
} # end sub delete

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
		my @indexes = sql::execute( $openprint::log, $openprint::dbh, q{SELECT id FROM Service_Prices WHERE pricelist_id=?}, $$self{'id'} );
		while ( @indexes ) {
			push @prices, new openprint::ServicePrice( shift @indexes );
		} # end while
	} # end if
	if ( ( ! $type ) or $type eq 'Paper' ) {
		push @prices, openprint::PaperPrice->find( 'pricelist_id'=>$$self{'id'} );
	} # end if
	if ( ( ! $type ) or $type eq 'Product' ) {
		my @indexes = sql::execute( undef, undef, q{SELECT id FROM Product_Prices WHERE pricelist_id=?}, $$self{'id'} );
		while ( @indexes ) {
			push @prices, new openprint::ProductPrice( shift @indexes );
		} # end while
	} # end if
	return @prices;
	
} # end sub getPrices

sub Next {
	my $self = shift;
	my $New = new openprint::Pricelist( sql::execute( undef, undef, q{SELECT MIN(id) FROM pricelists WHERE id > ?}, $$self{'id'} ) );
	if ( ! $New->id() ) {
		$New = new openprint::Pricelist( sql::execute( undef, undef, q{SELECT MAX(id) FROM Pricelists WHERE id <=?},  $$self{'id'} ) );
	} # end if
	return $New;
} # end sub next
sub Previous {
	my $self = shift;
	my $New = new openprint::Pricelist( sql::execute( undef, undef, q{SELECT MAX(Id) FROM pricelists WHERE Id < ?}, $$self{'id'} ) );
	if ( ! $New->id() ) {
		$New = new openprint::Pricelist( sql::execute( $openprint::log, $openprint::dbh, q{SELECT MIN(Id) FROM pricelists WHERE Id >=?},  $$self{'id'} ) );
	} # end if
	return $New;
} # end sub prev

sub Currency {
	my $self = shift;
	return new openprint::Currency( $$self{'currency_id'} );
} # end sub Currency

1;

__END__
~       
