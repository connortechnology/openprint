use strict;
require sql;
package openprint::Payment;
our @ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

use vars qw( $debug $table $serial %fields %defaults %transforms );


$debug = 0;
$table = 'payments';
$serial = 'payments_id_seq';
%fields = (
	'id'				=>	'id',
	'order_id'			=>	'order_id',
	'recipient_id'		=>	'owner_id',
	'payor_id'			=>	'company_id',
	'amount'			=>	'curamount',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'method'			=>	'strmethod',
	'currency_id'		=>	'currency_id',
	'transaction_id'	=>	'strtransactionid',
	'memo'				=>	'strdescription',
	'completed'			=>	'completed',
	'received_on'		=>	'dtmdate',
	'remaining'			=>	'remaining',
	'deleted'			=>	'deleted',
);

%transforms = (
);
%defaults = (
	'order_id'		=>	undef,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'completed'		=>	0,
	'deleted'		=>	0,
);

sub destroy {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM ledgers WHERE payment_id=?}, $$self{'id'} );
    return sql::execute( undef, undef, q{DELETE FROM Payments WHERE id=?}, $$self{'id'} );
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
		$$self{'remaining'} = $$self{'amount'} - misc::sum( sql::execute( undef, undef, 'SELECT amount FROM invoices_payments WHERE payment_id=?', $$self{'id'} ) );
	} # end if
	return $$self{'remaining'};
} # end sub remaining

1;
__END__
