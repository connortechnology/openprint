package openprint::employee_accounting;

use Text::CSV_XS;
use strict;

require openprint::Payment;
require openprint::order;
require openprint::Order;
require openprint::Ledger;
require openprint::Expenditure;
require openprint::Expense;
require misc;
require sql;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;

sub search {
	if ( $param{'btnFunction'} eq 'Go' ) {
        if ( $param{'StartDocket'} ) {
            my @orders = openprint::Order->find('docket'=>$param{'StartDocket'},'id'=>$param{'order_id'}, 'invoice_id'=>$param{'invoice_id'} );
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
		new openprint::Payment( $payment_index )->delete();
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
			'payor_id'		=> $Order->company_id(),
			'recipient_id'	=>	new openprint::User( $session{'user_id'} )->company_id(),
			'amount'		=> $param{'Amount'},
			'method'		=> 'Manual',
			'currency_id'	=> $Order->currency_id(),
			'memo'			=> $param{'Description'},
			'completed'		=> 1,
		} );
		if ( $error ) {
			return misc::error( $log, $dbh, \%variable, 'Error Saving Payment', $error );
		} # end if

		openprint::order::get_misc( \%variable, $Order );

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

	openprint::order::get_invoice_to( \%variable, $Order );
	$variable{'CCITYPROVCOUNTRY'} = misc::build_city_prov_country(@variable{'txtCity','txtStateProvince','txtCountry'} );
	openprint::order::get_misc( \%variable, $Order );
	$variable{'OrderID'} = $order_id;
	my $Currency = $Order->Currency();
	@variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
	$variable{'Order'} = $Order;
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
			( $company_index ) = sql::execute( $log, $dbh,'SELECT id FROM Companies WHERE strAccountNum=?',$param{'txtSearchAccountNum'} );
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

sub ledger {
	ssi::save_params( '/employee/accounting/ledger.html', ( 'occurred_on_start_year','occurred_on_start_month','occurred_on_start_day','occurred_on_end_year','occurred_on_end_month','occurred_on_end_day') );
} # end sub ledger

sub _ledger {
	ssi::save_params( '/employee/accounting/ledger.html', ( 'occurred_on_start_year','occurred_on_start_month','occurred_on_start_day','occurred_on_end_year','occurred_on_end_month','occurred_on_end_day') );
} # end sub _ledger

sub expenditures {
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'owner_id'} = $session{'company_id'} if ! $param{'owner_id'};
		my $Expenditure = new openprint::Expenditure( $param{'expenditure_id'} );
		if ( $variable{'error'} .= $Expenditure->save( \%param ) ) {
			$variable{'Redirect'} = '/employee/accounting/expenditure.html';
			return;	
		} # end if
		delete $param{'expenditure_id'};
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		my $Expenditure = new openprint::Expenditure( $param{'expenditure_id'} );
		if ( $variable{'error'} .= $Expenditure->delete() ) {
			$variable{'Redirect'} = '/employee/accounting/expenditure.html';
			return;	
		} # end if
		delete $param{'expenditure_id'};
	} else {
		ssi::save_params( '/employee/accounting/expenditures.html', ( 'occurred_on_start_year','occurred_on_start_month','occurred_on_start_day','occurred_on_end_year','occurred_on_end_month','occurred_on_end_day') );
	} # end if
ssi::setup_date_select( '/employee/accounting/expenditures.html', 'occurred_on', -31, 365 );

} # end sub expenditures

sub _expenditures {
	ssi::save_params( '/employee/accounting/expenditures.html', ( 'occurred_on_start_year','occurred_on_start_month','occurred_on_start_day','occurred_on_end_year','occurred_on_end_month','occurred_on_end_day') );
} # end sub _expenditures

sub expenditure {
	$variable{'Expenditure'} = new openprint::Expenditure( $param{'expenditure_id'} );
} # end sub expenditure

