package openprint::employee_accounting;

use Text::CSV_XS;
use strict;

require openprint::Payment;
require openprint::order;
require openprint::Order;
require misc;
require sql;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;

sub search {
	if ( $param{'btnFunction'} eq 'Go' ) {
        if ( $param{'StartDocket'} ) {
            my @orders = openprint::Order::find('docket'=>$param{'StartDocket'},'id'=>$param{'order_id'}, 'invoice_id'=>$param{'invoice_id'} );
            if ( @orders == 1 ) {
                $param{'order_id'} = $orders[0]->id();
                $variable{'Redirect'} = '/employee/accounting/details.html';
                return;
            } # end if
        } elsif ( $param{'project_id'} ) {
			my $Project = new openprint::Project( $param{'project_id'} );
			if ( $Project->id() and $Project->order_id() ) {
                $param{'order_id'} = $Project->order_id();
                $variable{'Redirect'} = '/employee/accounting/details.html';
                return;
            } # end if
        } # end if
    } # end if

} # end sub order_report

sub details {

    my $order_id = $param{'order_id'};
	my $Order = new openprint::Order( $order_id );

	if ( $param{'btnFunction'} eq 'Send' ) {
		openprint::order::send_sales_order( $r, $log, $dbh, $order_id );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		my $payment_index = $param{'PaymentIndex'};
		$payment_index =~ s/\D//g;
		if ( $payment_index ) {
			sql::execute( $log, $dbh, "DELETE FROM Payments WHERE id=$payment_index" );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Pay' ) {
		$Order->pay();
	} elsif ( $param{'btnFunction'} eq 'Invoice' ) {
		$Order->invoice_id( $param{'invoice_id'} );
		$Order->invoiced_on( 'NOW()' );
		$Order->save();
    } elsif ( $param{'btnFunction'} eq 'Save' ) {
		
		if ( ( ! $param{'Amount'} ) or $param{'Amount'} =~ /[^-\$\d\.]/ ) {
			return misc::error( $log, $dbh, \%variable, 'Invalid Amount', 'Please enter a valid monetary amount.' );
		} # end if

		my $Payment = new openprint::Payment();
		my $error = $Payment->save( {
			'order_id'		=> $order_id,
			'company_id'	=> $Order->company_id(),
			'amount'		=> $param{'Amount'},
			'method'		=> 'Manual',
			'currency_id'	=> $Order->currency_id(),
			'description'	=> $param{'Description'},
			'completed'		=> 1,
		} );
		if ( $error ) {
			return misc::error( $log, $dbh, \%variable, 'Error Saving Payment', $error );
		} # end if

		openprint::order::get_misc( $log, $dbh, \%variable, $order_id );

		if ( $variable{'DepositDue'} > 0 ) {
			foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
				sql::update( $log, $dbh, 'Projects', ['Index=? AND strStatus=?', $project_index, 'In Prepress'], 'strStatus', 'Pending Deposit' );
				sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND strStatus='Ordered'", 'strStatus', 'Pending Deposit' );
			} # end foreach
		} else {
			$Order->status('In Production') if $Order->status() eq 'Pending Deposit';

			foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
				sql::update( $log, $dbh, 'Projects', ['Index=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'In Prepress' );
				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'Ordered' );
			} # end foreach
			if ( $variable{'AmountPaid'} >= $variable{'TOTAL'} ) {
				$Order->status('Paid') if $Order->status() eq 'Complete';
			} # end if
			$Order->save();
		} # end if
		#openprint::order::send_invoice( $r, $log, $dbh, $order_id );
    } elsif ( $param{'btnFunction'} eq 'Cancel' ) {
       openprint::order::cancel_order( $log, $dbh, $order_id );
	} # end if

	openprint::order::get_invoice_to( $log, $dbh, \%variable, $order_id );
	openprint::order::get_ship_to( $log, $dbh, \%variable, $order_id );
	$variable{'CCITYPROVCOUNTRY'} = misc::build_city_prov_country(@variable{'txtCity','txtStateProvince','txtCountry'} );
	$variable{'FCITYPROVCOUNTRY'} = misc::build_city_prov_country(@variable{'txtShippingCity','txtShippingStateProvince','txtShippingCountry'} );
	openprint::order::get_misc( $log, $dbh, \%variable, $order_id );
	openprint::order::get_projects( $log, $dbh, \%variable, $order_id );
	$variable{'OrderID'} = $order_id;
	my $Currency = $Order->Currency();
	@variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
} # end sub details

