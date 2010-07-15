package openprint::PurchaseOrder_Tax;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );

$debug = 1;
$table = 'purchaseorder_taxes';
$serial = 'purchaseorder_taxes_id_seq';

%fields = (
	'id'				=>	'id',
	'purchaseorder_id'	=>	'purchaseorder_id',
	'tax_id'			=>	'tax_id',
	'rate'				=>	'rate',
	'amount'			=>	'amount',
	'charge'			=>	'charge',
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
	my $self = $_[0];
	if ( @_ == 2 ) {
		$$self{'amount'} = $_[1];
	} # end if

	if ( ! defined $$self{'amount'} ) {
		if ( $self->charge() ) {
			$$self{'amount'} = sprintf('%.2f', ($$self{'rate'}/100) * $self->PurchaseOrder()->subtotal() );
		} # end if
	} # end if
	return $$self{'amount'};
} # end sub amount

sub charge {
	my $self = $_[0];
	if ( @_ == 2 ) {
		$$self{'charge'} = $_[1];
	} # end if

	if ( $self->PurchaseOrder()->supplier_id() and ! defined $$self{'charge'} ) {
$openprint::log->debug("Calculating Tax: " . $self->name() );
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

1;
__END__
