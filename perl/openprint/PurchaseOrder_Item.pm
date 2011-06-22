use strict;
package openprint::PurchaseOrder_Item;
our @ISA=qw(openprint::Object);

use openprint ();
use vars qw( $debug $table $serial %fields %transforms %defaults );
require openprint::Company;

$table = 'purchaseorder_items';
$serial = 'purchaseorder_items_id_seq';
%fields = (
	'id'	=>	'id',
	'company_id'	=>	'company_id',
	'vendor_id'		=>	'vendor_id',
	'type_id'		=>	'type_id',
	'name'			=>	'name',
	'price'			=>	'price',
);

%transforms = (
	'name'	=>	[ 's/\.//g', 's/^\s+//', 's/\s+$//' ],
	'price'	=>	[ 's/[^\d\.\-]//g' ],
);

sub Vendor {
	return new openprint::Company( $_[0]{'vendor_id'} );
} # end sub Vendor

1;
__END__
