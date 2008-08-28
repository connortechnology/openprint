package openprint::administrator_reports;

use strict;

require openprint::ServiceCategory;
require openprint::order;
require misc;
require sql;
require ssi;
use Text::Unaccent;

sub projects {
	my ($r, $log, $dbh, $variable) = @_;

    my $start;
    my $startYear = $r->param('ddmStartYear');
    my $startMonth;
    my $startDay;
    ( $start ) = $openprint::config{'startYear'};
    $start = 2003 if ! $start;
    if ( ! $startYear ) {
       $startYear = (localtime(time))[5]+1900;
    } # end if
    $startMonth = $r->param('ddmStartMonth') ? $r->param('ddmStartMonth') : (localtime(time))[4]+1;
    $startDay = $r->param('ddmStartDay') ? $r->param('ddmStartDay') : (localtime(time))[3];

    ssi::get_start_end_dates( $log, $dbh, $variable,
            $startYear,
            $startMonth,
            $startDay,
            $r->param('ddmEndYear'),
            $r->param('ddmEndMonth'),
            $r->param('ddmEndDay') );

    $_ = "SELECT DISTINCT strStatus, strStatus FROM tbl_Projects ORDER BY strStatus";
    $$variable{'ddmStatus'} = ssi::fill_drop_down( $log, $dbh, $_, $r->param('ddmStatus') );

	$$variable{'ddmEquipment'} = ssi::make_drop_down( [ map { $_->id(), $_->name() } openprint::Equipment::find('order'=>'lower(strName)') ], $r->param('ddmEquipment') );

	if ( $r->param('btnFunction') eq 'Download in CSV format' ) {
		my @header = ('Docket #', 'Project Reference','Company Name', 'Creation Date','Status');
		$_ = "SELECT lngProjectIndex, SUBSTR(strProjectReference,0,50),\n".
				"(SELECT Name FROM Companies WHERE id = tbl_Projects.CompanyIndex),\n".
				"to_char(dtmCreationDate, 'MM/DD/YYYY'), strStatus\n".
				"FROM tbl_Projects ".
				"WHERE date(dtmCreationDate) BETWEEN date('$$variable{'StartDate'}') AND date('$$variable{'EndDate'}') ";
		$_ .= "AND UserIndex = '".$r->param('ddmEstimator')."'\n" if $r->param('ddmEstimator');
		$_ .= "AND strStatus = '".$r->param('ddmStatus')."' \n" if $r->param('ddmStatus');
		$_ .= "AND CompanyIndex = '".$r->param('ddmCustomers')."' \n" if $r->param('ddmCustomers') ne '';
		$_ .= "AND CompanyIndex IN ( SELECT Index FROM Company WHERE lngSalesperson='".$r->param('ddmEmployees')."')\n" if $r->param('ddmEmployees') ne '';
		$_ .= "ORDER BY lngProjectIndex";

		my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, $variable, 'project_report.csv', \@header, \@data );
	} else {
		$_ = "SELECT DISTINCT (SELECT id FROM Companies WHERE id = CompanyIndex),\n".
			"				(SELECT Name FROM Companies WHERE id = CompanyIndex),\n".
			"				Index, SUBSTR(strProjectReference,0,50), to_char(dtmCreationDate, 'MM/DD/YYYY'), strStatus \n".
				"FROM tbl_Projects	".
				"WHERE date(dtmCreationDate) BETWEEN date('$$variable{'StartDate'}') AND date('$$variable{'EndDate'}') ";
		$_ .= "AND UserIndex = '".$r->param('ddmEstimator')."'\n" if $r->param('ddmEstimator');
		$_ .= "AND strStatus = '".$r->param('ddmStatus')."' \n" if $r->param('ddmStatus');
		$_ .= "AND CompanyIndex = '".$r->param('ddmCustomers')."' \n" if $r->param('ddmCustomers') ne '';
		$_ .= "AND CompanyIndex IN ( SELECT id FROM Companies WHERE lngSalesperson='".$r->param('ddmEmployees')."')\n" if $r->param('ddmEmployees') ne '';
		$_ .= "ORDER BY Index";
		@{$$variable{'DATA'}} = sql::execute( $log, $dbh, $_ );
	} # end if

} # end sub project_report

