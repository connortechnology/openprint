package openprint::support;

use MIME::QuotedPrint;
use Mail::Sendmail;
use Email::Valid;
use strict;
use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;

require sql;

sub returns {
} # end sub returns 

sub confirmation_returns {

	my $order_id = $param{'order_id'};
	my $prod_id = $param{'project_id'};
	my ( $check_order_id, $check_cust_id );

	if ( $param{'docket'} ) {
		$_ = 'SELECT Index, CompanyIndex FROM Orders WHERE lngDocketNumber=?';
		( $check_order_id, $check_cust_id ) = sql::execute( $log, $dbh, $_, $openprint::param{'docket'} );
	} elsif ( $param{'order_id'} ) {
		$_ = 'SELECT Index, CompanyIndex FROM Orders WHERE Index=?';
		( $check_order_id, $check_cust_id ) = sql::execute( $log, $dbh, $_, $order_id );
	} # end if

	if ( $check_order_id eq '' ) {
		return misc::error( $log, $dbh, \%variable, 'Error','Invalid Order ID' );
	} elsif ( $check_cust_id != $session{'company_id'} ) {
		return misc::error( $log, $dbh, \%variable, 'Error','You are not the owner of that order.' );
	} # end if

	$_ = 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?';
	if ( ! sql::execute( $log, $dbh, $_, $order_id, $prod_id ) ) {
		return misc::error( $log, $dbh, \%variable, 'Error',"Order $order_id does not contain project $prod_id" );
	} # end if
	
	my ( $rma_id ) = sql::execute( $log, $dbh, "SELECT nextval('RMA_Index_seq')" );
	
	sql::insert( $log, $dbh, 'tbl_RMA',
		'lngIndex',			$rma_id,
		'lngProjectIndex',	$prod_id,
		'lngCustomerIndex',	$session{'company_id'},
		'lngUserIndex',		$session{'user_id'},
		'OrderIndex',		$order_id,
		'chrRMAType',		$param{'rdbRMAType'},
		'strDescription',	$param{'txtDescription'},
		'ysnApprove',		undef,
		'dtmRequestDate',	'NOW()',
	);

	my %info;
	$_ = "SELECT strSalutation, strFirstName, strLastName, strEmail FROM Orders WHERE Index=?";
	@info{'Salutation','FirstName','LastName','Email'} = sql::execute( $log, $dbh, $_, $order_id );

	$info{'ProjectIndex'} = $prod_id;
	my $Project = new openprint::Project( $prod_id );
	@info{'ProjectReference'} = $Project->reference();
	$info{'OrderID'} = $order_id;
	$info{'RMAType'} = ( $param{'rdbRMAType'} eq 'C' ? 'Credit' : 'Reproduction' );
	$info{'Description'} = $param{'txtDescription'};
	$info{'RMAIndex'} = $rma_id;

	my $template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/rma_notification.html' );
	$template = ssi::variable_substitution( $template, \%info );

	my $Email = new openprint::Email();
	$Email->send(
			FROM	=> $config{'RMAEmail'},
			TO		=> $config{'RMAEmail'},
			SUBJECT => 'Online RMA Submission.',
			ATTACHMENTS	=>	[ '', encode_qp($template), 'text/html', 'quoted-printable' ],
			);

	$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/rma_confirmation.html' );
	$info{'ReplacementText'} = ssi::variable_substitution( $info{'ReplacementText'}, \%info );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$email_template = ssi::variable_substitution( $email_template, \%info );

	$Email = new openprint::Email();
	$Email->send(
		TO		=> $info{'Email'},
		FROM	=> $config{'RMAEmail'},
		SUBJECT => 'Online RMA Submission.',
		ATTACHMENTS	=>	[ '', encode_qp($email_template), 'text/html', 'quoted-printable' ],
		);

} # end sub rma

sub help_desk {
} # end sub help_desk

