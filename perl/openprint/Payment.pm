use strict;
package openprint::Payment;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );

require sql;
require openprint::PaymentType;

$debug = 1;
$table = 'payments';
$serial = 'payments_id_seq';

%fields = (
	'id'				=>	'id',
	'order_id'			=>	'order_id',
	'recipient_id'		=>	'owner_id',
	'payor_id'			=>	'payor_id',
	'amount'			=>	'amount',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'method'			=>	'method',
	'currency_id'		=>	'currency_id',
	'transaction_id'	=>	'transaction_id',
	'memo'				=>	'memo',
	'completed'			=>	'completed',
	'received_on'		=>	'received_on',
	'remaining'			=>	'remaining',
	'deleted'			=>	'deleted',
	'type_id'			=>	'type_id',
);

%transforms = (
	'amount'	=>	[ 's/[^\d\.]//g' ],
);
%defaults = (
	'order_id'		=>	undef,
	'created_on'	=> q`'NOW()'`,
	'updated_on'	=> q`'NOW()'`,
	'received_on'	=>	q`'NOW()'`,
	'completed'		=>	0,
	'deleted'		=>	0,
);

sub destroy {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM ledgers WHERE payment_id=?}, $$self{'id'} );
    return $self->SUPER::destroy();
} # end sub destroy

sub Payor {
	return new openprint::Company( $_[0]{payor_id} );
} # end sub Payor

sub Recipient {
	return new openprint::Company( $_[0]{owner_id} );
} # end sub Recipient

sub Currency {
	return new openprint::Currency( $_[0]{currency_id} );
} # end sub Currency
sub Order {
	return new openprint::Order( $_[0]{order_id} );
} # end sub Order

sub remaining {
	my $self = shift;
	if ( @_ ) {
		$$self{'remaining'} = $_[0];
	} # end if
	if ( ! defined $$self{'remaining'} ) {
		$$self{'remaining'} = $$self{'amount'} - misc::sum( map { $_->amount() } openprint::Invoice_Payment->find('payment_id'=>$$self{'id'}) );
	} # end if
	return $$self{'remaining'};
} # end sub remaining

sub Type {
	return new openprint::PaymentType( $_[0]{'type_id'} );
} # end sub Type

1;
__END__
