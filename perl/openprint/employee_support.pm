use strict;
package openprint::employee_support;

require sql;
require misc;
require openprint;
require openprint::RMA;
require openprint::RMA_Type;
require openprint::RMA_Status;
require openprint::Email;
require openprint::RMA_Log;
require openprint::RMA_Part;
require openprint::Fault_Found;
require openprint::Fault;
require openprint::Test;
require openprint::Test_Result;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub helpdesk {
	my $index = $param{'helpdesk_id'};

	if ( $param{'btnFunction'} eq 'Submit' ) {
		sql::update( $log, $dbh, 'HelpDesk', [ 'id =?', $index], 
			'ysnReviewed',	$param{'rdbReviewed'},
			'blbResponse',	$param{'txtQuestion-Quote'}
		);
		$_ = "SELECT Users.FirstName || ' ' || Users.LastName, Users.Email\n".
			"FROM HelpDesk,Users WHERE HelpDesk.Id = ?".
			"AND Users.id=UserId";

		my ($name, $email) = sql::execute( $log, $dbh, $_, $index);

		my %info;
		$_ = "SELECT to_char(dtmRequestDate,'MM/DD/YYYY'), strDescription,blbResponse FROM HelpDesk WHERE Id=?";
		$info{'RequestDate','Question', 'Response'} = sql::execute( $log, $dbh, $_, $index );

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/helpdesk_response.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		$_ = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );

		my $Email = new openprint::Email();
		$Email->html_body( ssi::variable_substitution( \$_, \%info ) );
		$Email->send(
			FROM	=> $config{'HelpdeskEmail'},
			TO		=> $email,
			SUBJECT	=> 'Your help desk submission has been reviewed.',
		);
	} # end if

	$_ = "SELECT strCompanyName, strTitle, strFirstName, strLastName, strAddress, strAddress2, strCity,
		 strStateProv, strPostalCode, strCountry, strPhone, strExtension, strEmail, blbQuestion, chrMethod,
		 ysnReviewed, blbResponse, to_char(dtmRequestDate,'MM/DD/YYYY')
		 FROM HelpDesk WHERE Id=?";
	@variable{'company_name', 'title', 'firstname', 'lastname', 'address_one', 'address_two',
			'city', 'state', 'postal_code', 'country', 'phone', 'extension', 'email', 'question',
			'method', 'rdbReviewed', 'response', 'sub_date' } = sql::execute( $log, $dbh, $_, $index );

	$variable{'response_type'} = "Email" if $variable{'method'} eq 'E';
	$variable{'response_type'} = "Phone" if $variable{'method'} eq 'P';

	$variable{'HelpdeskIndex'} = $index;

} # end sub helpdesk

sub rma {

	$param{rma_id} = openprint::RMA->transform('id', $param{rma_id} );
	my $RMA = $variable{RMA} = new openprint::RMA( $param{rma_id} );

} # end sub rma

sub _faults {
	$param{rma_id} = openprint::RMA->transform('id', $param{rma_id} );
	my $RMA = $variable{RMA} = new openprint::RMA( $param{rma_id} );
	if ( ! $RMA->id() ) {
		$variable{error} .= 'Invalid RMA# specified';
		return;
	} # end if
	if ( $param{action} eq 'Add' ) {
		$param{fault} = openprint::Fault->transform('name', $param{fault} );
		if ( $param{fault} ) {
			my $Fault = openprint::Fault->find_one('name lc'=>lc $param{fault});
			if ( ! $Fault ) {
				$Fault = new openprint::Fault();
				$variable{error} .= $Fault->save({name=>$param{fault}});
			} # end if
			$param{fault_id} = $Fault->id();
		} # end if
		delete $param{fault};

		my $Fault = new openprint::Fault_Found();
		$variable{error} .= $Fault->save({
			rma_id	=>	$RMA->id(),
			fault_id	=>	$param{fault_id},
			quantity	=>	$param{fault_quantity},
			action		=>	$param{action_taken},
			( $param{user_id} ? ( user_id => $param{user_id} ) : () ),
		});
		if ( ! $variable{error} ) {
			%param = ();
		} # end if
	} # end if
} # end sub faults

