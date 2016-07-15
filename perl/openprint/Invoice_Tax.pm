use strict;
require Math::Round;
require openprint::Tax;
package openprint::Invoice_Tax;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );

$debug = 0;

$table = 'invoice_taxes';
$serial = 'invoice_taxes_id_seq';

%fields = (
	id			=>	'id',
	invoice_id	=>	'invoice_id',
	tax_id		=>	'tax_id',
	rate		=>	'rate',
	amount		=>	'amount',
);

%transforms = (
);
%defaults = (
);

sub Tax {
	return new openprint::Tax( $_[0]{tax_id} );
} # end sub Tax

sub name {
	return $_[0]->Tax()->name();
} # end sub name

sub amount {
	my $self = $_[0];
	if ( @_ == 2 ) {
		$$self{amount} = $_[1];
	} # end if

	if ( $$self{invoice_id} and ! defined $$self{amount} ) {
		$$self{amount} = ($$self{rate}/100) * $self->Invoice()->subtotal();
	} # end if
	return Math::Round::nearest( 0.01, $$self{amount} );
} # end sub amount

1;
__END__