sub expenses {
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'owner_id'} = $session{'company_id'} if ! $param{'owner_id'};
		$param{'due_on'} = sprintf('%.4d-%.2d-%.2d', @param{'due_on_year','due_on_month','due_on_day'} );
		if ( $param{'recipient_id'} ) {
			delete $param{'recipient'};
		} else {
			delete $param{'recipient_id'};
		} # end if
		if ( $param{'category_id'} ) {
			delete $param{'category'};
		} else {
			delete $param{'category_id'};
		} # end if
		my $Expense = new openprint::Expense( $param{'expense_id'} );
		if ( $variable{'error'} .= $Expense->save( \%param ) ) {
			$variable{'Redirect'} = '/employee/accounting/expense.html';
			return;	
		} # end if
		$variable{'information'} .= 'Expense saved successfully.<br/>';
		delete $param{'expenditure_id'};
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		my $Expenditure = new openprint::Expense( $param{'expense_id'} );
		if ( $variable{'error'} .= $Expenditure->delete() ) {
			$variable{'Redirect'} = '/employee/accounting/expense.html';
			return;	
		} # end if
		delete $param{'expense_id'};
	} else {
		ssi::save_params( '/employee/accounting/expenses.html', ( 'due_on_start_year','due_on_start_month','due_on_start_day','due_on_end_year','due_on_end_month','due_on_end_day') );
		ssi::setup_date_select( '/employee/accounting/expenses.html', 'due_on', -31, 365 );
	} # end if
} # end sub expenses
sub _expenses {
	ssi::save_params( '/employee/accounting/expenses.html', ( 'due_on_start_year','due_on_start_month','due_on_start_day','due_on_end_year','due_on_end_month','due_on_end_day') );
} # end sub _expenses

sub expense {
	my $Expense = $variable{'Expense'} = new openprint::Expense( $param{'expense_id'} );
	
} # end sub expense

sub stock {
	require openprint::ManifestContent;

	if ( $param{'btnFunction'} eq 'Save' ) {
		foreach my $Type ( openprint::Manifest_Content_Type->find('cost'=>undef) ) {
			$param{'cost-'.$Type->id()} =~ s/[^\d\.]//g;
			if ( $param{'units-'.$Type->id()} eq '/lb' ) {
				$param{'cost-'.$Type->id()} *= 100;
			} # end if
			if ( ( $param{'supplier_invoice-'.$Type->id()} ne $Type->supplier_invoice() ) or ( $param{'cost-'.$Type->id()} != $Type->cost() ) ) {
				$variable{'error'} .= $Type->save({'supplier_invoice'=>$param{'supplier_invoice-'.$Type->id()}, 'cost'=>$param{'cost-'.$Type->id()} });
			} # end if
		} # end foreach
	} else {
		@param{'received_on_start_year','received_on_start_month','received_on_start_day'} = Date::Calc::Today();
		@param{'received_on_end_year','received_on_end_month','received_on_end_day'} = Date::Calc::Today();
	} # end if
} # end sub stock

