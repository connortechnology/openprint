use strict;
package openprint::PurchaseOrder_Item;
our @ISA=qw(openprint::Object);

use openprint ();
use vars qw( $debug $table $serial %fields %transforms %defaults );
require openprint::Company;
require openprint::PurchaseOrder_ContentType;

$debug = 1;
$table = 'purchaseorder_items';
$serial = 'purchaseorder_items_id_seq';
%fields = (
	'id'	=>	'id',
	'company_id'	=>	'company_id',
	'vendor_id'		=>	'vendor_id',
	'type_id'		=>	'type_id',
	'name'			=>	'name',
	'description'	=>	'description',
	'price'			=>	'price',
	'product'		=>	'product',
);

%transforms = (
	'name'	=>	[ 's/^\s+//', 's/\s+$//' ],
	'product'	=>	[ 's/^\s+//', 's/\s+$//' ],
	'price'	=>	[ 's/[^\d\.\-]//g' ],
);
%defaults = (
	'price'	=>	undef,
);

sub Vendor {
	return new openprint::Company( $_[0]{'vendor_id'} );
} # end sub Vendor

sub Type {
	return new openprint::PurchaseOrder_ContentType( $_[0]{type_id} );
} # end sub Type

sub type {
	if ( @_ > 1 ) {
		my $Type = openprint::PurchaseOrder_ContentType->find_one('name'=>$_[1]);
		if ( $Type ) {
			$_[0]{'type_id'} = $Type->id();
			return $Type->name();
		}
	}
	return new openprint::PurchaseOrder_ContentType( $_[0]{'type_id'} )->name();
} # end sub type

1;
__END__