sub confirmation_help_desk {

	my $error = '';
	$error .= 'Missing First Name<br/>' if $param{'txtFirstName'} eq '';
	$error .= 'Missing Last Name<br/>' if $param{'txtLastName'} eq '';
	$error .= 'Missing Address<br/>' if $param{'txtAddress1'} eq '';
	$error .= 'Missing City<br/>' if $param{'txtCity'} eq '';
	$error .= 'Missing Postal Code<br/>' if $param{'txtPostalCode'} eq '';
	$error .= 'Missing Phone<br/>' if $param{'txtPhone'} eq '';
	$error .= 'Missing/Invalid E-mail<br/>' if ( ! $param{'txtEmail'} ) or ( ! Email::Valid->address( $param{'txtEmail'} ) );
	$error .= 'Missing Question or Comment<br/>' if $param{'txtQuestion-Quote'} eq '';
	if ( ! $session{'user_id'} ) {
		# Remove spaces, because some people want to put spaces between the characters, etc.
		$param{'Captcha'} =~ s/\s//g;
		require Authen::Captcha;
		my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
		if ( 1 != $Captcha->check_code( $param{'Captcha'}, $param{'MD5SUM'} ) ) {
			$error .= 'Validation Code incorrect. Please try again.';
		} # end if
	} # end if

	if ( $error ) {
		return misc::error( $log, $dbh, \%variable, 'Bad Field', $error );
	} # end if

	my ( $index ) = sql::execute( $log, $dbh, q{SELECT nextval('HelpDesk_Id_seq')} );
	if ( ! $index ) {
		return misc::error( $log, $dbh, \%variable, 'System Error', 'Unable to create helpdesk entry.' );
	} # end if

	sql::insert( $log, $dbh, 'Helpdesk',
			'Id', $index,
			'company_id', $session{'company_id'},
			'user_id',	 $session{'user_id'},
			'strCompanyName',	$param{'txtCompanyName'},
			'strTitle',			$param{'txtTitle'},
			'strFirstName',		$param{'txtFirstName'},
			'strLastName',		$param{'txtLastName'},
			'strAddress',		$param{'txtAddress1'},
			'strAddress2',		$param{'txtAddress2'},
			'strCity',			$param{'txtCity'},
			'strStateProv',		$param{'ddmStateProvince'},
			'strPostalCode',	$param{'txtPostalCode'},
			'strCountry',		$param{'ddmCountry'},
			'strPhone',			$param{'txtPhone'},
			'strExtension',		$param{'txtExtension'},
			'strEmail',			$param{'txtEmail'},
			'blbdescription',	$param{'txtQuestion-Quote'},
			'chrMethod',		$param{'rdbMethod'},
			'dtmRequestDate',	'NOW()',
			);

	my %info = ( 
			'HelpDeskIndex' => $index,
			'txtSalutation'	=>	$param{'rdbSalutation'},
			'txtFirstName'	=>	$param{'txtFirstName'},
			'txtLastName'	=>	$param{'txtLastName'},
			);

	@info{ keys %param } = @param{ keys %param };
	
	my $template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/helpdesk_notification.html' );
	$template = ssi::variable_substitution( \$template, \%info );

	my $Email = new openprint::Email();
	$Email->send(
			FROM	=> sprintf('"%s %s" <%s>', @param{'txtFirstName','txtLastName','txtEmail'} ),
			TO		=> $config{'HelpdeskEmail'},
			SUBJECT => 'Online Helpdesk Submission.',
			ATTACHMENTS =>	[ '', encode_qp($template), 'text/html', 'quoted-printable' ],
			);

	if ( 0 ) {
		# Sends an email saying we will get back to you as soon as possible.  Completely useless.
	$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/helpdesk_confirmation.html' );
	$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$email_template = ssi::variable_substitution( \$email_template, \%info );

	$Email = new openprint::Email();
	$Email->send(
			FROM	=> sprintf('"%s %s" <%s>', @param{'txtFirstName','txtLastName','txtEmail'} ),
			TO		=> sprintf('"%s %s" <%s>', @param{'txtFirstName','txtLastName','txtEmail'} ),
			FROM	=> $config{'HelpdeskEmail'},
			SUBJECT => 'Online Helpdesk Submission.',
			ATTACHMENTS =>	[ '', encode_qp($email_template), 'text/html', 'quoted-printable' ],
		);
	} # end if

} # end sub helpdesk

1;

__END__
