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

sub make {
	$param{'order_id'} = $param{'OrderID'} if $param{'OrderID'};
	$variable{'Order'} = new openprint::Order( $param{'order_id'} );

	$variable{'Payment'} = new openprint::Payment( $param{'payment_id'} );
	
	$variable{'Payment'}->set( \%param );
	$variable{'Payment'}->amount( $variable{'Order'}->balance() ) if ! $variable{'Payment'}->amount();

	if ( $param{'btnFunction'} eq 'ExpressCheckOut' ) {
		# Express CheckOut takes an Order
		my $Order = new openprint::Order( $param{'order_id'} );
		require PayPal;
		my $Paypal=PayPal->new('api_USER'=>$config{'PayPal API Username'},'api_PWD'=>$config{'PayPal API Password'},'api_SIGNATURE'=>$config{'PayPal API Signature'} );
		my $result = $Paypal->Call_Service({
					METHOD			=>	'SetExpressCheckout',
					PAYMENTACTION	=>	'Sale',
					CURRENCYCODE	=>	openprint::Currency::get_current()->short(),
					AMT				=>	$Order->balance(),
					RETURNURL		=>	$config{'ExternalSiteURL'}.'/payment/make.html',
					CANCELURL		=>	$config{'ExternalSiteURL'}.'/payment/make.html',
					});
		if ($$result{ack} ne 'Success') {
			$variable{'error'} .= 'Api call failed:<br/>';
			foreach my $error ( $Paypal->Parse_Errors($result) ) {
				$variable{'error'} .= "$$error{errorcode} $$error{longmessage}<br/>";
			} # end foreach error
		} else {
			my $token = $$result{'TOKEN'};	
			$r->headers_out->(Location=>$Paypal::url.$token);
			return;
		} # end if
		
	} elsif ( $param{'btnFunction'} eq 'Submit' ) {
		if ( $variable{'Payment'}->Type()->name() eq 'PayPal' ) {
			require PayPal;

			my $Paypal=PayPal->new('api_USER'=>$config{'PayPal API Username'},'api_PWD'=>$config{'PayPal API Password'},'api_SIGNATURE'=>$config{'PayPal API Signature'} );

			my $result = $Paypal->Call_Service({
					#METHOD=>'GetBalance',
					METHOD			=>	'SetExpressCheckout',
					PAYMENTACTION	=>	'Sale',
					AMT				=>	$param{'amount'},
					#COUTNRYCODE=>'CA',

					#creditcardtype=>$param{'cc_type'},
					acct=>$param{'cc_number'},
					expdate=>$param{'exp_month'}.$param{'exp_year'},
					cvv2=>$param{'cc_cvv2'},
					#firstname=>$param{'firstname'},
					#lastname=>$param{'lastname'},
					#street=>$param{'address1'},
					#city=>$param{'city'},
					#state=>$param{'state'},
					#zip=>$param{'postalcode'},
					#country=>$param{'country'},
					RETURNURL=>$config{'ExternalSiteURL'}.'/payment/make.html',
					CANCELURL=>$config{'ExternalSiteURL'}.'/payment/make.html',
					});

			if ($$result{ack} eq 'Success') {
				$variable{'information'} = 'Api call successfull<br/>';
			} else {
				$variable{'error'} .= 'Api call failed:<br/>';
				foreach my $error ( $Paypal->Parse_Errors($result) ) {
					$variable{'error'} .= "$$error{errorcode} $$error{longmessage}<br/>";
				} # end foreach error
			} # end if
		} # end if PaymentProcessor == Paypal
	} elsif ( $param{'btnFunction'} eq '' ) {
	} else {
		$log->error("Unknown btnFunction in payment::make : $param{'btnFunction'}");
	} # end if btnFunction
} # end sub make

 1;
__END__
