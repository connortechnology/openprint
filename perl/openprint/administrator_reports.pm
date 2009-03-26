package openprint::administrator_reports;

use strict;

require openprint::ServiceCategory;
require openprint::order;
require misc;
require sql;
require ssi;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub projects {

	ssi::get_start_end_dates( $log, $dbh, \%variable, @param{'ddmStartYear','ddmStartMonth','ddmStartDay','ddmEndYear','ddmEndMonth','ddmEndDay'} );

	my %filters = (
		'order'=>'index',
			);
	$filters{'company_id'}	= $param{'ddmCustomers'} if $param{'ddmCustomers'};
	$filters{'user_id'}	= $param{'ddmEstimator'} if $param{'ddmEstimator'};
	$filters{'status'}	= $param{'ddmStatus'} if $param{'ddmStatus'};
	$filters{'csr_id'}	= $param{'ddmEmployees'} if $param{'ddmEmployees'};
	$filters{'created_on_start'} = sprintf('%.4d-%.2d-%.2d 00:00:00' , @param{'ddmStartYear','ddmStartMonth','ddmStartDay'} );
	$filters{'created_on_end'} = sprintf('%.4d-%.2d-%.2d 23:59:59' , @param{'ddmEndYear','ddmEndMonth','ddmEndDay'} );

	@{$variable{'Projects'}} = openprint::Project::find( %filters );

	if ( $param{'btnFunction'} eq 'Download in CSV format' ) {
		my @header = ('Project #', 'Docket #', 'Company', 'Reference', 'Summary', 'Creation Date', 'Status', 'Price 1', 'Price 2', 'Price 2', 'Currency');
		my @data;
		my ( $total1, $total2, $total3 );
		foreach my $Project ( @{$variable{'Projects'}} ) {
			push @data, $Project->id(), $Project->docket(), $Project->Company()->name(), $Project->reference(), $Project->summary(), 
				Date::Format::time2str( $config{'DateTimeFormat'}, Date::Parse::str2time( $Project->created_on() ) ), $Project->status(),
				$Project->price1(), $Project->price2(), $Project->price3(), $Project->Currency()->name();
			$total1 += $Project->total1();
			$total2 += $Project->total2();
			$total3 += $Project->total3();
		} # end foreach Project
		push @data, '','','','','','','Totals:',$total1,$total2,$total3,'';
		misc::export_csv( $r, $log, \%variable, 'project_report.csv', \@header, \@data );
	} # end if

} # end sub project_report

sub quotes {

	ssi::get_start_end_dates( $log, $dbh, \%variable,
			@param{'ddmStartYear','ddmStartMonth','ddmStartDay','ddmEndYear','ddmEndMonth','ddmEndDay'} );

	$variable{'ddmStatus'.$r->param('ddmStatus')} = 'SELECTED';

	my %filters = (
			'order'=>'index',
			);
	$filters{'status'} = $param{'ddmStatus'} if $param{'ddmStatus'};
	$filters{'company_id'} = $param{'ddmCustomers'} if $param{'ddmCustomers'};
	$filters{'salesrep_id'} = $param{'salesrep_id'} if $param{'salesrep_id'};
	$filters{'currency_id'} = $param{'currency_id'} if $param{'currency_id'};
	$filters{'total_start'} = $param{'total_start'} if $param{'total_start'};
	$filters{'total_end'} = $param{'total_end'} if $param{'total_end'};
	$filters{'created_on_start'} = sprintf('%.4d-%.2d-%.2d 00:00:00' , @param{'ddmStartYear','ddmStartMonth','ddmStartDay'} );
	$filters{'created_on_end'} = sprintf('%.4d-%.2d-%.2d 23:59:59' , @param{'ddmEndYear','ddmEndMonth','ddmEndDay'} );

	@{$variable{'Quotes'}} = openprint::Quote::find( %filters );

	if ( $param{'btnFunction'} eq 'Download in CSV format' ) {
		my @header = ( 'Quote ID', 'Created On', 'Prepared By', 'Company', 'Prepared For','Status', 'Total1', 'Total2', 'Total3', 'Currency' );
		my @data;
		my $total1;
		my $total2;
		my $total3;
		foreach my $Quote ( @{$variable{'Quotes'}} ) {
			push @data, $Quote->id(), Date::Format::time2str($config{'DateTimeFormat'}, Date::Parse::str2time( $Quote->created_on() ) ), $Quote->by_name(), $Quote->Company()->name(), $Quote->for_name(), $Quote->status(), $Quote->total1(), $Quote->total2(), $Quote->total3(), $Quote->Currency()->name();
			$total1 += $Quote->total1();
			$total2 += $Quote->total2();
			$total3 += $Quote->total3();
		} # end foreach
		push @data, '','','','','','Totals:', $total1, $total2, $total3, '';
		misc::export_csv( $r, $log, \%variable, 'quote_report.csv', \@header, \@data );
	} # end if

} # end sub quotes

