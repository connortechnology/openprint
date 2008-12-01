package openprint::employee_support;

use Mail::Sendmail;
use MIME::QuotedPrint;
use strict;

require sql;
require misc;

sub helpdesk {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $index = $r->param('helpdesk_id');

	if ( $r->param('btnFunction') eq 'Submit' ) {
		sql::update( $log, $dbh, 'HelpDesk', "Id =$index", 
			'ysnReviewed',	$r->param('rdbReviewed'),
			'blbResponse',	$r->param('txtQuestion-Quote')
		);
		$_ = "SELECT Users.strFirstName || ' ' || Users.strLastName, Users.strEmail\n".
			"FROM HelpDesk,Users WHERE HelpDesk.Id = $index\n".
			"AND Users.Index=UserId\n";

		my ($name, $email) = sql::execute( $log, $dbh, $_);

		my %info;
		$_ = "SELECT to_char(dtmRequestDate,'MM/DD/YYYY'), strDescription,blbResponse FROM HelpDesk WHERE Id=$index";
		$info{'RequestDate','Question', 'Response'} = sql::execute( $log, $dbh, $_);

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/helpdesk_response.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		$_ = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );
		my $email_template = ssi::variable_substitution( \$_, \%info );

		my %mail = (
			SMTP	=> $openprint::config{'Mail Server'},
			FROM	=> $openprint::config{'HelpdeskEmail'},
			TO		=> $email,
			SUBJECT	=> 'Your help desk submission has been reviewed.',
		);
		misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );
	} # end if

	$_ = "SELECT strCompanyName, strTitle, strFirstName, strLastName, strAddress, strAddress2, strCity,
		 strStateProv, strPostalCode, strCountry, strPhone, strExtension, strEmail, blbQuestion, chrMethod,
		 ysnReviewed, blbResponse, to_char(dtmRequestDate,'MM/DD/YYYY')
		 FROM HelpDesk WHERE Id= $index";
	@$variable{'company_name', 'title', 'first_name', 'last_name', 'address_one', 'address_two',
			'city', 'state', 'postal_code', 'country', 'phone', 'extension', 'email', 'question',
			'method', 'rdbReviewed', 'response', 'sub_date' } = sql::execute( $log, $dbh, $_);

	$$variable{'response_type'} = "Email" if $$variable{'method'} eq 'E';
	$$variable{'response_type'} = "Phone" if $$variable{'method'} eq 'P';

	$$variable{'rdbReviewed'.$$variable{'rdbReviewed'}} = 'CHECKED';
	$$variable{'HelpdeskIndex'} = $index;

} # end sub helpdesk

sub rma {
	my ( $r, $log, $dbh, $variable ) = @_;
	
	my $rma = $r->param('rma_id');


	$_ = q{SELECT company_id,
		to_char(dtmRequestDate,'MM/DD/YYYY'), chrRMAType, strDescription, ysnApprove, txtComments,strRMANumber,
		order_id, (SELECT dtmOrderDate FROM Orders WHERE Orders.Index=RMA.order_id),
		project_id, (SELECT strReference FROM tbl_Projects WHERE tbl_Projects.Index=project_id)
		FROM RMA WHERE id=?};
	@$variable{'CustomerIndex', 
		'RequestDate', 'RMAType','Problem','Verdict','txtAdminComments','RMANumber',
		'OrderID', 'OrderDate',
		'ProjectIndex','ProjectReference'
	} = sql::execute( $log, $dbh, $_, $rma );
	$$variable{'CompanyName'} = new openprint::Company( $$variable{'CustomerIndex'} )->name();


	$$variable{'rmatype'} = 'Credit' if $$variable{'RMAType'} eq 'C';
	$$variable{'rmatype'} = 'Reproduction' if $$variable{'RMAType'} eq 'R';
	$$variable{'rmatype'} = 'Service' if $$variable{'RMAType'} eq 'S';

	$$variable{'rdbVerdict'.$$variable{'Verdict'}} = 'CHECKED';

	$$variable{'RMAIndex'} = $rma;
} # end sub rma

