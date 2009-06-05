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
	my ($r, $log, $dbh, $variable) = @_;

	my $order_id = $openprint::param{'order_id'};
	my $prod_id = $openprint::param{'project_id'};
	my ( $check_order_id, $check_cust_id );

	if ( $openprint::param{'docket'} ) {
		$_ = 'SELECT Index, CompanyIndex FROM Orders WHERE lngDocketNumber=?';
		( $check_order_id, $check_cust_id ) = sql::execute( $log, $dbh, $_, $openprint::param{'docket'} );
	} elsif ( $openprint::param{'order_id'} ) {
		$_ = 'SELECT Index, CompanyIndex FROM Orders WHERE Index=?';
		( $check_order_id, $check_cust_id ) = sql::execute( $log, $dbh, $_, $order_id );
	} # end if

	if ( $check_order_id eq '' ) {
		return misc::error( $log, $dbh, $variable, 'Error','Invalid Order ID' );
	} elsif ( $check_cust_id != $openprint::session{'company_id'} ) {
		return misc::error( $log, $dbh, $variable, 'Error','You are not the owner of that order.' );
	} # end if

	$_ = 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?';
	if ( ! sql::execute( $log, $dbh, $_, $order_id, $prod_id ) ) {
		return misc::error( $log, $dbh, $variable, 'Error',"Order $order_id does not contain project $prod_id" );
	} # end if
	
	my ( $rma_id ) = sql::execute( $log, $dbh, "SELECT nextval('RMA_Index_seq')" );
	
	sql::insert( $log, $dbh, 'tbl_RMA',
		'lngIndex',			$rma_id,
		'lngProjectIndex',	$prod_id,
		'lngCustomerIndex',	$openprint::session{'company_id'},
		'lngUserIndex',		$openprint::session{'user_id'},
		'OrderIndex',		$order_id,
		'chrRMAType',		$openprint::param{'rdbRMAType'},
		'strDescription',	$openprint::param{'txtDescription'},
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
    $info{'RMAType'} = ( $openprint::param{'rdbRMAType'} eq 'C' ? 'Credit' : 'Reproduction' );
    $info{'Description'} = $openprint::param{'txtDescription'};
    $info{'RMAIndex'} = $rma_id;
	$info{'SecureSiteURL'} = $r->dir_config('SecureSiteURL');
	$info{'siteURL'} = $r->dir_config('siteURL');

	my $template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/rma_notification.html' );
	$template = ssi::variable_substitution( $template, \%info );

	my %mail = (
			SMTP	=> $config{'Mail Server'},
			FROM	=> $config{'RMAEmail'},
			TO		=> $config{'RMAEmail'},
			SUBJECT => 'Online RMA Submission.'
			);
	misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($template), 'text/html', 'quoted-printable' ) );

	$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/rma_confirmation.html' );
	$info{'ReplacementText'} = ssi::variable_substitution( $info{'ReplacementText'}, \%info );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
    $email_template = ssi::variable_substitution( $email_template, \%info );

	my %mail = (
		SMTP	=> $config{'Mail Server'},
		TO		=> $info{'Email'},
		FROM	=> $config{'RMAEmail'},
		SUBJECT => 'Online RMA Submission.'
		);
	misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );

} # end sub rma

sub help_desk {
} # end sub help_desk