sub orders {
	if ( $param{'btnFunction'} eq 'Download in CSV format' ) {
		my @header = ('OrderID', 'Docket', 'Order Date', 'Company Name', 'Status', 'Total', 'Currency');

		my @Orders = openprint::Order::find(
				'company_id'		=> $param{'ddmCustomer'},
				'created_on_start'  => sprintf('%.4d-%.2d-%.2d 00:00:00', @session{$r->uri().'?StartYear',$r->uri().'?StartMonth',$r->uri().'?StartDay'} ),
				'created_on_end'	=> sprintf('%.4d-%.2d-%.2d 23:59:59', @session{$r->uri().'?EndYear',$r->uri().'?EndMonth',$r->uri().'?EndDay'} ),
				'value_start'	   => $param{'TotalStart'},
				'value_end'		 => $param{'TotalEnd'},
				'salesrep_id'	   => $param{'ddmEmployee'},
				'status'			=> $param{'ddmStatus'},
				'currency_id'	   => $param{'ddmCurrency'},
				);
		my @data;
		my $total = 0;
		foreach my $Order ( @Orders ) {
			push @data, $Order->id(), $Order->docket(), Date::Format::time2str($config{'DateTimeFormat'}, Date::Parse::str2time($Order->created_on())), $Order->Company()->name(), $Order->status(), $Order->total(), $Order->Currency()->name();
			next if $Order->status() eq 'Cancelled';
			$total += $Order->total();
		} # end foreach Order
		push @data, '', '', '', '', 'Total:', $total, '';

		misc::export_csv( $r, $log, \%variable, 'order_report.csv', \@header, \@data );
	} # end if
} # end sub orders

sub custom {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $id = $r->param( 'ddmStoredReport' );

	if ( $r->param('btnFunction') eq 'Save' ) {
		my @sql = (
				'strReportName', $r->param('strReportName'),
				'strSQLCommand', $r->param('strSQLCommand'),
				);
		if ( $id ) { # save
			sql::update( $log, $dbh, 'tbl_Reports', ['lngIndex=?', $id], @sql );
		} else { # add
			sql::insert( $log, $dbh, 'tbl_Reports', @sql );
 			$_ = 'SELECT lngIndex FROM tbl_Reports WHERE strReportName=?';
			( $id ) = sql::execute( $log, $dbh, $_, $r->param('strReportName') );
		} # end if
	} elsif ( $r->param('btnFunction') eq 'Delete' ) {
		# perform the record deletion
		sql::execute( $log, $dbh, 'DELETE FROM tbl_Reports WHERE lngIndex=?', $id);
		$id = undef;
	} elsif ( $r->param('btnFunction') eq 'Show Results' ) {
		$_ = 'SELECT strReportName, strSQLCommand FROM tbl_Reports WHERE lngIndex=?';
		my ( $name, $command ) = sql::execute( $log, $dbh, $_, $id );

		my ( $num_columns, @data ) = sql::run_query( $log, $dbh, $command );
		if ( ! @data ) {
			$$variable{'RESULTS'} = $dbh->errstr;
		} else {
			$$variable{'RESULTS'} = "<table>";
			while( my @line = splice( @data, 0, $num_columns ) ) {
				for ( my $i = 0; $i < @line; $i += 1 ) {
					$line[$i] =~ s/,//g;
				} # end for
				$$variable{'RESULTS'} .= "<tr><td>" . join( "</td><td>", @line )."</td></tr>\n";
			} # end for 
			$$variable{'RESULTS'} .= "</table>\n";
		} # end if

	} elsif ( $r->param('btnFunction') eq 'Download in CSV format' ) {
		$_ = 'SELECT strReportName, strSQLCommand FROM tbl_Reports WHERE lngIndex=?';
		my ( $name, $command ) = sql::execute( $log, $dbh, $_, $id );

		my ( $num_columns, @data ) = sql::run_query( $log, $dbh, $command );

		my @header = splice @data, 0, $num_columns;
		misc::export_csv( $r, $log, $variable, $name.'.csv', \@header, \@data );
	} # end if

	if ( $id ne '' ) {
		# get report to display
		$_ = "SELECT strReportName, strSQLCommand FROM tbl_Reports WHERE lngIndex = '$id'";
		@$variable{'strReportName', 'strSQLCommand'} = sql::execute( $log, $dbh, $_ );
	} # end if

	$_ = "SELECT lngIndex, strReportName FROM tbl_Reports";
	$$variable{'ddmStoredReport'} = ssi::fill_drop_down( $log, $dbh, $_, $id );

} # end sub custom

