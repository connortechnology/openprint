package openprint::ProductPrice;
@ISA = qw(openprint::Object);

use strict;

require sql;
require openprint::logs;
use openprint ();
use vars qw(%variable $log $dbh $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'Product_Prices';
$serial = 'product_prices_id_seq';
%fields = (
		'id'	=>	'id',
		'product_id'	=>	'product_id',
		'pricelist_id'	=>	'pricelist_id',
		'min'			=>	'min',
		'max'			=>	'max',
		'units'			=>	'units',
		'cost'			=>	'cost',
		'markup'		=>	'markup',
		'price'			=>	'price',
		'discountable'	=>	'discountable',
		'owner_id'		=>	'owner_id',
		);
%transforms = (
	'id'	=>	[ 's/\D//g' ],
	'product_id'	=>	[ 's/\D//g' ],
	'pricelist_id'	=>	[ 's/\D//g' ],
	'min'		=>	[ 's/\D//g' ],
	'max'		=>	[ 's/\D//g' ],
	'cost'		=>	[ 's/[^\d\.]//g' ],
	'markup'	=>	[ 's/[^\d\.]//g' ],
	'price'		=>	[ 's/[^\d\.]//g' ],
);
%defaults = (
	'min'	=>	undef,
	'max'	=>	undef,
	'cost'	=>	0,
	'markup'	=>	0,
	'price'		=>	0,
	'discountable'	=>	1,
);


my $debug = 0;

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

sub save {
	my ( $self, $param ) = @_;

	$$self{'owner_id'} = $openprint::config{'Owner'} if ! $$self{'owner_id'};

	if ( ( my $error = $self->SUPER::save( $param ) ) ) {
		return $error;
	} # end if
} # end sub save

1;

__END__
~       
