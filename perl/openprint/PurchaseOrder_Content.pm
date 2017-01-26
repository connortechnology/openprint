use strict;
package openprint::PurchaseOrder_Content;
our @ISA = qw(openprint::Object);

require openprint;
use vars qw( $debug $table $serial %fields %transforms %defaults );

require openprint::PurchaseOrder_ContentType;
require openprint::PurchaseOrder_Item;
require openprint::PurchaseOrder_Department;

$debug = 0;
$table = 'PurchaseOrder_Contents';
$serial = 'PurchaseOrder_Contents_id_seq';

%fields = (
	id				=>	'id',
	po_id			=>	'po_id',
	created_on		=>	'created_on',
	qty				=>	'qty',
	price			=>	'price',
	price_units		=>	'price_units',
	total			=>	'total',
	product			=>	'product',
	item			=>	'item',
	item_id			=>	'item_id',
	docket			=>	'docket',
	description		=>	'description',
	type_id			=>	'type_id',
	type			=>	undef,
	department_id	=>	'department_id',
	department		=>	undef,
	object_type_id	=>	undef,
	object_id		=>	undef,
);

%transforms = (
	price			=>	[ 's/[^\-\d\.]//g' ],
	total			=>	[ 's/[^\-\d\.]//g' ],
	qty				=>	[ 's/[^\-\d\.]//g' ],
);

%defaults = (
	po_id			=>	undef,
	created_on		=>	q`'NOW()'`,
	price			=>	undef,
	total			=>	undef,
	qty				=>	undef,
	type_id			=>	undef,
	item_id			=>	undef,
	department_id	=>	undef,
	object_type_id	=>	undef,
	object_id		=>	undef,
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
			$_[0]{type_id} = $Type->id();
			return $Type->name();
		} # end if
	} # end if
	return new openprint::PurchaseOrder_ContentType( $_[0]{type_id} )->name();
} # end sub type

sub Department {
	return new openprint::PurchaseOrder_Department( $_[0]{department_id} );
} # end sub Department

sub department {
	if ( @_ > 1 ) {
		$_[1] = openprint::PurchaseOrder_Department->transform( 'name', $_[1] );
		my $Department = openprint::PurchaseOrder_Department->find_one('name'=>$_[1]);
		if ( $Department ) {
			$_[0]{department_id} = $Department->id();
			return $Department->name();
		} else {
			$Department = new openprint::PurchaseOrder_Department();
			$Department->save({'name'=>$_[1]});
			$_[0]{department_id} = $Department->id();
			return $Department->name();
		} # end if
	} # end if
	return new openprint::PurchaseOrder_Department( $_[0]{department_id} )->name();
} # end sub department

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
	return new openprint::PurchaseOrder_Item( $_[0]{item_id} );
} # end sub Item

sub item {
	my $Item = new openprint::PurchaseOrder_Item( $_[0]{item_id} );
	if ( @_ > 1 ) {
		if ( $Item->name() ne $_[1] ) {
			my $NewItem = openprint::PurchaseOrder_Item->find_one( 'name lc'=>lc $_[1], 'company_id'=>$_[0]->PurchaseOrder()->company_id(), 'vendor_id'=>$_[0]->PurchaseOrder()->supplier_id(), 'type_id'=>$_[0]{type_id} );
			if ( ! $NewItem ) {
				$NewItem = new openprint::PurchaseOrder_Item();
				$NewItem->save( { 
					'name'=>$_[1], 
					'company_id'=>$_[0]->PurchaseOrder()->company_id(), 
					'vendor_id'=>$_[0]->PurchaseOrder()->supplier_id(), 
					'type_id'=>$_[0]{type_id},
					'price'	=>	$_[0]{price},
					'product'	=>	$_[0]{product},
				 } );
			} # end if
			$_[0]{item_id} = $$NewItem{id};
		} # end if
	} # end if
	if ( ! $Item->id() ) {
		return $_[0]{item};
	} # end if
	return $Item->name();
} # end sub item

sub Order {
	my $docket = $_[0]{docket};
	$docket =~ s/\D//g;
	$_ = openprint::Order->find_one('docket'=>$docket) if $docket;
	return $_ if $_;
	return new openprint::Order();
} # end sub Order

sub Orders {
	my @dockets = map { $_ ? $_ : () } split( /\D/, $_[0]{docket} );
	return openprint::Order->find(docket=>\@dockets) if @dockets;
	return ();
} # end sub Orders

sub can_view {
	return 1 if ! $_[0]{id};
	my $User = $_[1] ? $_[1] : $openprint::User;
	if ( 
			( $$User{type} eq 'A' )
			or ( sets::isin( $_[0]->PurchaseOrder->created_by(), [ $$User{id}, $User->assistant_ids(), $User->csr_ids() ] ) )
			or ( openprint::usergroup::is_user_in( ['Accounting','Shipping','Inventory'], $$User{id} ) ) 
			or ( sets::isin( $$User{id}, [ map { $_->salesrep_id() } $_[0]->Orders() ] ) )
	   ) {
		return 1;
	} # end if
	if ( my @notifications = $_[0]->PurchaseOrder()->notifications() ) {
		if ( sets::isin( $$User{id}, \@notifications ) ) {
			$openprint::log->debug($$User{firstname} . ' can see because in notifications.' ) if $debug;
			return 1;
		} # end if
	} # end if
	return 0;
} # end sub can_view

sub mprice {
	return if $_[0]->type() ne 'Sheet Stock';
	my ( $mweight, $type, $name ) = $_[0]->item() =~ /^([\d\.]+)M *([\w\/]*) *(.*)$/;
	return Math::Round::nearest(0.01, $_[0]{price} * $mweight / 100 );
} # end sub mprice

sub Manifest_Content_Type {
	if ( !  $_[0]{Manifest_Content_Type} ) {
		$_[0]{Manifest_Content_Type} = openprint::Manifest_Content_Type->find_one( po_content_id=>$_[0]{id} );
	} 
	return $_[0]{Manifest_Content_Type};
}

1;
__END__