sub customer_login {

	ssi::get_start_end_dates( $log, $dbh, $variable, @param{'ddmStartYear','ddmStartMonth','ddmStartDay','ddmEndYear','ddmEndMonth','ddmEndDay'} );

	@variable{'LastProjectStartYears','LastProjectStartMonths','LastProjectStartDays','LastProjectStart'} = ssi::get_dates( $log, $dbh,
			@param{'ddmLastProjectStartYear','ddmLastProjectStartMonth','ddmLastProjectStartDay'} );
	@variable{'LastProjectEndYears','LastProjectEndMonths','LastProjectEndDays','LastProjectEnd'} = ssi::get_dates( $log, $dbh,
			@param{'ddmLastProjectEndYear','ddmLastProjectEndMonth','ddmLastProjectEndDay'} );

	@variable{'LastOrderStartYears','LastOrderStartMonths','LastOrderStartDays','LastOrderStart'} = ssi::get_dates( $log, $dbh,
			@param{'ddmLastOrderStartYear','ddmLastOrderStartMonth','ddmLastOrderStartDay'} );
	@variable{'LastOrderEndYears','LastOrderEndMonths','LastOrderEndDays','LastOrderEnd'} = ssi::get_dates( $log, $dbh,
			@param{'ddmLastOrderEndYear','ddmLastOrderEndMonth','ddmLastOrderEndDay'} );

	my $query = 'SELECT Company.Index, (SELECT MIN(Index) FROM Users WHERE Users.CompanyIndex = Company.Index ), Company.lngSalesPerson, ';
	$query .= '(SELECT COUNT(Index) FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ), ';
	$query .= '(SELECT MAX(Index) as lastproject FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ), ';
	$query .= '(SELECT COUNT(Index) FROM Orders WHERE Orders.CompanyIndex = Company.Index ), ';
	$query .= '(SELECT MAX(index) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index ), ';
	$query .= '(SELECT SUM(curtotalsale) FROM Orders WHERE Orders.CompanyIndex = Company.Index ) ';
	$query .=  'FROM Company ';
	$query .=  "WHERE (Company.dtmdateentered BETWEEN '$variable{'StartDate'} 00:00:00' AND '$variable{'EndDate'} 23:59:59') AND Company.deleted != true ";
	if ( $param{'ddmEmployees'} ) {
		if ( $param{'ddmEmployees'} eq 'None' ) {
			$query .= " AND lngsalesperson IS NULL OR lngSalesPerson NOT IN ( SELECT Index FROM Users WHERE chrType='E' AND strEmployeeType='Sales')";
		} else {
			$query .= " AND lngsalesperson=" . $param{'ddmEmployees'};
		} # end if
	} # end if
	if ( $param{'ddmLastProjectStartYear'} and $param{'ddmLastProjectStartMonth'} and $param{'ddmLastProjectStartDay'} ) {
		if ( $param{'ddmLastProjectEndYear'} and $param{'ddmLastProjectEndMonth'} and $param{'ddmLastProjectEndDay'} ) {
			$query .= " AND (SELECT date(MAX(dtmCreationDate)) as lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ) BETWEEN date('$variable{'LastProjectStart'}') AND date('$variable{'LastProjectEnd'}')";
		} else {
			$query .= " AND (SELECT date(MAX(dtmCreationDate)) as lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ) > date('$variable{'LastProjectStart'}')";
		} # end if
	} elsif ( $param{'ddmLastProjectEndYear'} and $param{'ddmLastProjectEndMonth'} and $param{'ddmLastProjectEndDay'} ) {
		$query .= " AND (SELECT date(MAX(dtmCreationDate)) AS lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ) < date('$variable{'LastProjectEnd'}')";
	} # end if

	if ( $param{'ddmLastOrderStartYear'} and $param{'ddmLastOrderStartMonth'} and $param{'ddmLastOrderStartDay'} ) {
		if ( $param{'ddmLastOrderEndYear'} and $param{'ddmLastOrderEndMonth'} and $param{'ddmLastOrderEndDay'} ) {
			$query .= " AND (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index ) BETWEEN date('$variable{'LastOrderStart'}') AND date('$variable{'LastOrderEnd'}')";
		} else {
			$query .= " AND (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index )  > date('$variable{'LastOrderStart'}')";
		} # end if
	} elsif ( $param{'ddmLastOrderEndYear'} and $param{'ddmLastOrderEndMonth'} and $param{'ddmLastOrderEndDay'} ) {
		$query .= " AND (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index )  < date('$variable{'LastOrderEnd'}')";
	} # end if
	if ( $param{'rdbActive'} ) {
		$query .= " AND Company.ysnAccountActivation = '$param{'rdbActive'}'\n";
	} # end if
	@{$$variable{'DATA'}} = sql::execute( $log, $dbh, $query );

	if ( $param{'btnFunction'} eq 'Download in CSV format' ) {
		my @header = ( 'Company Name','Contact Name', 'Phone #', 'Email','City','State','Registration Date','Account Rep','# of Projects','Last Project','# of Orders','Last Order', 'Last Order Value');
		my @data;
		while ( my ( $company_id, $user_id, $csr_id, $projects, $last_project, $orders, $last_order, $total ) = splice @{$$variable{'DATA'}}, 0, 8 ) {
			my $Company = new openprint::Company( $company_id );
			my $User = new openprint::User( $user_id );
			my $CSR = new openprint::User( $csr_id );
			my $Project = new openprint::Project( $last_project );
			my $Order = new openprint::Order( $last_order );
			push @data, $Company->name(), $User->name(), $Company->phone(), $User->email(), $Company->city(), $Company->state(),
				Date::Format::time2str($config{'DateFormat'}, Date::Parse::str2time( $Company->created_on() ) ),
				$CSR->name(), $projects, 
				$projects ? Date::Format::time2str($config{'DateFormat'}, Date::Parse::str2time( $Project->created_on() ) ) : '',
				$orders, 
				$orders ? Date::Format::time2str($config{'DateFormat'}, Date::Parse::str2time( $Order->created_on() ) ) : '',
				$total;
		} # end while
		misc::export_csv( $r, $log, $variable, 'customer_report.csv', \@header, \@data );
	} # end if	

} # end sub customer_login

