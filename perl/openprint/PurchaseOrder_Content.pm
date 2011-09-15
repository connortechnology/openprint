use strict;
package openprint::PurchaseOrder_Content;
our @ISA = qw(openprint::Object);
require openprint::Object;

use openprint ();
use vars qw(%variable $log $dbh $debug $table $serial %config %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require openprint::PurchaseOrder_ContentType;
require openprint::PurchaseOrder_Item;

$debug = 1;
$table = 'PurchaseOrder_Contents';
$serial = 'PurchaseOrder_Contents_id_seq';

%fields = (
	'id'			=>	'id',
	'po_id'			=>	'po_id',
	'created_on'	=>	'created_on',
	'qty'			=>	'qty',
	'price'			=>	'price',
	'total'			=>	'total',
	'product'		=>	'product',
	'item'			=>	'item',
	'item_id'		=>	'item_id',
	'docket'		=>	'docket',
	'description'	=>	'description',
	'type_id'		=>	'type_id',
	'type'			=>	undef,
);

%transforms = (
	'price'			=>	[ 's/[^\-\d\.]//g' ],
	'total'			=>	[ 's/[^\-\d\.]//g' ],
	'qty'			=>	[ 's/[^\-\d\.]//g' ],
);

%defaults = (
	'po_id'			=>	undef,
	'created_on'	=> q`'NOW()'`,
	'price'			=>	undef,
	'total'			=>	undef,
	'qty'			=>	undef,
	'type_id'		=>	undef,
	'item_id'		=>	undef,
);

sub PurchaseOrder {
	return new openprint::PurchaseOrder( $_[0]{po_id} );
} # end sub Supplier

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
} # en dsub type

sub units {
	my ( $self ) = @_;
	if ( $self->Type()->name() eq 'Roll Stock' ) {
		return 'lbs';
	} elsif ( $self->Type()->name() eq 'Sheet Stock' ) {
		return 'sheets';
	} # end if
	return;
} # end sub units

sub Item {
	return new openprint::PurchaseOrder_Item( $_[0]{'item_id'} );
} # end sub Item

sub item {
	my $Item = new openprint::PurchaseOrder_Item( $_[0]{'item_id'} );
	if ( @_ > 1 ) {
		if ( $Item->name() ne $_[1] ) {
			my $NewItem = openprint::PurchaseOrder_Item->find_one( 'name lc'=>lc $_[1], 'company_id'=>$_[0]->PurchaseOrder()->company_id(), 'vendor_id'=>$_[0]->PurchaseOrder()->supplier_id(), 'type_id'=>$_[0]{'type_id'} );
			if ( ! $NewItem ) {
				$NewItem = new openprint::PurchaseOrder_Item();
				$NewItem->save( { 
					'name'=>$_[1], 
					'company_id'=>$_[0]->PurchaseOrder()->company_id(), 
					'vendor_id'=>$_[0]->PurchaseOrder()->supplier_id(), 
					'type_id'=>$_[0]{'type_id'},
					'price'	=>	$_[0]{'price'},
					'product'	=>	$_[0]{'product'},
				 } );
			} # end if
			$_[0]{'item_id'} = $$NewItem{'id'};
		} # end if
	} # end if
	if ( ! $Item->id() ) {
		return $_[0]{'item'};
	} # end if
	return $Item->name();
} # end sub item

sub Order {
	return openprint::Order->find_one('docket'=>$_[0]{'docket'}) if $_[0]{'docket'};
	return new openprint::Order();
} # end sub Order

sub can_view {
	return 1 if ! $_[0]{'id'};
	if ( 
			( $openprint::session{'user_type'} eq 'A' )
			or ( sets::isin( $_[0]->PurchaseOrder->created_by(), [ $openprint::session{'user_id'}, new openprint::User($openprint::session{'user_id'})->assistant_ids(), new openprint::User($openprint::session{'user_id'})->csr_ids() ] ) )
			or ( openprint::usergroup::is_user_in( ['Accounting','Shipping','Inventory'], $openprint::session{'user_id'} ) ) 
			or ( $openprint::session{'user_id'} == $_[0]->Order()->salesrep_id() )
	   ) {
		return 1;
	} # end if
	return 0;
} # end sub can_view
1;
__END__
