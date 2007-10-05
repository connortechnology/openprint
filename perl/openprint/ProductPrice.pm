package openprint::ProductPrice;

use strict;

use openprint ();
use vars qw(%variable);
*variable = \%openprint::variable;

require sql;
require openprint::logs;

sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::ProductPrice( $params{'id'} );
	} else {
		my @values;
		my $sql = q{SELECT id FROM Product_Prices WHERE 1>0};
		if ( $params{'product'} ) {
			$sql .= q{ AND product_id=?};
			push @values, $params{'product'}->id();
		} elsif ( $params{'product_id'} ) {
			$sql .= q{ AND product_id=?};
			push @values, $params{'product_id'};
		} # end if
		if ( $params{'pricelist'} ) {
			$sql .= q{ AND pricelist_id=?};
			push @values, $params{'pricelist'}->id();
		} elsif ( $params{'pricelist_id'} ) {
			$sql .= q{ AND pricelist_id=?};
			push @values, $params{'pricelist_id'};
		} # end if
		$sql .= " ORDER BY $params{'order'}" if $params{'order'};
		return map { new openprint::ProductPrice( $_ ) } sql::execute( $openprint::log, $openprint::dbh, $sql, @values );
	} # end if
} # end sub find

sub new {
	my $self = {};
	bless $self, shift;
	$self->load() if $$self{'id'} = shift;
	return $self;
} # end sub new

sub load {
	my $self = shift;

	if ( $$self{'id'} ) {
		@$self{'pricelist_id','product_id','min','max','units','cost','markup','price','discountable'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT pricelist_id, product_id, min, max, units,cost, markup, price, discountable FROM Product_Prices WHERE id=?}, $$self{'id'} );
	} # end if

} # end sub load

sub delete {
	my $self = shift;
   sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Product_Prices WHERE id=?}, $$self{'id'} );
   openprint::logs::insertLogRecord('18', "Product Price ID: " . $$self{'id'} . " Price: " . $$self{'price'},);
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
		@$self{'id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('Product_Prices_id_seq')} );

		sql::insert( $openprint::log, $openprint::dbh, 'Product_Prices', 'id', $$self{'id'}, @sql );
	} else {
		sql::update( $openprint::log, $openprint::dbh, 'Product_Prices', "id=$$self{'id'}", @sql );
	} # end if
	$self->load();
} # end sub save

sub next {
	my $self = shift;
	my $new = new openprint::Product( sql::execute( $openprint::log, $openprint::dbh, q{SELECT MIN(Index) WHERE Index > ?}, $$self{'id'} ) );
	return $new;
} # end sub next

sub id {
    my $self = shift;
    $$self{'id'} = shift if @_;
    return $$self{'id'};
} # end sub id
sub product {
    my $self = shift;
	if ( @_ ) {
		my $Product = shift;
		$$self{'product_id'} = $Product->id();
	} # end if
    return new openprint::Product( $$self{'product_id'} );
} # end sub min
sub product_id {
    my $self = shift;
    $$self{'product_id'} = shift if @_;
    return $$self{'product_id'};
} # end sub min
sub pricelist {
    my $self = shift;
	if ( @_ ) {
		my $Pricelist = shift;
		$$self{'pricelist_id'} = $Pricelist->id();
	} # end if
    return new openprint::Pricelist( $$self{'pricelist_id'} );
} # end sub min
sub pricelist_id {
    my $self = shift;
    $$self{'pricelist_id'} = shift if @_;
    return $$self{'pricelist_id'};
} # end sub min

sub min {
    my $self = shift;
    $$self{'min'} = shift if @_;
    return $$self{'min'};
} # end sub min
sub max {
    my $self = shift;
    $$self{'max'} = shift if @_;
    return $$self{'max'};
} # end sub max
sub units {
    my $self = shift;
    $$self{'units'} = shift if @_;
    return $$self{'units'};
} # end sub max
sub cost {
    my $self = shift;
    $$self{'cost'} = shift if @_;
    return $$self{'cost'};
} # end sub cost
sub markup {
    my $self = shift;
    $$self{'markup'} = shift if @_;
    return $$self{'markup'};
} # end sub markup
sub price {
    my $self = shift;
    $$self{'price'} = shift if @_;
    return $$self{'price'};
} # end sub price
sub discountable {
    my $self = shift;
    $$self{'discountable'} = shift if @_;
    return $$self{'discountable'};
} # end sub discountable


1;

__END__
~       
