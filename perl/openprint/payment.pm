package openprint::payment;

use strict;
use openprint;
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::Payment;
require openprint::Invoice;

sub history {
	ssi::save_params('/payment/history.html',  'received_on_start_year','received_on_start_month','received_on_start_day','received_on_end_year','received_on_end_month','received_on_end_day', 'company_id' );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'recipient_id'} = $session{'company_id'} if ! $param{'recipient_id'};
		$param{'received_on'} = sprintf('%.4d-%.2d-%.2d', @param{'received_on_year','received_on_month','received_on_day'} );
		my $Payment = new openprint::Payment( $param{'payment_id'} );
		$Payment->remaining( undef ); # force update
		$variable{'error'} .= $Payment->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		my $Payment = new openprint::Payment( $param{'payment_id'} );
		$variable{'error'} .= $Payment->delete();
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Payment = new openprint::Payment( $param{'payment_id'} );
		$variable{'error'} .= $Payment->destroy();
	} # end if
} # end sub history

sub _history {
	ssi::save_params('/payment/history.html',  'received_on_start_year','received_on_start_month','received_on_start_day','received_on_end_year','received_on_end_month','received_on_end_day', 'company_id' );
} # end sub _history

sub edit {
	$variable{'Payment'} = new openprint::Payment( $param{'payment_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'recipient_id'} = $session{'company_id'} if ! $param{'recipient_id'};
		$param{'received_on'} = sprintf('%.4d-%.2d-%.2d', @param{'received_on_year','received_on_month','received_on_day'} );
		my $Payment = new openprint::Payment( $param{'payment_id'} );
		if ( $variable{'error'} .= $variable{'Payment'}->save(\%param) ) {
			$variable{'Redirect'} = '/payment/history.html';
			delete $param{'btnFunction'};
		} # end if
	} # end if
} # end sub edit

sub _paid {
	my $Payment = new openprint::Payment( $param{'payment_id'} );
	if ( $param{'invoice_id'} ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		$Invoice->add_Payment( $Payment );
	} # end if
	$variable{'Payment'} = $Payment;
} # end sub _paid

sub _unpaid {
	my $Payment = new openprint::Payment( $param{'payment_id'} );
	if ( $param{'invoice_id'} ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		$Invoice->del_Payment( $Payment );
	} # end if
	$variable{'Payment'} = $Payment;
} # end sub _paid

 1;
__END__
