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
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'owner_id'} = $session{'company_id'} if ! $param{'owner_id'};
		$param{'starting'} = sprintf('%.4d-%.2d-%2.d %.2d:%.2d:00', @param{'starting_year','starting_month','starting_day','starting_hour','starting_minute'} );
		$param{'ending'} = sprintf('%.4d-%.2d-%2.d %.2d:%.2d:00', @param{'ending_year','ending_month','ending_day','ending_hour','ending_minute'} );
		my $Payment = new openprint::Payment( $param{'payment_id'} );
		$variable{'error'} .= $Payment->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Payment = new openprint::Payment( $param{'payment_id'} );
		$variable{'error'} .= $Payment->destroy();
	} # end if
} # end sub history

sub _history {
} # end sub _history

sub edit {
	$variable{'Payment'} = new openprint::Payment( $param{'payment_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $variable{'Payment'}->save(\%param);
		$variable{'Redirect'} = '/payment/history.html';
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
