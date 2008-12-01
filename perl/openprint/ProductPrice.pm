package openprint::ProductPrice;
@ISA = qw(openprint::Object);

use strict;

use openprint ();
use vars qw(%variable $log $dbh);
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require openprint::logs;

my $debug = 1;

sub find {
	my %params = @_;

	my @values;
	my $sql = q{SELECT * FROM Product_Prices WHERE 1>0};
	if ( $params{'id'} ) {
		$sql .= q{ AND id=?};
		push @values, $params{'id'};
	} # end if

	if ( $params{'Product'} ) {
		$sql .= q{ AND product_id=?};
		push @values, $params{'Product'}->id();
	} # end if
	if ( $params{'product_id'} ) {
		$sql .= q{ AND product_id=?};
		push @values, $params{'product_id'};
	} # end if
	if ( $params{'Pricelist'} ) {
		$sql .= q{ AND pricelist_id=?};
		push @values, $params{'Pricelist'}->id();
	} # end if
	if ( $params{'pricelist_id'} ) {
		$sql .= q{ AND pricelist_id=?};
		push @values, $params{'pricelist_id'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};

	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
    if ( ! $data ) {
        $log->warn("Error loading ProductPrice: ($sql) (@values)" . $dbh->errstr );
        return;
    } elsif ($debug ) {
        $log->debug("openprint::ProductPrice::find($sql) (@values)");
    } # end if
    return map { new openprint::ProductPrice( $_->{id}, $_ ); } @$data;

} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $dbh->selectrow_hashref( 'SELECT * FROM Product_Prices WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $log->debug($dbh->errstr ); }
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub delete {
	my $self = shift;
	sql::execute( $log, $dbh, q{DELETE FROM Product_Prices WHERE id=?}, $$self{'id'} );
	logs::insertLogRecord('18', "Product Price ID: " . $$self{'id'} . " Price: " . $$self{'price'},);
} # end sub delete

sub save {
	my ( $self, $param ) = @_;
	
	my @sql = (
				'pricelist_id',		$$self{'pricelist_id'},
				'product_id',		$$self{'product_id'},
				'min',				$$self{'min'} ? $$self{'min'} : undef,
				'max',				$$self{'max'} ? $$self{'max'} : undef,
				'units',			$$self{'units'},
				'cost',				1*$$self{'cost'},
				'markup',			1*$$self{'markup'},
				'price',			1*$$self{'price'},
				'discountable',		$$self{'discountable'} ? 'true' : 'false',
);

	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( $log, $dbh, q{SELECT nextval('Product_Prices_id_seq')} );

		sql::insert( $log, $dbh, 'Product_Prices', 'id', $$self{'id'}, @sql );
	} else {
		sql::update( $log, $dbh, 'Product_Prices', ['id=?',$$self{'id'}], @sql );
	} # end if
	$self->load();
} # end sub save

sub next {
	my $self = shift;
	my $new = new openprint::Product( sql::execute( $log, $dbh, q{SELECT MIN(Index) WHERE Index > ?}, $$self{'id'} ) );
	return $new;
} # end sub next

sub Product {
    my $self = shift;
	if ( @_ ) {
		my $Product = shift;
		$$self{'product_id'} = $Product->id();
	} # end if
    return new openprint::Product( $$self{'product_id'} );
} # end sub Product

sub Pricelist {
    my $self = shift;
	if ( @_ ) {
		my $Pricelist = shift;
		$$self{'pricelist_id'} = $Pricelist->id();
	} # end if
    return new openprint::Pricelist( $$self{'pricelist_id'} );
} # end sub Pricelist

1;

__END__
~       
