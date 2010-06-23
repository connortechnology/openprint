package openprint::Invoiced_Product;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 0;

use strict;
use vars qw( $table $serial %fields %defaults %transforms %find_cache );

$table = 'invoiced_products';
$serial = 'invoiced_products_id_seq';

require sql;

%fields = (
	'id'				=>	'id',
	'price'				=>	'price',
	'quantity'			=>	'quantity',
	'invoice_id'		=>	'invoice_id',
	'product_id'		=>	'product_id',
	'description'		=>	'description',
);

%transforms = (
);
%defaults = (
	'invoice_id'	=>	undef,
	'product_id'	=>	undef,
	'price'			=>	0,
	'quantity'		=>	undef,
);

sub Invoice {
	return new openprint::Invoice( $_[0]{invoice_id} );
} # end sub Invoice

sub Product {
	return new openprint::Product( $_[0]{product_id} );
} # end sub Product

sub name {
	return $_[0]->Product()->name();
} # end sub name

sub total {
	my ( $self ) = @_;
	return $$self{'quantity'} * $$self{'price'};
} # end sub total

sub description {
	my ( $self ) = @_;
	if ( ( ! $$self{'description'} ) and $$self{'product_id'} ) {
		$$self{'description'} = $self->Product()->name();
	} # end if
	return $$self{'description'};
} # end if

1;

__END__
~       
