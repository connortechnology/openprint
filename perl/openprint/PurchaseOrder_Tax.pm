use strict;
package openprint::PurchaseOrder_Tax;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );

$debug = 0;
$table = 'purchaseorder_taxes';
$serial = 'purchaseorder_taxes_id_seq';

%fields = (
	id					=>	'id',
	purchaseorder_id	=>	'purchaseorder_id',
	PurchaseOrder		=>	undef,
	tax_id				=>	'tax_id',
	rate				=>	'rate',
	amount				=>	'amount',
	charge				=>	'charge',
);

%transforms = (
);
%defaults = (
	'rate'		=>	undef,
	'amount'	=>	undef,
);

sub name {
	return $_[0]->Tax()->name();
} # end sub name

sub amount {
	if ( @_ > 1 ) {
		$_[0]{amount} = $_[1];
	} # end if
	if ( ! defined $_[0]{amount} ) {
#$openprint::log->debug("caculating amount: $_[0]{purchaseorder_id}" .$_[0]->PurchaseOrder()->subtotal().' charge: ' . $_[0]->charge() );
		if ( $_[0]->charge() ) {
			$_[0]{amount} = Math::Round::nearest( 0.01, ($_[0]{'rate'}/100) * $_[0]->PurchaseOrder()->subtotal() );
		} # end if
	} # end if
	return $_[0]{amount};
} # end sub amount

sub charge {
	my $self = $_[0];
	if ( @_ == 2 ) {
		$$self{'charge'} = $_[1];
	} # end if

	if ( $self->PurchaseOrder()->supplier_id() and ! defined $$self{'charge'} ) {
#$openprint::log->debug("Calculating Tax: " . $self->name() . 'exempt: ' . $self->PurchaseOrder()->Supplier()->taxexempt1() );
		if ( sets::isin( $self->name(), ['GST','HST'] ) ) {
			if ( $self->PurchaseOrder()->Supplier()->taxexempt1() eq 'Y' ) {
				return 0;
			} # end if
			return 1;
		} elsif ( sets::isin( $self->name(), ['PST'] ) ) {
			if ( $self->PurchaseOrder()->Supplier()->taxexempt2() eq 'Y' ) {
				return 0;
			} # end if
			return 1;
		} # end if 
	} # end if
	return $$self{'charge'};
} # end sub charge

sub PurchaseOrder {
	if ( @_ > 1 ) {
		$_[0]{'PurchaseOrder'} = $_[1];
		if ( $_[1]{'id'} ) {
			$_[0]{'purchaseorder_id'} = $_[1]{'id'};
		} # end if
	} 
	if ( ! defined $_[0]{'PurchaseOrder'} ) {
	 	$_[0]{'PurchaseOrder'} = new openprint::PurchaseOrder( $_[0]{'purchaseorder_id'} );
	} # end if
	return $_[0]{'PurchaseOrder'};
} # end sub PurchaseOrder	

1;
__END__