sub credit {
	my ( $r, $log, $dbh, $variable ) = @_;

	my %credit_fields = (
			'txtDenyDays'		=>	'DenyDays',
			'txtWarnDays'		=>	'WarnDays',
			'txtCreditLimit'	=>	'Limit',
			'rdbCreditHold'		=>	'Hold',
			'txtDownpayment'	=>	'Downpayment',
			);

	my $company_index = $param{'ddmCustomer'};

	if ( $param{'btnFunction'} eq 'Go' ) {
		 if ( $param{'txtSearchAccountNum'} ne '' ) {
			( $company_index ) = sql::execute( $log, $dbh,'SELECT Index from Company WHERE strAccountNum=?',$param{'txtSearchAccountNum'} );
		} # end if

	} elsif ( $param{'btnFunction'} eq 'Pay' ) {
		if ( ! $param{'PAID'} ) {
			$variable{'error'} = 'Please select an order to pay.<br/>';
		} else {
			my @errors;
			foreach my $order_id ( ref $param{'PAID'} eq 'ARRAY' ? @{$param{'PAID'}} : $param{'PAID'} ) {
				my $Order = new openprint::Order( $order_id );
				push @errors, $Order->pay();
			} # end foreach
			if ( @errors ) {
				$variable{'error'} = join('<br/>', @errors );
			} # end if
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		my $customer_credit = new openprint::customer_credit( $company_index );
		$customer_credit->set( \%param );
	} # end if

	if ( $company_index ) {
		$_ = "SELECT DISTINCT Orders.Index AS OrderIndex, to_char(dtmOrderDate, 'MM/DD/YYYY'), ".
			"strCompanyName, strPONumber, curTotalSale, ".
			"(SELECT SUM(amount) FROM Payments WHERE (deleted=false OR deleted IS NULL) AND completed=true AND Payments.order_id=Orders.Index), lngDocketNumber, invoice_id ".
			"FROM Orders, order_Contents ".
			"WHERE Orders.Index = Order_Contents.OrderIndex ";
		$_ .= "AND Orders.strStatus NOT IN ('Cancelled','Incomplete','Deleted')";
# which customers
		$_ .= "	AND Orders.CompanyIndex = $company_index";
		$_ .= " AND (
(SELECT SUM(amount) FROM Payments WHERE (deleted=false OR deleted IS NULL) AND completed=true AND Payments.order_id=Orders.Index) < curTotalSale OR	
(SELECT SUM(amount) FROM Payments WHERE (deleted=false OR deleted IS NULL) AND completed=true AND Payments.order_id=Orders.Index) IS NULL ) ";
		$_ .= "ORDER BY OrderIndex";
		@{$variable{'UnpaidOrders'}} = sql::execute( $log, $dbh, $_ );
		for ( my $index = 0; $index < @{$variable{'UnpaidOrders'}}; $index += 8 ) {
		$variable{'UnpaidOrders'}[$index+5] = sprintf( '%.2f', $variable{'UnpaidOrders'}[$index+4] - $variable{'UnpaidOrders'}[$index+5] );
		} # end foreach

		my $customer_credit = new openprint::customer_credit( $company_index );
		@variable{ keys %credit_fields } = ssi::htmlize( $customer_credit->get( @credit_fields{ keys %credit_fields } ) );
		$variable{'CreditBalance'} = sprintf( '$ %.2f', $customer_credit->debt() );
		if ( $variable{'txtCreditLimit'} < $customer_credit->debt() ) {
			$variable{'CreditRemaining'} = '$ 0.00';
		} else {
			$variable{'CreditRemaining'} = sprintf( '$ %.2f', ( $variable{'txtCreditLimit'} - $customer_credit->debt() ) );
		} # end if
		$variable{'CompanyIndex'} = $company_index;
	} # end if customer_index
} # end sub credit

1;

__END__

