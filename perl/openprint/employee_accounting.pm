use strict;
package openprint::employee_accounting;

require openprint::Credit_Application;
require MIME::QuotedPrint;
require openprint::Company_Credit;
require openprint::order;
require openprint::Order;
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

	_search();
	ssi::setup_date_select( '/employee/accounting/search.html', 'ordered_on_start', '' );
	ssi::setup_date_select( '/employee/accounting/search.html', 'ordered_on_end', '' );
	if ( ! $session{'/employee/accounting/search.html?ddmStatus'} ) {
		$session{'/employee/accounting/search.html?ddmStatus'} = [ 'Complete','In Production',' Order Submitted', 'Pending Deposit', 'Paid', 'Picked Up','Re-Opened', 'Shipped', 'Waiting For Customer Approval', 'Waiting For Pickup' ];
	} # end if
} # end sub search

sub _search {
	ssi::save_params( '/employee/accounting/search.html',
			'ddmCustomer','ddmStatus','ddmEmployee','dblTotal1','dblTotal2',
			( map { 'ordered_on_start_'.$_ } ( 'year', 'month','day' ) ),
			( map { 'ordered_on_end_'.$_ } ( 'year', 'month','day' ) ),
			);
} # end sub _search

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

		my $error = sql::insert( $log, $dbh, 'Payments',
			'Order_Id',		$order_id,
			'Company_Id',	$Order->company_id(),
			'curAmount',	$param{'Amount'},
			'dtmDate',		'NOW()',
			'strMethod',	'Manual',
			'currency_id',	$Order->currency_id(),
			'strDescription',	$param{'Description'},
		);
		if ( $error ) {
			return misc::error( $log, $dbh, \%variable, 'Error Saving Payment', $error );
		} # end if

		openprint::order::get_misc( $log, $dbh, \%variable, $order_id );

		if ( $variable{'DepositDue'} > 0 ) {
			foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
				sql::update( $log, $dbh, 'tbl_Projects', ['Index=? AND strStatus=?', $project_index, 'In Prepress'], 'strStatus', 'Pending Deposit' );
				sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND strStatus='Ordered'", 'strStatus', 'Pending Deposit' );
			} # end foreach
		} else {
			$Order->status('In Production') if $Order->status() eq 'Pending Deposit';

			foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
				sql::update( $log, $dbh, 'tbl_Projects', ['Index=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'In Prepress' );
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

	$_ = q{SELECT id, to_char(dtmDate,'MM/DD/YYYY'), strMethod, strDescription, curAmount, currency_id FROM Payments WHERE strSessionID IS NULL AND Order_Id=? ORDER BY dtmDate};
	@{$variable{'PAYMENTS'}} = sql::execute( $log, $dbh, $_, $order_id );
	$variable{'Order'} = $Order;
} # end sub details

sub credit {

	my $company_id = $param{'ddmCustomer'};

	if ( $param{'btnFunction'} eq 'Go' ) {
		 if ( $param{'txtSearchAccountNum'} ne '' ) {
			( $company_id ) = sql::execute( $log, $dbh,'SELECT Index from Company WHERE strAccountNum=?',$param{'txtSearchAccountNum'} );
		} # end if

	} elsif ( $param{'btnFunction'} eq 'Pay' ) {
		if ( ! $param{'PAID'} ) {
			$variable{'error'} = 'Please select an order to pay.<br/>';
		} else {
			my @errors;
			foreach my $order_id ( ref $param{'PAID'} eq 'ARRAY' ? @{$param{'PAID'}} : $param{'PAID'} ) {
				my $Order = new openprint::Order( $order_id );
				if ( $Order->company_id() != $company_id ) {
					push @errors, 'Order ' . $Order->id() . ' does not belong to ' . new openprint::Company($company_id)->name().'.';
					next;
				} # end if
				push @errors, $Order->pay();
			} # end foreach
			if ( @errors ) {
				$variable{'error'} = join('<br/>', @errors );
			} # end if
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		foreach my $Supplier ( openprint::Company->find('offers_credit'=>1) ) {
			my $Credit = new openprint::Company_Credit( {'company_id'=>$company_id, 'supplier_id'=>$Supplier->id() } );

			$variable{'error'} .= $Credit->save( { 'company_id'=>$company_id, 'supplier_id'=>$Supplier->id(), 
				map { $_ => $param{$_.'-'.$Supplier->id()} } ( 'denydays','warndays','limit','hold','downpayment','cod' ) } );
		} # end foreach Supplier
	} elsif ( $param{'btnFunction'} eq 'Export' ) {
		my @header = ( 'Creditor', 'Company Internal Name','Legal Name', 'Warn After Days', 'Deny After Days', 'Limit', 'Balance', 'Remaining', 'Hold', 'Downpayment', 'COD' );
		my @data;
		foreach my $Credit ( openprint::Company_Credit->find() ) {
			push @data, $Credit->Supplier()->name(), $Credit->Company()->name(), $Credit->Company()->business_name(),
			$Credit->warndays(), $Credit->denydays(), $Credit->limit(), $Credit->debt(), $Credit->remaining(), $Credit->hold(), $Credit->downpayment(), $Credit->cod();
		} # ebd foreach Credut
		misc::export_csv( $r, $log, \%variable, 'Credit.csv', \@header, \@data );
	} # end if

	$variable{'CompanyIndex'} = $company_id;
	$variable{'Company'} = new openprint::Company($company_id);
} # end sub credit

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
		_stock();
		ssi::setup_date_select( '/employee/accounting/stock.html', 'received_on_start', -30 );
		ssi::setup_date_select( '/employee/accounting/stock.html', 'received_on_end', 0 );
	} # end if
} # end sub stock

sub _stock {
	ssi::save_params( '/employee/accounting/stock.html',
			( map { 'received_on_start_'.$_ } ( 'year', 'month','day' ) ),
			( map { 'received_on_end_'.$_ } ( 'year', 'month','day' ) ),
			);
} # end sub _stock

sub credit_applications {

	ssi::setup_date_select( '/employee/accounting/credit_applications.html', 'created_on_start', -180 );
	ssi::setup_date_select( '/employee/accounting/credit_applications.html', 'created_on_end', 0 );
	ssi::save_params( '/employee/accounting/credit_applications.html',
			'ddmStatus',
			'created_on_start_year', 'created_on_start_month','created_on_start_day',
			'created_on_end_year', 'created_on_end_month','created_on_end_day',
		);

} # end sub credit_applications

sub credit_application {

	my $Application = $variable{'Application'} = new openprint::Credit_Application( $param{'credit_index'} );
	if ( ! $Application->id() ) {
		$variable{'error'} .=  'Application does not exist.';
		return;
	} # end if

	my $Company = $variable{'Company'} = $Application->Company();
	if ( ! $Company->id() ) {
		$variable{'error'} .= 'The company that created this credit app has been deleted from the system.  This credit app has been deleted.';
	} # end if

	my $User = $variable{'User'} = $Application->User();
	my $Credit = $variable{'Credit'} = $Company->Credit();

	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $Application->save({
				'status'				=>	$param{'status'},
				'granted_terms'			=>	$param{'denydays'},
				'granted_limit'			=>	$param{'limit'},
				'granted_downpayment'	=>	$param{'downpayment'},
				'granted_cod'			=>	$param{'cod'},
				});
		
		$variable{'error'} .= $Credit->save( \%param );
		if ( ! $variable{'error'} ) {

			$variable{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/credit_change_notification.html' );
			$variable{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$variable{'ReplacementText'}, \%variable );
			$_ = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
			my $template = ssi::variable_substitution( $r, $log, $dbh, \$_, \%variable );
			$variable{'error'} .= ( new openprint::Email())->send(
					FROM	=> $config{'AdministratorEmail'},
					TO		=> $Application->User()->email(),
					SUBJECT => 'Credit Status Changed.',
					ATTACHMENTS	=> [ '', MIME::QuotedPrint::encode_qp($template), 'text/html', 'quoted-printable' ],
				);
		} # end if
		$variable{'ExternalRedirect'} = '/employee/accounting/credit_applications.html' if ! $variable{'error'};
	} # end if

} # end sub credit_application

1;
__END__