sub credit_applications {

	if ( $param{'btnFunction'} eq 'Save' ) {
		my %credit_fields = (
				'txtTerms'			=>	'Terms',
				'CreditLimit'		=>	'CreditLimit',
				'txtDownpayment'	=>	'Downpayment',
				);
		my $credit_app = $param{'credit_index'};

		if ( $credit_app ) {
			sql::update( $log, $dbh, 'CreditApplications', ['Id = ?',$credit_app],
					'strStatus',			$param{'verdict'},
					'lngGrantedTerms',			$param{'txtTerms'},
					'dblGrantedCreditLimit',	$param{'CreditLimit'},
					'dblGrantedDownpayment',	$param{'txtDownpayment'},
					);
			$_ = "SELECT company_id, user_id, strSignature, ysnFinancialStatementAvailable,strFirstOrderValue,strAnnualPurchases, dblCreditLimit, strAccountsPayableContact, to_char(dtmCreationDate,'Day Month DD, YYYY HH24:MI') FROM CreditApplications ".
				"WHERE id=?";

			@variable{
				'hiddenCustomerID',
					'UserIndex',
					'Signature',
					'FinancialStatementAvailable',
					'FirstOrderValue',
					'AnnualPurchases',
					'AccountLimitDesired',
					'AccountsPayableContact',
					'SubmissionDate',
			} = sql::execute( $log, $dbh, $_, $credit_app );

			if ( ! sql::execute( $log, $dbh, 'SELECT index FROM company WHERE index=?', $variable{'hiddenCustomerID'} ) ) {
				return misc::error( $log, $dbh, \%variable, 'Deleted Customer', "The company that created this credit app has been deleted from the system.  This credit app has been deleted." );
			} # end if

			my $customer_credit = new openprint::customer_credit( $variable{'hiddenCustomerID'}, $session{'company_id'} );
			my %params;

			foreach my $field ( keys %credit_fields ) {
				$params{$credit_fields{$field}} = $param{$field} if defined $param{$field};
			} # end foreach
			$params{'txtSignature'} = $variable{'Signature'};
			$customer_credit->set( \%params );
			$params{'siteURL'} = $config{'siteURL'};
			$params{'SecureSiteURL'} = $config{'SecureSiteURL'};

			my $Me = new openprint::User( $variable{'UserIndex'} );

			$params{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/credit_change_notification.html' );
			$params{'ReplacementText'} = ssi::variable_substitution( \$params{'ReplacementText'}, \%params );
			$_ = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
			my $template = ssi::variable_substitution( \$_, \%params );
			my %mail = (
					SMTP	=> $config{'Mail Server'},
					FROM	=> $config{'AdministratorEmail'},
					TO		=> $Me->email(),
					SUBJECT => 'Credit Status Changed.'
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($template), 'text/html', 'quoted-printable' ) );
		} # end if
	} # end if
	ssi::setup_date_select( '/employee/accounting/credit_applications.html', 'created_on', -180, 0 );
	ssi::save_params( '/employee/accounting/credit_applications.html',
			'ddmStatus',
			'created_on_start_year', 'created_on_start_month','created_on_start_day',
			'created_on_end_year', 'created_on_end_month','created_on_end_day',
			);

} # end sub credit_applications

sub credit_application {

	my %credit_fields = (
			'txtTerms'			=>	'Terms',
			'CreditLimit'		=>	'CreditLimit',
			'txtDownpayment'	=>	'Downpayment',
			);

	my $credit_app = $param{'credit_index'};
	$variable{'credit_index'} = $credit_app;

	if ( $credit_app ) {
		$_ = "SELECT company_Id, User_Id, strSignature, ysnFinancialStatementAvailable,strFirstOrderValue,\n".
			"strAnnualPurchases, dblCreditLimit, lngTerms, strAccountsPayableContact,\n".
			"to_char(dtmCreationDate,'Day Month DD, YYYY HH24:MI'), strStatus, lngGrantedTerms, dblGrantedCreditLimit, dblGrantedDownpayment\n".
			"FROM CreditApplications ".
			"WHERE Id=?";

		@variable{
			'hiddenCustomerID',
				'UserIndex',
				'Signature',
				'FinancialStatementAvailable',
				'FirstOrderValue',
				'AnnualPurchases',
				'AccountLimitDesired',
				'AccountTermsDesired',
				'AccountsPayableContact',
				'SubmissionDate',
				'verdict',
				'GrantedTerms',
				'GrantedCreditLimit',
				'GrantedDownpayment',
		} = sql::execute( $log, $dbh, $_, $credit_app );

		$variable{'FinancialStatementAvailable'} = $variable{'FinancialStatementAvailable'} eq 'Y' ? 'Yes' : 'No';
		$variable{'verdict'.$variable{'verdict'}} = 'CHECKED';

		my $customer_credit = new openprint::customer_credit( $variable{'hiddenCustomerID'}, $session{'company_id'} );

		my $Company = $variable{'Company'} = new openprint::Company( $variable{'hiddenCustomerID'} );
		my $User = $variable{'User'} = new openprint::User( $variable{'UserIndex'} );

		@variable{ keys %credit_fields } = ssi::htmlize( $customer_credit->get( @credit_fields{ keys %credit_fields } ) );
		$variable{'rdbTerms'.$variable{'rdbTerms'}} = 'CHECKED';

	} # end if
} # end sub admin_credit_app

1;
__END__