sub confirmation_help_desk {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $error = '';
	$error .= 'Missing First Name<br/>' if $openprint::param{'txtFirstName'} eq '';
	$error .= 'Missing Last Name<br/>' if $openprint::param{'txtLastName'} eq '';
	$error .= 'Missing Address<br/>' if $openprint::param{'txtAddress1'} eq '';
	$error .= 'Missing City<br/>' if $openprint::param{'txtCity'} eq '';
	$error .= 'Missing Postal Code<br/>' if $openprint::param{'txtPostalCode'} eq '';
	$error .= 'Missing Phone<br/>' if $openprint::param{'txtPhone'} eq '';
	$error .= 'Missing/Invalid E-mail<br/>' if ( ! $openprint::param{'txtEmail'} ) or ( ! Email::Valid->address( $openprint::param{'txtEmail'} ) );
	$error .= 'Missing Question or Comment<br/>' if $openprint::param{'txtQuestion-Quote'} eq '';
	if ( $config{'UseCaptchaOnRegistration'} eq 'Y' ) {
		require Authen::Captcha;
		my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
		if ( 1 != $Captcha->check_code( $openprint::param{'Captcha'}, $openprint::param{'MD5SUM'} ) ) {
			$error .= 'Validation Code incorrect.  Please try again.';
		} # end if
	} # end if

	if ( $error ) {
		return misc::error( $log, $dbh, $variable, 'Bad Field', $error );
	} # end if

    my ( $index ) = sql::execute( $log, $dbh, q{SELECT nextval('HelpDesk_Id_seq')} );
    if ( ! $index ) {
        return misc::error( $log, $dbh, $variable, 'System Error', 'Unable to create helpdesk entry.' );
    } # end if

	sql::insert( $log, $dbh, 'Helpdesk',
			'Id', $index,
			'company_id', $openprint::session{'company_id'},
			'user_id',     $openprint::session{'user_id'},
			'strCompanyName',	$openprint::param{'txtCompanyName'},
			'strTitle',			$openprint::param{'txtTitle'},
			'strFirstName',		$openprint::param{'txtFirstName'},
			'strLastName',		$openprint::param{'txtLastName'},
			'strAddress',		$openprint::param{'txtAddress1'},
			'strAddress2',		$openprint::param{'txtAddress2'},
			'strCity',			$openprint::param{'txtCity'},
			'strStateProv',		$openprint::param{'ddmStateProvince'},
			'strPostalCode',	$openprint::param{'txtPostalCode'},
			'strCountry',		$openprint::param{'ddmCountry'},
			'strPhone',			$openprint::param{'txtPhone'},
			'strExtension',		$openprint::param{'txtExtension'},
			'strEmail',			$openprint::param{'txtEmail'},
			'blbdescription',	$openprint::param{'txtQuestion-Quote'},
			'chrMethod',		$openprint::param{'rdbMethod'},
			'dtmRequestDate',	'NOW()',
			);

	my %info = ( 
			'HelpDeskIndex' => $index,
			'txtSalutation'	=>	$openprint::param{'rdbSalutation'},
			'txtFirstName'	=>	$openprint::param{'txtFirstName'},
			'txtLastName'	=>	$openprint::param{'txtLastName'},
			);

	foreach my $key ( keys %openprint::param ) {
		$info{$key} = $openprint::param{$key};
	} # end foreach

    $info{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
    $info{'siteURL'} = $r->dir_config('ExternalSiteURL');

	
	my $template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/helpdesk_notification.html' );
	$template = ssi::variable_substitution( \$template, \%info );

	my %mail = (
			SMTP	=> $config{'Mail Server'},
			FROM	=> sprintf('"%s %s" <%s>', @openprint::param{'txtFirstName','txtLastName','txtEmail'} ),
			TO		=> $config{'HelpdeskEmail'},
			SUBJECT => 'Online Helpdesk Submission.'
			);
	misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($template), 'text/html', 'quoted-printable' ) );

	$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/helpdesk_confirmation.html' );
	$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
    $email_template = ssi::variable_substitution( \$email_template, \%info );

	my %mail = (
		SMTP	=> $config{'Mail Server'},
		TO		=> sprintf('"%s %s" <%s>', @openprint::param{'txtFirstName','txtLastName','txtEmail'} ),
		FROM	=> $config{'HelpdeskEmail'},
		SUBJECT => 'Online Helpdesk Submission.'
		);
	misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );

} # end sub helpdesk

1;

__END__