sub CustomerServiceReps {
	my ( $r, $log, $dbh, $variable ) = @_;

	ssi::get_start_end_dates( $log, $dbh, $variable,
			$r->param('ddmStartYear'),
			$r->param('ddmStartMonth'),
			$r->param('ddmStartDay'),
			$r->param('ddmEndYear'),
			$r->param('ddmEndMonth'),
			$r->param('ddmEndDay') );


	@{$$variable{'Employees'}} = map { $_->id(), $_->name() } openprint::User::find('type'=>['E','A'],'order'=>'lower(strfirstname),lower(strlastname)', 'usergroup'=>'Sales', 'id'=>$r->param('ddmEmployees'), 'web_active'=>1 );
	$$variable{'ddmEmployees'} = ssi::make_drop_down( $$variable{'Employees'}, $r->param('ddmEmployees') );

	my $estimator = $r->param('ddmEstimator');
	$$variable{'ddmEstimatorOptions'} = ssi::make_drop_down( $$variable{'Employees'}, $r->param('ddmEstimator') );

	@{$$variable{'Currencies'}} = sql::execute( $log, $dbh, "SELECT id, Name, Symbol FROM Currencies ORDER BY lower(name)" );

	my %ordered_projects;

	my $query = "SELECT Index, strStatus, (SELECT salesrep_id FROM Companies WHERE id=Projects.CompanyIndex),
	   ";
	$query .= "(SELECT curSalesPrice FROM Order_Contents, Orders WHERE Orders.Index=Order_Contents.OrderIndex AND Order_Contents.lngProjectIndex=Projects.Index AND Orders.lngDocketNumber=Projects.lngDocketNumber),";
	$query .= "(SELECT currency_id FROM Orders WHERE Orders.lngDocketNumber=Projects.lngDocketNumber)";

	$query .= " FROM Projects ";
	$query .= "WHERE dtmcreationdate BETWEEN '$$variable{'StartDate'} 00:00:00' AND '$$variable{'EndDate'} 23:59:59' ";
	$query .= "AND UserIndex = $estimator\n" if $estimator;
	my @data = sql::execute( $log, $dbh, $query );
	while ( my ( $project_index, $status, $employee, $price, $currency_index ) = splice @data,0,5 ) {
		$$variable{'TotalProjectCount'.$employee} += 1;
		$$variable{'TotalProjectCount'} += 1;
		if ( $status eq 'Deleted' ) {
			$$variable{'DeletedProjectCount'.$employee} += 1;
			$$variable{'DeletedProjectCount'} += 1;
		} elsif ( $status eq 'uncalculated' ) {
			$$variable{'UnfinishedProjectCount'.$employee} += 1;
			$$variable{'UnfinishedProjectCount'} += 1;
		} elsif ( $status eq 'Unordered' ) {
			$$variable{'UnorderedProjectCount'.$employee} += 1;
			$$variable{'UnorderedProjectCount'} += 1;
		} else { # ordered
			$$variable{'OrderedProjectCount'.$employee} += 1;
			$$variable{'OrderedProjectCount'} += 1;
			$$variable{"OrderValue-$employee-$currency_index"} += $price;
			$$variable{"OrderValue-$currency_index"} += $price;
		} # end if
	} # end while

} # end sub customer_service_reps

