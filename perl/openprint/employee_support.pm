package openprint::employee_support;

use Mail::Sendmail;
use MIME::QuotedPrint;
use openprint ();
use strict;

require sql;
require misc;
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
		my $email_template = ssi::variable_substitution( \$_, \%info );

		my $Email = new openprint::Email();
		$Email->send(
			FROM	=> $config{'HelpdeskEmail'},
			TO		=> $email,
			SUBJECT	=> 'Your help desk submission has been reviewed.',
			ATTACHMENTS	=>	[ '', encode_qp($email_template), 'text/html', 'quoted-printable' ],
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
	my $rma = $param{'rma_id'};


	$_ = q{SELECT company_id,
		to_char(dtmRequestDate,'MM/DD/YYYY'), chrRMAType, strDescription, ysnApprove, txtComments,strRMANumber,
		order_id, (SELECT dtmOrderDate FROM Orders WHERE Orders.id=RMA.order_id),
		project_id, (SELECT strReference FROM Projects WHERE Projects.id=project_id)
		FROM RMA WHERE id=?};
	@variable{'CustomerIndex', 
		'RequestDate', 'RMAType','Problem','Verdict','txtAdminComments','RMANumber',
		'OrderID', 'OrderDate',
		'ProjectIndex','ProjectReference'
	} = sql::execute( $log, $dbh, $_, $rma );
	$variable{'CompanyName'} = new openprint::Company( $variable{'CustomerIndex'} )->name();


	$variable{'rmatype'} = 'Credit' if $variable{'RMAType'} eq 'C';
	$variable{'rmatype'} = 'Reproduction' if $variable{'RMAType'} eq 'R';
	$variable{'rmatype'} = 'Service' if $variable{'RMAType'} eq 'S';

	$variable{'rdbVerdict'.$variable{'Verdict'}} = 'CHECKED';

	$variable{'RMAIndex'} = $rma;
} # end sub rma

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
	push @values, sprintf('%.4d-%.2d-%.2d 00:00:00', @params{'created_on_start_year','created_on_start_month','created_on_start_day'});
	push @values, sprintf('%.4d-%.2d-%.2d 00:00:00', @params{'created_on_end_year','created_on_end_month','created_on_end_day'});
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
		'created_on_start_year', 'created_on_start_month', 'created_on_start_day',
		'created_on_end_year', 'created_on_end_month', 'created_on_end_day',
		);

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
		$Email->send(
				FROM	=> $config{'RMAEmail'},
				TO		=> $To,
				SUBJECT	=> 'Your RMA has been reviewed.',
				ATTACHMENTS => [ '', encode_qp($email_template), 'text/html', 'quoted-printable' ],
		);

	} # end if
	ssi::get_start_end_dates( $log, $dbh, \%variable, 
			$r->param('ddmStartYear'),
			$r->param('ddmStartMonth'),
			$r->param('ddmStartDay'),
			$r->param('ddmEndYear'),
			$r->param('ddmEndMonth'),
			$r->param('ddmEndDay') );

	$_ = "SELECT id, (SELECT name FROM Companies WHERE id=company_id), order_id, to_char(dtmRequestDate,'MM/DD/YYYY'), ysnApprove FROM RMA\n";
	$_ .= "WHERE dtmRequestDate BETWEEN '$variable{'StartDate'} 00:00:00' AND '$variable{'EndDate'} 23:59:59'\n";
	$_ .= "AND ysnReviewed = '".$param{'ddmReviewed'}."'\n" if $param{'ddmReviewed'};
	$_ .= "AND company_id = '".$param{'ddmCustomers'}."'\n" if $param{'ddmCustomers'};
	$_ .= "ORDER BY id";
	@{$variable{'RMAS'}} = sql::execute( $log, $dbh, $_ );

	$variable{'ddmReviewed'.$param{'ddmReviewed'}} = 'selected';

} # end sub rma_search 


1;
__END__
