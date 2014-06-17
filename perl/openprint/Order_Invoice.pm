use strict;
package openprint::Order_Invoice;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table @identified_by %fields %defaults %transforms );

require openprint::Order;
require openprint::Invoice;

$debug = 1;

$table = 'order_invoices';
@identified_by = ( 'order_id', 'invoice_id' );

%fields = (
	order_id		=>	'order_id',
	invoice_id		=>	'invoice_id',
);

%transforms = (
);
%defaults = (
);

sub Order {
	return new openprint::Order( $_[0]{order_id} );
} 
sub Invoice {
	return new openprint::Invoice( $_[0]{invoice_id} );
} 

1;
__END__