sub _tests {
	$param{rma_id} = openprint::RMA->transform('id', $param{rma_id} );
	my $RMA = $variable{RMA} = new openprint::RMA( $param{rma_id} );
	if ( ! $RMA->id() ) {
		$variable{error} .= 'Invalid RMA# specified';
		return;
	} # end if
	if ( $param{action} eq 'Add' ) {
		$param{test} = openprint::Test->transform('name', $param{test} );
		if ( $param{test} ) {
			my $Test = openprint::Test->find_one('name lc'=>lc $param{test});
			if ( ! $Test ) {
				$Test = new openprint::Test();
				$variable{error} .= $Test->save({name=>$param{fault}});
			} # end if
			$param{test_id} = $Test->id();
		} # end if
		delete $param{test};

		my $Result = new openprint::Test_Result();
		$variable{error} .= $Result->save({
			rma_id	=>	$RMA->id(),
			test_id	=>	$param{test_id},
			remarks	=>	$param{test_remarks},
			result_id	=>	$param{result_id},
			( $param{user_id} ? ( technician_id => $param{user_id} ) : () ),
		});
		if ( ! $variable{error} ) {
			%param = ();
		} # end if
	} # end if
} # end sub _tests

sub _parts {
	$param{rma_id} = openprint::RMA->transform('id', $param{rma_id} );
	my $RMA = $variable{RMA} = new openprint::RMA( $param{rma_id} );
	if ( ! $RMA->id() ) {
		$variable{error} .= 'Invalid RMA# specified';
		return;
	} # end if
	if ( $param{action} eq 'Add' ) {
		$param{parts_product_id} = openprint::Product->transform('id', $param{parts_product_id} );
		if ( ! $param{parts_product_id} ) {
			$variable{error} .= 'No part specified.';
			return;
		} # end if
	
		my $Product = openprint::Product->find_one( id=>$param{parts_product_id} );
		if ( ! $Product ) {
			$variable{error} .= 'Product not found.';
			return;
		} # end if

		my $Part = new openprint::RMA_Part();
		$variable{error} .= $Part->save({
			rma_id		=>	$RMA->id(),
			product_id	=>	$param{parts_product_id},
			serialnumber	=>	$param{serialnumber},
			quantity	=>	$param{parts_quantity},
		});
		if ( ! $variable{error} ) {
			%param = ();
		} # end if
	} # end if
} # end sub _parts

sub helpdesk_search {

	if ( $param{'btnFunction'} eq 'Submit' ) {
		my $index = $param{'HelpdeskIndex'};
		sql::update( $log, $dbh, 'HelpDesk', ['id=?', $index], [
				'ysnReviewed',	$param{'rdbReviewed'},
				'blbResponse',	$param{'txtQuestion-Quote'}
				] );

		my @user_ids = sql::execute( $log, $dbh, 'SELECT user_id FROM HelpDesk WHERE HelpDesk.Id=?', $index );

		my $Email = new openprint::Email();
		$variable{'information'} .= $Email->send(
				FROM	=> $config{'HelpdeskEmail'},
				TO		=> [ openprint::User->find( 'id in'=>\@user_ids ) ],
				SUBJECT => 'Your help desk submission has been reviewed.',
				BODY	=> $param{'txtQuestion-Quote'},
				);
	} # end if

	my $sql = q{SELECT id, strFirstName || ' ' || strLastName, date(dtmRequestDate), strCompanyName, ysnReviewed FROM HelpDesk};
	my @values;
	push @values, sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'created_on_start_year','created_on_start_month','created_on_start_day'});
	push @values, sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'created_on_end_year','created_on_end_month','created_on_end_day'});
	$sql .= ' WHERE ( dtmREquestDate BETWEEN ? AND ? )';
	if ( $param{'ddmReviewed'} ) {
		$sql .= ' AND ysnReviewed = ?';
		push @values, $param{'ddmReviewed'};
	} # end if
	if ( $param{'ddmCustomers'} ) {
		$sql .= 'AND company_id = ?';
		push @values, $param{'ddmCustomers'};
	} # end if
	$sql .= ' ORDER BY Id';
	@{$variable{'HELPDESKENTRIES'}} = sql::execute( $log, $dbh, $sql, @values );

	$variable{'ddmReviewed'.$param{'ddmReviewed'}} = 'SELECTED';

	ssi::save_params( '/employee/support/helpdesk_search.html', (
			( map { 'created_on_start_'.$_ } ( 'year','month','day' ) ),
			( map { 'created_on_end_'.$_ } ( 'year','month','day' ) ),
		) );

} # end sub helpdesk_search