sub helpdesk_search {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $r->param('btnFunction') eq 'Submit' ) {
		my $index = $r->param('HelpdeskIndex');
		sql::update( $log, $dbh, 'HelpDesk', ['id=?', $index], [
				'ysnReviewed',	$r->param('rdbReviewed'),
				'blbResponse',	$r->param('txtQuestion-Quote')
				] );
		$_ = "SELECT Users.strFirstName || ' ' || Users.strLastName, Users.strEmail\n".
			"FROM HelpDesk,Users WHERE HelpDesk.Id=$index\n".
			"AND Users.Index=User_Id\n";

		my ($name, $email) = sql::execute( $log, $dbh, $_);
		my %mail = (
				SMTP	=> $openprint::config{'Mail Server'},
				FROM	=> $openprint::config{'HelpdeskEmail'},
				TO		=> $email,
				SUBJECT => 'Your help desk submission has been reviewed.',
				BODY	=> $r->param('txtQuestion-Quote') );
		sendmail(%mail) || $log->warn( "Error: $Mail::Sendmail::error\n" );
	} # end if


	ssi::get_start_end_dates( $log, $dbh, $variable, 
			$r->param('ddmStartYear'),
			$r->param('ddmStartMonth'),
			$r->param('ddmStartDay'),
			$r->param('ddmEndYear'),
			$r->param('ddmEndMonth'),
			$r->param('ddmEndDay') );

	my $sql = q{SELECT id, strFirstName || ' ' || strLastName, date(dtmRequestDate), strCompanyName, ysnReviewed FROM HelpDesk};
	my @values;
	push @values, sprintf('%s 00:00:00', $$variable{'StartDate'});
	push @values, sprintf('%s 23:59:59', $$variable{'EndDate'});
	$sql .= ' WHERE ( dtmREquestDate BETWEEN ? AND ? )';
	if ( $openprint::param{'ddmReviewed'} ) {
		$sql .= ' AND ysnReviewed = ?';
		push @values, $openprint::param{'ddmReviewed'};
	} # end if
	if ( $openprint::param{'ddmCustomers'} ) {
		$sql .= 'AND company_id = ?';
		push @values, $openprint::param{'ddmCustomers'};
	} # end if
	$sql .= ' ORDER BY Id';
	@{$$variable{'HELPDESKENTRIES'}} = sql::execute( $log, $dbh, $sql, @values );

	$$variable{'ddmReviewed'.$r->param('ddmReviewed')} = 'SELECTED';

} # end sub helpdesk_search

sub returns {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $r->param('btnFunction') eq 'Send' ) {
		my $rma = $r->param('rma_id');
		sql::update( $log, $dbh, 'RMA', "id = '$rma'",
			'ysnApprove',	$r->param('rdbVerdict'),
			'strRMANumber',	$r->param('RMANumber'),
			'txtComments',	$r->param('txtAdminComments'),
		);

		my %info;
		$_ = 'SELECT company_id,user_id,'.
			"to_char(dtmRequestDate,'MM/DD/YYYY'), chrRMAType, strDescription, ysnApprove, txtComments, strRMANumber,\n".
			"order_id, (SELECT dtmOrderDate FROM Orders WHERE Index=RMA.order_id),\n".
			"project_id, (SELECT strReference FROM tbl_Projects WHERE tbl_Projects.Index=RMA.project_id)\n".
			"FROM RMA WHERE id=?";
		@info{'company_id', 'user_id',
			'RequestDate', 'RMAType','Problem','Verdict','txtAdminComments','RMANumber',
			'OrderID', 'OrderDate',
			'ProjectIndex','ProjectReference'
		} = sql::execute( $log, $dbh, $_, $rma );
		$$variable{'CompanyName'} = new openprint::Company( $$variable{'company_id'} )->name();
		$$variable{'UserName'} = join( ' ', new openprint::User( $$variable{'user_id'} )->get('salutation','firstname','lastname') );
		$$variable{'Email'} = new openprint::User( $$variable{'user_id'} )->email();

		$info{'SecureSiteURL'} = $r->dir_config('SecureSiteURL');
		$info{'siteURL'} = $r->dir_config('siteURL');

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/rma_response.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		my $email_template = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );
		$email_template = ssi::variable_substitution( \$email_template, \%info );

		my %mail = (
				SMTP	=> $openprint::config{'Mail Server'},
				FROM	=> $openprint::config{'RMAEmail'},
				TO		=> $info{'Email'},
				SUBJECT	=> 'Your RMA has been reviewed.'
		);
		misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );

	} # end if
	ssi::get_start_end_dates( $log, $dbh, $variable, 
			$r->param('ddmStartYear'),
			$r->param('ddmStartMonth'),
			$r->param('ddmStartDay'),
			$r->param('ddmEndYear'),
			$r->param('ddmEndMonth'),
			$r->param('ddmEndDay') );

	$_ = "SELECT id, (SELECT name FROM Companies WHERE id=company_id), order_id, to_char(dtmRequestDate,'MM/DD/YYYY'), ysnApprove FROM RMA\n";
	$_ .= "WHERE dtmRequestDate BETWEEN '$$variable{'StartDate'} 00:00:00' AND '$$variable{'EndDate'} 23:59:59'\n";
	$_ .= "AND ysnReviewed = '".$r->param('ddmReviewed')."'\n" if $r->param('ddmReviewed');
	$_ .= "AND company_id = '".$r->param('ddmCustomers')."'\n" if $r->param('ddmCustomers');
	$_ .= "ORDER BY id";
	@{$$variable{'RMAS'}} = sql::execute( $log, $dbh, $_ );

	$$variable{'ddmReviewed'.$r->param('ddmReviewed')} = 'selected';

} # end sub rma_search 


1;

__END__

