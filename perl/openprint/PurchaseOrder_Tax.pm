package openprint::PurchaseOrder_Tax;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );

require sql;

$debug = 1;

$table = 'purchaseorder_taxes';
$serial = 'purchaseorder_taxes_id_seq';

%fields = (
	'id'			=>	'id',
	'purchaseorder_id'	=>	'purchaseorder_id',
	'tax_id'		=>	'tax_id',
	'rate'			=>	'rate',
	'amount'		=>	'amount',
	'charge'		=>	'charge',
);

%transforms = (
);
%defaults = (
	'charge'	=>	1,
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
		if ( $$self{'charge'} ) {
			$$self{'amount'} = ($$self{'rate'}/100) * $self->PurchaseOrder()->subtotal();
		} # end if
	} # end if
	return $$self{'amount'};
} # end sub amount

1;
__END__