sub quotes {
	my ( $r, $log, $dbh, $variable ) = @_;

	ssi::get_start_end_dates( $log, $dbh, $variable,
			$r->param('ddmStartYear'),
			$r->param('ddmStartMonth'),
			$r->param('ddmStartDay'),
			$r->param('ddmEndYear'),
			$r->param('ddmEndMonth'),
			$r->param('ddmEndDay') );

    $$variable{'dblTotal1'} = $r->param('dblTotal1');
    $$variable{'dblTotal2'} = $r->param('dblTotal2');

	$$variable{'ddmStatus'.$r->param('ddmStatus')} = 'SELECTED';

	if ( $r->param('btnFunction') eq 'Download in CSV format' ) {
		my @header = ( 'lngQuoteID', 'dtmQuoteDate', 'strPrepared By', 'strPreparedFor','Total1','Total2','Total3' );
		$_ = "SELECT DISTINCT tbl_Quotes.lngQuoteID, to_char(tbl_Quotes.dtmQuoteDate, 'MM/DD/YYYY'),\n".
			"tbl_Quote_Users_By.strFirstName || ' ' || tbl_Quote_Users_By.strLastName,\n".
			"tbl_Quote_Users_For.strFirstName || ' ' || tbl_Quote_Users_For.strLastName,\n".
			"strStatus,\n".
			"tbl_Quotes.curTotalSale1, curTotalSale2, curTotalSale3\n".
			"FROM tbl_Quotes, tbl_Quote_Users_For, tbl_Quote_Users_By ".
			"WHERE tbl_Quote_Users_By.lngQuoteID = tbl_Quotes.lngQuoteID ".
			"AND tbl_Quote_Users_For.lngQuoteID = tbl_Quotes.lngQuoteID ".
			"AND tbl_Quotes.lngQuoteID IN ( ".
			"	SELECT DISTINCT tbl_Quotes.lngQuoteID FROM	tbl_Quotes, tbl_Quote_Details ".
			"	WHERE date(tbl_Quotes.dtmQuoteDate) BETWEEN date('$$variable{'StartDate'}') AND date('$$variable{'EndDate'}') ";
		$_ .= "AND tbl_Quotes.strStatus = '".$r->param('ddmStatus')."'\n" if $r->param('ddmStatus');
		$_ .= "	AND tbl_Quote_Details.lngQuoteID = tbl_Quotes.lngQuoteID ";
		$_ .= "	AND tbl_Quotes.CompanyIndex = '".$r->param('ddmCustomers')."' \n" if $r->param('ddmCustomers') ne '';
		if ( $r->param('dblTotal1') and $r->param('dblTotal2') ) {
			$_ .= " AND ( ";
			$_ .= "tbl_Quotes.curTotalSale1 BETWEEN ".$r->param('dblTotal1')." AND ".$r->param('dblTotal2')."\n";
			$_ .= " OR ";
			$_ .= "tbl_Quotes.curTotalSale2 BETWEEN ".$r->param('dblTotal1')." AND ".$r->param('dblTotal2')."\n";
			$_ .= " OR ";
			$_ .= "tbl_Quotes.curTotalSale3 BETWEEN ".$r->param('dblTotal1')." AND ".$r->param('dblTotal2')."\n";
			$_ .= " )\n";
		} # end if

		$_ .= ") ORDER BY tbl_Quotes.lngQuoteID";

		my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, $variable, 'quote_report.csv', \@header, \@data );
	} else {
		$_ = "SELECT DISTINCT tbl_Quotes.Index, to_char(tbl_Quotes.dtmQuoteDate, 'MM/DD/YYYY'),\n".
			"tbl_Quote_Users_By.strFirstName || ' ' || tbl_Quote_Users_By.strLastName,\n".
			"tbl_Quote_Users_For.strFirstName || ' ' || tbl_Quote_Users_For.strLastName,\n".
			"strStatus,\n".
			"tbl_Quotes.curTotalSale1, curTotalSale2, curTotalSale3\n".
			"FROM tbl_Quotes, tbl_Quote_Users_For, tbl_Quote_Users_By ".
			"WHERE tbl_Quote_Users_By.QuoteIndex = tbl_Quotes.Index ".
			"AND tbl_Quote_Users_For.QuoteIndex = tbl_Quotes.Index ".
			"AND tbl_Quotes.Index IN ( ".
			"SELECT tbl_Quotes.Index FROM tbl_Quotes, tbl_Quote_Details ".
			"WHERE date(tbl_Quotes.dtmQuoteDate) BETWEEN date('$$variable{'StartDate'}') AND date('$$variable{'EndDate'}') ";
		$_ .= "AND tbl_Quotes.strStatus = '".$r->param('ddmStatus')."'\n" if $r->param('ddmStatus');
		$_ .= "	AND tbl_Quote_Details.QuoteIndex = tbl_Quotes.Index ";
		$_ .= "	AND tbl_Quotes.CompanyIndex = '".$r->param('ddmCustomers')."' \n" if $r->param('ddmCustomers') ne '';
		if ( $r->param('dblTotal1') and $r->param('dblTotal2') ) {
			$_ .= " AND ( ";
			$_ .= "tbl_Quotes.curTotalSale1 BETWEEN ".$r->param('dblTotal1')." AND ".$r->param('dblTotal2')."\n";
			$_ .= " OR ";
			$_ .= "tbl_Quotes.curTotalSale2 BETWEEN ".$r->param('dblTotal1')." AND ".$r->param('dblTotal2')."\n";
			$_ .= " OR ";
			$_ .= "tbl_Quotes.curTotalSale3 BETWEEN ".$r->param('dblTotal1')." AND ".$r->param('dblTotal2')."\n";
			$_ .= " )\n";
		} # end if

		$_ .= ") ORDER BY tbl_Quotes.Index";
		@{$$variable{'DATA'}} = sql::execute( $log, $dbh, $_ );
		$$variable{'ReportTotal1'} = 0;
		$$variable{'ReportTotal2'} = 0;
		$$variable{'ReportTotal3'} = 0;
		for ( my $index = 0; $index < @{$$variable{'DATA'}}; $index += 8 ) {
			$$variable{'ReportTotal1'} += $$variable{'DATA'}[$index+5];
			$$variable{'ReportTotal2'} += $$variable{'DATA'}[$index+6];
			$$variable{'ReportTotal3'} += $$variable{'DATA'}[$index+7];
		} # end for
		$$variable{'ReportTotal1'} = sprintf("%.2f", $$variable{'ReportTotal1'} );
		$$variable{'ReportTotal2'} = sprintf("%.2f", $$variable{'ReportTotal2'} );
		$$variable{'ReportTotal3'} = sprintf("%.2f", $$variable{'ReportTotal3'} );
	} # end if

} # end sub quotes