sub order_details {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $order_id = $openprint::param{'order_id'};
	my $Order = new openprint::Order( $order_id );

	if ( $r->param('btnFunction') eq 'Delete' ) {
		if ( openprint::Payment::find('order_id'=>$order_id ) ) {
			$$variable{'error'} .= "Order $order_id appears to have payments.  Please delete the payments before deleting the order.";
		} else {
		$Order->delete();
		$$variable{'Redirect'} = '/administrator/reports/orders.html';
		return;
		} # en dif
	} elsif ( $r->param('btnFunction') eq 'Resend' ) {
		sql::update( $log, $dbh, 'Orders',['Index=?', $order_id], 'strComments',$r->param('txtComments') );
		openprint::order::order_send_email( $r, $log, $dbh, $order_id );
	} elsif ( $openprint::param{'btnFunction'} eq 'Pay' ) {
		$Order->pay();
	} elsif ( $openprint::param{'btnFunction'} eq 'Save Payment' ) {

		if ( ( ! $openprint::param{'Amount'} ) or $openprint::param{'Amount'} =~ /[^-\$\d\.]/ ) {
			return misc::error( $log, $dbh, $variable, 'Invalid Amount', 'Please enter a valid monetary amount.' );
		} # end if

		my $Payment = new openprint::Payment();
		
		my $error = $Payment->save({
				'order_id'		=>	$order_id,
				'recipient_id'	=>	new openprint::User( $openprint::session{'user_id'} )->company_id(), 
				'payor_id'		=>	$Order->company_id(),
				'amount'		=>	$openprint::param{'Amount'},
				'method'		=>	'Manual',
				'currency_id'	=>	$Order->currency_id(),
				'memo'			=>	$openprint::param{'Description'},
				} );
		if ( $error ) {
			return misc::error( $log, $dbh, $variable, 'Error Saving Payment', $error );
		} # end if

		openprint::order::get_misc( $log, $dbh, $variable, $order_id );

		if ( $$variable{'DepositDue'} > 0 ) {
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
			if ( $$variable{'AmountPaid'} >= $$variable{'TOTAL'} ) {
				$Order->status('Paid') if $Order->status() eq 'Complete';
			} # end if
			$Order->save();
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete Payment' ) {
		$openprint::param{'payment_id'} =~ s/\D//g;
		if ( $openprint::param{'payment_id'} ) {
			my $Payment = new openprint::Payment( $openprint::param{'payment_id'} );
			$Payment->delete();
		} # end if
		$Order->update_status();
	} elsif ( $openprint::param{'btnFunction'} eq 'Invoice' ) {
		$Order->invoice_id( $openprint::param{'invoice_id'} );
		$Order->invoiced_on( 'NOW()' );
		$Order->save();
	} elsif ( $openprint::param{'btnFunction'} eq 'Cancel' ) {
		openprint::order::cancel_order( $log, $dbh, $order_id );
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		$Order->company_id( $openprint::param{'company_id'} );
		$$variable{'error'} .= $Order->save();
	} # end if
	$$variable{'Order'} = $Order;
	openprint::order::display_order( $log, $dbh, $variable, $order_id );
} # end sub display_order

sub uploads {
	require openprint::Upload;
} # end sub uploads

1;

__END__

