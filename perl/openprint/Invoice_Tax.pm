package openprint::Invoice_Tax;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );

require sql;

$debug = 1;

$table = 'invoice_taxes';
$serial = 'invoice_taxes_id_seq';

%fields = (
	'id'			=>	'id',
	'invoice_id'	=>	'invoice_id',
	'tax_id'		=>	'tax_id',
	'rate'			=>	'rate',
	'amount'		=>	'amount',
);

%transforms = (
);
%defaults = (
);

sub name {
	return $_[0]->Tax()->name();
} # end sub name

sub amount {
	my $self = $_[0];
	if ( @_ == 2 ) {
		$$self{'amount'} = $_[1];
	} # end if

	if ( $$self{'invoice_id'} and ! defined $$self{'amount'} ) {
		$$self{'amount'} = ($$self{'rate'}/100) * $self->Invoice()->subtotal();
	} # end if
	return sprintf('%.2f', $$self{'amount'} );
} # end sub amount

1;
__END__