sub orders {
	my ( $r, $log, $dbh, $variable ) = @_;
	
	my @products;

	if ( $r->param('ddmCategories') ne '' ) {
		$_ = "SELECT lngProductIndex FROM tbl_Products WHERE lngCategoryIndex = '" . $r->param('ddmCategories') ."'";
		@products = sql::execute( $log, $dbh, $_ );
	} elsif ( $r->param('ddmProducts') ne '' ) {
		@products = ( $r->param('ddmProducts') );
	} # end if

	if ( $r->param('btnFunction') eq 'Download in CSV format' ) {
		my @header = ('OrderID', 'Order Date', 'Company Name', 'Status', 'Total');
		$_ = "SELECT Index, to_char(Orders.dtmOrderDate, 'MM/DD/YYYY'), ".
			"strCompanyName, strStatus, (SELECT SUM(curSalesPrice) FROM Order_Contents WHERE OrderIndex=Index)\n".
			"FROM Orders, Order_Contents ".
			"WHERE dtmOrderDate BETWEEN '$$variable{'StartDate'}' AND '$$variable{'EndDate'}' ";
# whether to show finished, unfinished or both
		$_ .= "AND strStatus = '".$r->param('ddmStatus')."'\n" if $r->param('ddmStatus');
		$_ .= "AND OrderIndex = Index \n";
# which products
		$_ .= "AND Order_Contents.lngProductIndex IN ('" . join( ',', @products ) . "') \n" if @products != 0;
# which customers
		$_ .= "	AND Orders.CompanyIndex = '" . $r->param('ddmCustomers') ."' \n" if $r->param('ddmCustomers') ne '';
		$_ .= " AND Orders.CompanyIndex IN ( SELECT DISTINCT CompanyIndex FROM Companys_In_Categories WHERE lngCategoryID='".$r->param('ddmMarketingCategory')."')\n" if $r->param('ddmMarketingCategory') ne '';
		#$_ .= "	AND Orders.lngEmployeeID = '" . $r->param('ddmEmployees') . "' \n" if $r->param('ddmEmployees') ne '';
		$_ .= " AND Orders.CompanyIndex IN ( SELECT Index FROM Company WHERE lngSalesPerson='".$r->param('ddmEmployees')."')" if $r->param('ddmEmployees') ne '';
		$_ .= " AND Orders.curTotalSale BETWEEN " . $r->param('dblTotal1') . " AND " . $r->param('dblTotal2') . "\n" if $r->param('dblTotal1') and $r->param('dblTotal2');
		$_ .= " AND Orders.strCurrencyName = '" . $r->param('ddmCurrency') . "'" if $r->param('ddmCurrency') ne '';
		$_ .= "ORDER BY Index";

		my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, $variable, 'order_report.csv', \@header, \@data );
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
	my ( $r, $log, $dbh, $variable ) = @_;

	$$variable{'rdbActive'} = $r->param('rdbActive');
	
	ssi::get_start_end_dates( $log, $dbh, $variable,
			$r->param('ddmStartYear'),
			$r->param('ddmStartMonth'),
			$r->param('ddmStartDay'),
			$r->param('ddmEndYear'),
			$r->param('ddmEndMonth'),
			$r->param('ddmEndDay') );

	@$variable{'LastProjectStartYears','LastProjectStartMonths','LastProjectStartDays','LastProjectStart'} = ssi::get_dates( $log, $dbh,
			@openprint::param{'ddmLastProjectStartYear','ddmLastProjectStartMonth','ddmLastProjectStartDay'} );
	@$variable{'LastProjectEndYears','LastProjectEndMonths','LastProjectEndDays','LastProjectEnd'} = ssi::get_dates( $log, $dbh,
			$r->param('ddmLastProjectEndYear'), $r->param('ddmLastProjectEndMonth'),$r->param('ddmLastProjectEndDay') );

	@$variable{'LastOrderStartYears','LastOrderStartMonths','LastOrderStartDays','LastOrderStart'} = ssi::get_dates( $log, $dbh,
			$r->param('ddmLastOrderStartYear'), $r->param('ddmLastOrderStartMonth'),$r->param('ddmLastOrderStartDay') );
	@$variable{'LastOrderEndYears','LastOrderEndMonths','LastOrderEndDays','LastOrderEnd'} = ssi::get_dates( $log, $dbh,
			$r->param('ddmLastOrderEndYear'), $r->param('ddmLastOrderEndMonth'),$r->param('ddmLastOrderEndDay') );

	if ( $r->param('btnFunction') eq 'Download in CSV format' ) {
		my $query = "SELECT strName, strFirstName || ' ' || strLastName, Users.strPhone, strEmail,";
		$query .=  "strCity, strProvState, date(Company.dtmdateentered),";
		$query .=  "(SELECT strFirstName || ' ' || strLastName FROM Users WHERE Index = lngSalesPerson ),";
		$query .=  "(SELECT COUNT(Index) FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ),";
        $query .= "(SELECT date(MAX(dtmCreationDate)) as lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ),";
		$query .=  "(SELECT COUNT(Index) FROM Orders WHERE Orders.CompanyIndex = Company.Index ),";
		$query .=  "'\$' || (SELECT SUM(curtotalsale) FROM Orders WHERE Orders.CompanyIndex = Company.Index ),";
        $query .= " (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index ) AS LastOrderDate ";
		$query .=  "FROM Company, Users ";
		$query .=  "WHERE date(Company.dtmdateentered) BETWEEN date('$$variable{'StartDate'}') AND date('$$variable{'EndDate'}') ";
		$query .=  "AND Users.CompanyIndex = Company.Index ";
		$query .=  "AND Users.Index = (SELECT MIN(Index) FROM Users WHERE Users.CompanyIndex = Company.Index ) ";
      if ( $r->param('ddmEmployees') ) {
            if ( $r->param('ddmEmployees') eq 'None' ) {
                $query .= " AND lngsalesperson IS NULL OR lngSalesPerson NOT IN ( SELECT id FROM Users WHERE Type='E' AND strEmployeeType='Sales')";
            } else {
                $query .= " AND lngsalesperson=" . $r->param('ddmEmployees');
            } # end if
        } # end if

        if ( $r->param('ddmLastProjectStartYear') and $r->param('ddmLastProjectStartMonth') and $r->param('ddmLastProjectStartDay') ) {
            if ( $r->param('ddmLastProjectEndYear') and $r->param('ddmLastProjectEndMonth') and $r->param('ddmLastProjectEndDay') ) {
                $query .= " AND (SELECT date(MAX(dtmCreationDate)) as lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ) BETWEEN date('$$variable{'LastProjectStart'}') AND date('$$variable{'LastProjectEnd'}')";
            } else {
                $query .= " AND (SELECT date(MAX(dtmCreationDate)) as lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ) > date('$$variable{'LastProjectStart'}')";
            } # end if
        } elsif ( $r->param('ddmLastProjectEndYear') and $r->param('ddmLastProjectEndMonth') and $r->param('ddmLastProjectEndDay') ) {
            $query .= " AND (SELECT date(MAX(dtmCreationDate)) AS lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ) < date('$$variable{'LastProjectEnd'}')";
        } # end if

        if ( $r->param('ddmLastOrderStartYear') and $r->param('ddmLastOrderStartMonth') and $r->param('ddmLastOrderStartDay') ) {
            if ( $r->param('ddmLastOrderEndYear') and $r->param('ddmLastOrderEndMonth') and $r->param('ddmLastOrderEndDay') ) {
                $query .= " AND (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index ) BETWEEN date('$$variable{'LastOrderStart'}') AND date('$$variable{'LastOrderEnd'}')";
            } else {
                $query .= " AND (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index )  > date('$$variable{'LastOrderStart'}')";
            } # end if
        } elsif ( $r->param('ddmLastOrderEndYear') and $r->param('ddmLastOrderEndMonth') and $r->param('ddmLastOrderEndDay') ) {
            $query .= " AND (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index )  < date('$$variable{'LastOrderEnd'}')";
        } # end if
        if ( $$variable{'rdbActive'} ) {
            $query .= " AND Company.ysnAccountActivation = '$$variable{'rdbActive'}'\n";
        } # end if

		my @header = ( 'Company Name','Contact Name', 'Phone #', 'Email','City','State','Registration Date','Account Rep','# of Projects','Last Project','# of Orders','Total', 'Last Order');
		my @data = sql::execute( $log, $dbh, $query );
		misc::export_csv( $r, $log, $variable, 'customer_report.csv', \@header, \@data );
	} else {
       my $query = "SELECT Company.Index, strName, ";
        $query .=  "strProvState, date(Company.dtmdateentered),";
        $query .=  "(SELECT strFirstName || ' ' || strLastName FROM Users WHERE Index = lngSalesPerson ),";
        $query .=  "(SELECT COUNT(Index) FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ),";
        $query .= "(SELECT date(MAX(dtmCreationDate)) as lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ),";
        $query .=  "(SELECT COUNT(Orders.Index) FROM Orders WHERE Orders.CompanyIndex = Company.Index ),";
        $query .=  "(SELECT SUM(curtotalsale) FROM Orders WHERE Orders.CompanyIndex = Company.Index )";
        $query .= ", (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index ) AS LastOrderDate ";
        $query .=  "FROM Company WHERE date(Company.dtmdateentered) BETWEEN date('$$variable{'StartDate'}') AND date('$$variable{'EndDate'}') ";
		#$query .=  " AND Users.Index = (SELECT MIN(Users.Index) FROM Users WHERE Users.CompanyIndex = Company.lndex )";

		if ( $r->param('ddmEmployees') ) {
			if ( $r->param('ddmEmployees') eq 'None' ) {
				$query .= " AND lngsalesperson IS NULL OR lngSalesPerson NOT IN ( SELECT id FROM Users WHERE type='E' AND strEmployeeType='Sales')";
			} else {
				$query .= " AND lngsalesperson=" . $r->param('ddmEmployees');
			} # end if
		} # end if

		if ( $r->param('ddmLastProjectStartYear') and $r->param('ddmLastProjectStartMonth') and $r->param('ddmLastProjectStartDay') ) {
			if ( $r->param('ddmLastProjectEndYear') and $r->param('ddmLastProjectEndMonth') and $r->param('ddmLastProjectEndDay') ) {
				$query .= " AND (SELECT date(MAX(dtmCreationDate)) as lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ) BETWEEN date('$$variable{'LastProjectStart'}') AND date('$$variable{'LastProjectEnd'}')";
			} else {
				$query .= " AND (SELECT date(MAX(dtmCreationDate)) as lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ) > date('$$variable{'LastProjectStart'}')";
			} # end if
		} elsif ( $r->param('ddmLastProjectEndYear') and $r->param('ddmLastProjectEndMonth') and $r->param('ddmLastProjectEndDay') ) {
			$query .= " AND (SELECT date(MAX(dtmCreationDate)) AS lastprojectdate FROM tbl_Projects WHERE tbl_Projects.CompanyIndex = Company.Index ) < date('$$variable{'LastProjectEnd'}')";
		} # end if

        if ( $r->param('ddmLastOrderStartYear') and $r->param('ddmLastOrderStartMonth') and $r->param('ddmLastOrderStartDay') ) {
            if ( $r->param('ddmLastOrderEndYear') and $r->param('ddmLastOrderEndMonth') and $r->param('ddmLastOrderEndDay') ) {
				$query .= " AND (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index ) BETWEEN date('$$variable{'LastOrderStart'}') AND date('$$variable{'LastOrderEnd'}')";
			} else {
				$query .= " AND (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index )  > date('$$variable{'LastOrderStart'}')";
			} # end if
		} elsif ( $r->param('ddmLastOrderEndYear') and $r->param('ddmLastOrderEndMonth') and $r->param('ddmLastOrderEndDay') ) {
			$query .= " AND (SELECT date(MAX(dtmOrderDate)) AS lastorder FROM Orders WHERE Orders.CompanyIndex = Company.Index )  < date('$$variable{'LastOrderEnd'}')";
		} # end if
		if ( $$variable{'rdbActive'} ) {
			$query .= " AND Company.ysnAccountActivation = '$$variable{'rdbActive'}'\n";
		} # end if

		@{$$variable{'DATA'}} = sql::execute( $log, $dbh, $query );
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

	my $query = "SELECT Index, strStatus, (SELECT lngSalesPerson FROM Company WHERE Company.Index=tbl_Projects.CompanyIndex),
	   ";
	$query .= "(SELECT curSalesPrice FROM Order_Contents, Orders WHERE Orders.Index=Order_Contents.OrderIndex AND Order_Contents.lngProjectIndex=tbl_Projects.Index AND Orders.lngDocketNumber=tbl_Projects.lngDocketNumber),";
	$query .= "(SELECT currency_id FROM Orders WHERE Orders.lngDocketNumber=tbl_Projects.lngDocketNumber)";

	$query .= " FROM tbl_Projects ";
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
		if ( sql::execute( undef, undef, q{SELECT * FROM Payments WHERE strSessionID IS NULL AND Order_Id=?}, $order_id ) ) {
			$$variable{'error'} .= "Order $order_id appears to have payments.  Please delete the payments before deleting the order.";
		} else {
		$Order->delete();
		$$variable{'Redirect'} = '/administrator/reports/orders.html';
		return;
		} # en dif
	} elsif ( $r->param('btnFunction') eq 'Resend' ) {
		sql::update( $log, $dbh, 'Orders',"Index=$order_id", 'strComments',$r->param('txtComments') );
		openprint::order::order_send_email( $r, $log, $dbh, $order_id );
	} elsif ( $openprint::param{'btnFunction'} eq 'Pay' ) {
		$Order->pay();
	} elsif ( $openprint::param{'btnFunction'} eq 'Save Payment' ) {

		if ( ( ! $openprint::param{'Amount'} ) or $openprint::param{'Amount'} =~ /[^-\$\d\.]/ ) {
			return misc::error( $log, $dbh, $variable, 'Invalid Amount', 'Please enter a valid monetary amount.' );
		} # end if

		my $error = sql::insert( $log, $dbh, 'Payments',
				'Order_Id',     $order_id,
				'Company_Id',   $Order->company_id(),
				'curAmount',    $openprint::param{'Amount'},
				'dtmDate',      'NOW()',
				'strMethod',    'Manual',
				'currency_id',  $Order->currency_id(),
				'strDescription',   $openprint::param{'Description'},
				);
		if ( $error ) {
			return misc::error( $log, $dbh, $variable, 'Error Saving Payment', $error );
		} # end if

		openprint::order::get_misc( $log, $dbh, $variable, $order_id );

		if ( $$variable{'DepositDue'} > 0 ) {
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
			if ( $$variable{'AmountPaid'} >= $$variable{'TOTAL'} ) {
				$Order->status('Paid') if $Order->status() eq 'Complete';
			} # end if
			$Order->save();
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete Payment' ) {
		my $payment_index = $openprint::param{'payment_id'};
		$payment_index =~ s/\D//g;
		if ( $payment_index ) {
			sql::execute( $log, $dbh, 'DELETE FROM Payments WHERE id=?', $payment_index );
		} # end if
		$Order->update_status();
	} elsif ( $openprint::param{'btnFunction'} eq 'Invoice' ) {
		$Order->invoice_id( $openprint::param{'invoice_id'} );
		$Order->invoiced_on( 'NOW()' );
		$Order->save();
	} elsif ( $openprint::param{'btnFunction'} eq 'Cancel' ) {
		openprint::order::cancel_order( $log, $dbh, $order_id );
    } # end if
	$$variable{'Order'} = $Order;
    openprint::order::display_order( $log, $dbh, $variable, $order_id );
} # end sub display_order

sub uploads {
	require openprint::Upload;
} # end sub uploads

1;

__END__