sub returns {

	if ( $param{'btnFunction'} eq 'Send' ) {
		my $rma = $param{'rma_id'};
		sql::update( $log, $dbh, 'RMA', [ 'id=?', $rma ],
			'ysnApprove',	$param{'rdbVerdict'},
			'strRMANumber',	$param{'RMANumber'},
			'txtComments',	$param{'txtAdminComments'},
		);

		my %info;
		$_ = 'SELECT company_id,user_id,'.
			"to_char(dtmRequestDate,'MM/DD/YYYY'), chrRMAType, strDescription, ysnApprove, txtComments, strRMANumber,\n".
			"order_id, (SELECT dtmOrderDate FROM Orders WHERE orders.id=RMA.order_id),\n".
			"project_id, (SELECT strReference FROM Projects WHERE Projects.id=RMA.project_id)\n".
			"FROM RMA WHERE id=?";
		@info{'company_id', 'user_id',
			'RequestDate', 'RMAType','Problem','Verdict','txtAdminComments','RMANumber',
			'OrderID', 'OrderDate',
			'ProjectIndex','ProjectReference'
		} = sql::execute( $log, $dbh, $_, $rma );
		$variable{'CompanyName'} = new openprint::Company( $variable{'company_id'} )->name();
		my $To = new openprint::User( $variable{'user_id'} );
		$variable{'UserName'} = join( ' ', $To->get('salutation','firstname','lastname') );
		$variable{'Email'} = $To->email();

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/rma_response.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
		$email_template = ssi::variable_substitution( \$email_template, \%info );

		my $Email = new openprint::Email();
		$Email->html_body( $email_template );
		$Email->send(
				FROM	=> $config{'RMAEmail'},
				TO		=> $To,
				SUBJECT	=> 'Your RMA has been reviewed.',
		);

	} # end if

	ssi::setup_date_select( '/employee/support/returns.html', 'created_on_start', -180 );
	ssi::setup_date_select( '/employee/support/returns.html', 'created_on_end', 0 );
	ssi::setup_date_select( '/employee/support/returns.html', 'updated_on_start', -60 );
	ssi::setup_date_select( '/employee/support/returns.html', 'updated_on_end', 0 );

	_returns();
} # end sub rma_search 

sub _returns {
	my $url = '/employee/support/returns.html';
	ssi::save_params( $url,
			'status', 'company_id',
			( map { 'created_on_start_'.$_ } ( 'year','month','day' ) ),
			( map { 'created_on_end_'.$_ } ( 'year','month','day' ) ),
			( map { 'updated_on_start_'.$_ } ( 'year','month','day' ) ),
			( map { 'updated_on_end_'.$_ } ( 'year','month','day' ) ),
			);

	my %companies = @{openprint::Company->dropdown()} if $session{user_type} ne 'A';
	my @company_ids = keys %companies;

	if ( $session{$url.'?company_id'} and ! sets::isin( $session{$url.'?company_id'}, \@company_ids ) ) {
		delete $session{$url.'?company_id'};
	} # end if

	if ( $param{rmanumber} ) {
		$param{rmanumber} .= '%' if $param{rmanumber} !~ /%/;
		@{$variable{RMAS}} = openprint::RMA->find( 'rmanumber ilike'=>$param{rmanumber}, order   =>  'rmanumber,id',
			( @company_ids ? ( company_id	=> ( $session{$url.'?company_id'} ? $session{$url.'?company_id'} : \@company_ids ) ) : () ),
 );
		
	} else {

		@{$variable{RMAS}} = openprint::RMA->find(
			ssi::date_filter( $url.'?created_on_start', 'created_on >=' ),
			ssi::date_filter( $url.'?created_on_end', 'created_on <=' ),
			ssi::date_filter( $url.'?updated_on_start', 'updated_on >=' ),
			ssi::date_filter( $url.'?updated_on_end', 'updated_on <=' ),
			( $session{$url.'?company_id'} or @company_ids ? ( company_id	=> ( $session{$url.'?company_id'} ? $session{$url.'?company_id'} : \@company_ids ) ) : () ),
			order	=>	'rmanumber,id',
		);
	} # end if
} # end sub _returns

1;
__END__
