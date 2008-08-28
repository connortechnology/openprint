package openprint::main_account;

use Mail::Sendmail;
use MIME::QuotedPrint;
use Email::Valid;

use strict;

require sql;
require ssi;
require misc;

require openprint::user;
require openprint::usergroup;
require openprint::logs;
require openprint::MarketingCategory;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;

# called when a salesperson selects a customer to be
sub select_company {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $param{'ddmCompany'} ) {
		my $Company = new openprint::Company( $param{'ddmCompany'} );
		if ( ! $Company->id() ) {
			$variable{'error'} .= 'Unknown company selected.  Please try again.';
			return;
		} # end if
		$openprint::session{'company_id'} = $Company->id();
		openprint::logs::insertLogRecord('79',);

		if ( $Company->currency_id() ) {
			$openprint::session{'Currency_id'} = $Company->currency_id();
		} elsif ( $Company->country() eq 'US' ) {
			my @currencies = openprint::Currency::find('short'=>'USD');
			$openprint::session{'Currency_id'} = (shift @currencies)->id() if @currencies;
		} elsif ( $Company->country() eq 'CA' ) {
			my @currencies = openprint::Currency::find('short'=>'CDN');
			$openprint::session{'Currency_id'} = (shift @currencies)->id() if @currencies;
		} # end if
		foreach my $k ( keys %openprint::session ) {
			next if sets::isin( $k, [ 'Currency_id', '_session_id','user_id','company_id','user_type','Country' ] );
			delete $openprint::session{$k};
		} # end foreach
	} # end if

} # end sub select_company

sub registration {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $openprint::param{'btnFunction'} ne 'Register' ) {
		$openprint::log->debug("Not registering");
		return;
	} else {
		$openprint::log->debug("Registering");
	} # end if

	# Need to strip out characters that don't work well in filesystems - this is for FTP/Fileserver integration
	$openprint::param{'business_name'} = $openprint::param{'name'} if ! $openprint::param{'business_name'};

	# perform input field validation
	my $error = '';
	$error .= 'Missing company name.<br/>' if ! $openprint::param{'name'};
	$error .= 'Missing contact first name.<br/>' if ! $openprint::param{'firstname'};
	$error .= 'Missing contact last name.<br/>' if ! $openprint::param{'lastname'};
	$error .= 'Missing Salutation.<br/>' if ! $openprint::param{'salutation'};
	$error .= 'Missing position.<br/>' if ! $openprint::param{'title'};
	$error .= 'Missing address.<br/>' if ! $openprint::param{'address1'};
	$error .= 'Missing city.<br/>' if ! $openprint::param{'city'};
	$error .= 'Missing state/province.<br/>' if ! $openprint::param{'state'}; 
	$error .= 'Missing country.<br/>' if ! $openprint::param{'country'};
	$error .= 'Missing Postal Code.<br/>' if ! $openprint::param{'postalcode'};
	$error .= 'Postal Code too long.<br/>' if length $openprint::param{'postalcode'} > 12;
	$error .= 'Missing Phone Number.<br/>' if ! $openprint::param{'phone'};
	if ( exists $openprint::param{'howdidyouhearaboutus'} ) {
	$error .= 'Please tell us how you heard about us.<br/>' if ! $openprint::param{'howdidyouhearaboutus'};
	$error .= 'Please tell us how you heard about us.<br/>' if ( $openprint::param{'howdidyouhearaboutus'} eq 'Other' ) and ( ! $openprint::param{'howdidyouhearaboutusother'} );
	} # end if
	$error .= 'Missing E-mail Address.<br/>' if ! $openprint::param{'email'};
	$error .= 'Invalid E-mail Address.<br/>' if ! Email::Valid->address( $openprint::param{'email'} );
	$error .= 'Empty Password.<br/>' if $openprint::param{'password'} eq '';
	$error .= 'Passwords do not match.<br/>' if $openprint::param{'password'} ne $openprint::param{'verifypassword'};
	if ( $openprint::config{'UseCaptchaOnRegistration'} eq 'Y' ) {
		require Authen::Captcha;
        my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $openprint::config{'SkinPath'}.'/images/captcha');
		if ( 1 != $Captcha->check_code( $openprint::param{'Captcha'}, $openprint::param{'MD5SUM'} ) ) {
			$error .= 'Validation Code incorrect.  Please try again.';
		} # end if
	} # end if

	if ( $error ne '' ) {
		$$variable{'error'} = $error;
		return;
	} # end if

	# enforce unique email addresses.
	$openprint::param{'email'} =~ tr/[A-Z]/[a-z]/;
	if ( openprint::User::find('email'=>$openprint::param{email} ) ) {
		$$variable{'error'} = $openprint::param{'email'} .' is already a user!';
		return;
	} # end if

	my @agents = split(',', $openprint::config{'UserRegistrationEmail'} );
	my $agent = $agents[0] if @agents;
	
	# No errors, We are in go status
	my %info;
	foreach my $key ( keys %openprint::param ) {
		$info{$key} = $openprint::param{$key};
	} # end foreach

	$info{'date'} = localtime;
	$info{'CustomerServiceEmail'} = $openprint::config{'CustomerServiceEmail'};

	# CLean up the postal code
	$openprint::param{'postalcode'} =~ s/[^\w]//g;
	$openprint::param{'postalcode'} =~ tr/[a-z]/[A-Z]/;

	# if Company already exists in the DB, then just add the user to that company.	Otherwise, add the company
	my ( $cust_id ) = sql::execute( $log, $dbh, q{SELECT id FROM Companies WHERE lower(name) = lower(?) AND upper(strPostalCode) = ?}, @openprint::param{'name','postalcode'} );
	if ( ! $cust_id ) {

		my $Company = new openprint::Company();
		$Company->set( \%openprint::param );
		$Company->taxexempt1( $openprint::param{'gstnumber'} ? 'Y' : 'N' );
		$Company->taxexempt2( $openprint::param{'pstnumber'} ? 'Y' : 'N' );
		$Company->activation( $openprint::config{'NewCustomerAccountActivation'} );
		if ( sets::isin( new openprint::User($openprint::session{'user_id'})->type(), ['E','A'] ) ) {
			$Company->salesrep_id( $openprint::session{'user_id'} );
		} # end if
		if ( my $error = $Company->save() ) {
			$$variable{'error'} .= $error;
			return;
		} # end if

		# Setup default Credit
		my $customer_credit = new openprint::customer_credit( $Company->id() );
		my %params = (
				'WarnDays'	=>	1*$openprint::config{'DefaultWarnDays'},
				'DenyDays'	=>	1*$openprint::config{'DefaultDenyDays'},
				'Limit'	=>	1*$openprint::config{'DefaultCreditLimit'},
				'Hold'	=>	$openprint::config{'DefaultCreditHold'},
				'Downpayment'	=>	1*$openprint::config{'DefaultDownpayment'},
				);
		$customer_credit->set( \%params );

		my $User = new openprint::User();
		$User->set( \%openprint::param );
		$User->company_id( $Company->id() );
		$User->web_active( $openprint::config{'NewFirstUserAccountActivation'} );
		$User->ftp_active( 'Y' );
		$User->administrator( 'Y' );
		$User->type( 'C' );
		$User->change_password( 'N' );
		$User->howdidyouhearaboutus( $openprint::param{'howdidyouhearaboutus'} );
		$User->howdidyouhearaboutusother( $openprint::param{'howdidyouhearaboutusother'} );
		$$variable{'error'} .= $User->save();		
		return if $$variable{'error'};

		$info{'Company'} = $Company;
		$info{'User'} = $User;

		# Send confirmation
		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/first_user_login_app_confirmation.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		my $email_template = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );
		my %mail = (
				SMTP	=> $openprint::config{'Mail Server'},
				FROM	=> $agent,
				TO		=> sprintf('"%s %s" <%s>', $User->get( 'firstname','lastname','email' ) ),
				SUBJECT => 'New Login Application',
				);
		misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ) );

		# send notification
		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/first_user_login_app_notification.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		foreach my $to ( split(',', $openprint::config{'UserRegistrationEmail'} ) ) {
			%mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> $agent,
					TO		=> $to,
					SUBJECT => 'New Login Application',
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ) );
		} # end foreach

		if ( sets::isin( $openprint::session{'user_type'}, ['E','A'] ) ) {
			# If I'm a salesrep, then only change my company, not the user.
			$openprint::session{'company_id'} = $Company->id();
		} else { 
			if ( $openprint::config{'NewFirstUserAccountActivation'} eq 'Y' and $openprint::config{'NewCustomerAccountActivation'} eq 'Y') {
				# auto log in.
				@openprint::session{'company_id','user_id','email','user_type'} = ( $Company->id(), $User->id(), $User->email(), 'C' );
			} # end if
		} # end if
	} else {
		my $Company = new openprint::Company( $cust_id );

		my $User = new openprint::User();
		$User->set( \%openprint::param );
		$User->company_id( $Company->id() );
		$User->web_active( $openprint::config{'NewNonFirstUserAccountActivation'} );
		$User->ftp_active( 'Y' );
		$User->administrator( 'N' );
		$User->type( 'C' );
		$User->change_password( 'N' );
		$User->howdidyouhearaboutus( $openprint::param{'howdidyouhearaboutus'} );
		$User->howdidyouhearaboutusother( $openprint::param{'howdidyouhearaboutusother'} );
		$$variable{'error'} .= $User->save();		
		return if $$variable{'error'};

		$info{'Company'} = $Company;
		$info{'User'} = $User;

		my $email_template = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );

		if ( $openprint::config{'NewNonFirstUserAccountActivation'} ne 'Y') {
			# send notifications
			foreach my $Notification ( openprint::User::find( 'company_id'=>$Company->id(), 'type'=>'Y' ) ) {
				@info{'AdminSalutation','AdminFirstName','AdminLastName'} = $Notification->get('salutation','firstname','lastname');

				$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_notification_for_company_admin.html' );
				$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
				my %mail = (
						SMTP	=> $openprint::config{'Mail Server'},
						FROM	=> $agent,
						TO		=> sprintf('"%s %s" <%s>', $Notification->get('firstname','lastname','email') ),
						SUBJECT => 'New Login Application'
						);
				misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ) );
			} # end foreach
		} # end if

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_notification_for_site_admin.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		foreach my $to ( split(',', $openprint::config{'UserRegistrationEmail'} ) ) {
			my %mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> $agent,
					TO		=> $to,
					SUBJECT => 'New Login Application'
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ) );
		} # end foreach

		if ( $openprint::config{'NewNonFirstUserAccountActivation'} ne 'Y') {
			# Send confirmation
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_confirmation.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
			my %mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> $agent,
					TO		=> sprintf('"%s %s" <%s>', $User->get('firstname','lastname','email') ),
					SUBJECT => 'New Login Application'
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ) );
		} # end if

		if ( $openprint::param{'rdbReasonForPurchase'} eq 'Reseller' ) {
			if ( $Company->reseller() ne 'Y' ) {
				$$variable{'Redirect'} = '/main/account/reseller_application.html';
			} # end if
		} # end if

		if ( sets::isin( $openprint::session{'user_type'}, ['E','A'] ) ) {
			# If I'm a salesrep, then only change my company, not the user.
			$openprint::session{'company_id'} = $Company->id();
		} else { 
			if ( $openprint::config{'NewNonFirstUserAccountActivation'} eq 'Y' ) {
				# auto log in.
				if ( $Company->activation() eq 'Y' ) {
					@openprint::session{'company_id','user_id','email','user_type'} = ( $cust_id, $User->id(), $User->email(), 'C' );
				} # end if
			} # end if
		} # end if

	} # end if

} # end sub registration

sub login_password {
	my ( $r, $log, $dbh, $variable ) = @_;

	$_ = $openprint::config{'customerlogin'};
	if ($ENV{'HTTP_REFERER'} =~ /$_/) {
		$$variable{'message'} = "Your account has been activated.	While it is not required, it is recommended you change your password now.";
	} else {
		$$variable{'message'} = "Please enter the required information to change your password.";
	} # end if
} # login password

sub company_profile {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $Company = $variable{'Company'} = new openprint::Company( $openprint::session{'company_id'} );

	if ( $param{'btnFunction'} eq 'Save' ) {
		my $error = '';
		$error .= "Company Name cannot be empty.<br/>" if ! $param{'companyname'};
		if ( exists $param{'StartYear'} ) {
			$param{'StartYear'} =~ s/\D//g;
			$param{'StartMonth'} =~ s/\D//g;
			$param{'StartMonth'} = 1 if ! $param{'StartMonth'};
			if ( $param{'StartYear'} and ! Date::Calc::check_date( @param{'StartYear','StartMonth'}, 1 ) ) {
				$error .= 'Invalid start date.<br/>';
			} # end if
			if ( $error ne '' ) {
				$$variable{'error'} = $error;
				return;
			} # end if
	
			if ( $param{'StartYear'} ) {
			$param{'established'} = sprintf('%.4d-%.2d-%.2d',@param{'StartYear','StartMonth'}, 1 );
			} else {
			$param{'established'} = undef;
			} # end if
		} # end if
		$param{'name'} = $param{'companyname'};
		$Company->set( \%param );
		$variable{'error'} .= $Company->save( );
		$variable{'error'} .= $Company->save_tradereferences( \%param );

	} # end if

	$variable{'Company'} = $Company;
} # end sub company_profile

sub user_profile {
	my ( $r, $log, $dbh, $variable ) = @_;

# We assume that we are authorized to be here now.

	my $User = new openprint::User( $openprint::session{'user_id'} );
	my $Me = new openprint::User( $openprint::session{'user_id'} );

	if ( ( $Me->administrator() eq 'Y' ) or ( new openprint::Company( $openprint::session{'company_id'} )->salesrep_id() == $Me->id() ) ) {
$openprint::log->debug('admin');

		# IF it's empty, then we are adding a new user! Otherwise editing one
		if ( exists $openprint::param{'ddmUser'} ) {
		$User = new openprint::User( $openprint::param{'ddmUser'} );
		} elsif ( $openprint::session{'company_id'} != $Me->company_id() ) {
			my @Users = openprint::User::find('company_id'=>$openprint::session{'company_id'} );
			if ( @Users == 1 ) {
				$User = $Users[0];
			} # end if
		} # end if
		if ( $openprint::param{'ddmUser'} ) {
# Enforce that we can only edit users from our company
			if ( $User->company_id() != $openprint::session{'company_id'} ) {
				$User = new openprint::User( $openprint::session{'user_id'} );
			} # end if
		} # end if

		if ( $openprint::param{'btnFunction'} eq '<<' ) {
			$User = $User->Prev( 'company_id'=>$openprint::session{'company_id'} );
		} elsif ( $openprint::param{'btnFunction'} eq '>>' ) {
			$User = $User->Next( 'company_id'=>$openprint::session{'company_id'} );
		} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
			$User->delete();
			$User = $User->Next( 'company_id'=>$openprint::session{'company_id'} );
		} # end if
	} # end if Company Admin

# options available to non-company administrators
	if ( $openprint::param{'btnFunction'} eq 'Save' ) {

		my $error = "";
		$error .= "Password fields do not match.<br/>" if $openprint::param{'password'} ne $openprint::param{'verifypassword'};
		$error .= "First Name cannot be blank.<br/>" if ! $openprint::param{'firstname'};
		$error .= "Last Name cannot be blank.<br/>" if ! $openprint::param{'lastname'};
		$error .= "Salutation cannot be blank.<br/>" if ! $openprint::param{'salutation'};
		$error .= "Phone cannot be blank.<br/>" if ! $openprint::param{'phone'};
		$error .= "Email Cannot be blank.<br/>" if ! $openprint::param{'email'};
		if ( $error ne '' ) {
			return misc::error( $log, $dbh, $variable, 'Bad Field', $error );
		} # end if

			foreach my $U ( openprint::User::find('email'=>lc $openprint::param{'email'}) ) {
				if ( $U->id() != $User->id() ) {
					return misc::error( $log, $dbh, $variable, 'User already exists.', $openprint::param{'email'} . " is already a user." );
				} # end if
			} # end foreach
		if ( ! $openprint::param{'ddmUser'} ) { # add
			$User->company_id( $openprint::session{company_id} ) if ! $User->company_id();
		} # end if
		$$variable{'error'} .= $User->save( \%openprint::param );
	} # end if

	$$variable{'Me'} = $Me;
	if ( $User->company_id() != $openprint::session{company_id} ) {
		$User = new openprint::User();
	} # end if
	$$variable{'User'} = $User;
} # end sub user_edit

sub change_password {
}
sub change_password_confirmation {
	my ( $r, $log, $dbh, $variable ) = @_;

		if ( $openprint::param{'txtNewPassword'} ne $openprint::param{'txtConfirmPassword'} ) {
			$$variable{'error'} = 'The new password, and the verification passwords you entered do not match.<br/>';
			$$variable{'Redirect'} = '/main/account/change_password.html';
			return;
		} # end if

		if ( $openprint::param{'txtNewPassword'} eq '' ) {
			$$variable{'error'} = 'The new password you entered was blank.This is too insecure, and will not be allowed.<br/>';
			$$variable{'Redirect'} = '/main/account/change_password.html';
			return;
		} # end if

		my $User = new openprint::User( $openprint::session{'user_id'} );

		if ( $openprint::param{'txtNewPassword'} eq $User->password() ) {
			$$variable{'error'} = 'The new password you entered was the same as your current password. Please try again.</br>';
			$$variable{'Redirect'} = '/main/account/change_password.html';
			return;
		} # end if
		
		if ( $User->password() eq $openprint::param{'txtOldPassword'} ) {
			$User->password( $openprint::param{'txtNewPassword'} );
			$User->changepassword( 'N' );
			$User->save();
		} else {
			$$variable{'error'} = 'You entered the wrong old password.<br/>';
			$$variable{'Redirect'} = '/main/account/change_password.html';
			return;
		} # end if
} # sub change_password

sub login {
	if ( $openprint::param{'btnFunction'} eq 'Forgotten Password' ) {
		if ( ! $openprint::param{'email'} ) {
			$openprint::variable{'error'} = 'Please enter the email address of the account to retrieve.';
			return;
		} # end if

		$openprint::param{'email'} =~ tr/[A-Z]/[a-z]/;
		my @Users = openprint::User::find('email'=>$openprint::param{'email'} );
		if ( ! @Users ) {
			$variable{'error'} = 'The account you entered does not exist.';
			return;
		} # end if

		if ( my $email_template = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' ) ) {
			my %info = (
					'User' =>$Users[0],	
					);

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/forgotten_password.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
			$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
			my @body = ('', $_, 'text/html', 'quoted-printable');

			my %mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM 	=> $openprint::config{'AdministratorEmail'},
					TO		=> sprintf('"%s %s" <%s>', $Users[0]->get('firstname','lastname','email') ),
					SUBJECT	=> 'Forgotten Password',
					);
			misc::send_email_with_attachment( $log, \%mail, @body );
			$variable{'information'} = 'Your password has been mailed to you.';
		} else {
			$variable{'error'} = 'We were unable to email your password to you.	Please contact support.';
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Login' ) {
		openprint::login::verify_login( $r, $log, $dbh, $session{_session_id}, \%variable, 'C' );
	} # end if
} # end sub login

sub logout {
	openprint::login::logout();
} # sub logout

sub reseller_application {

	my $Company = $variable{'Company'} = new openprint::Company( $session{'company_id'} );

	if ( $param{'btnFunction'} eq 'Apply' ) {

		my $error = '';
# first, check all fields that are required

		$error .= "Missing legal form<br/>" if ! $param{'business_form'};
		$error .= "Missing legal business name<br/>" if ! $param{'business_name'};
		$error .= "Missing legal business type<br/>" if ! $param{'business_type'};
		$error .= "Missing President/Owner<br/>" if ! $param{'president_owner'};
#$error .= "Bad Federal Tax number<br>" if ! $param{'gst_number'};
#$error .= "Bad State Tax number<br>" if ! $param{'pst_number'};

		foreach my $tr ( 1 .. 3 ) {
			$error .= "Missing company name for trade reference $tr<br/>" if ! $param{'tradereference'.$tr.'_companyname'};
			$error .= "Missing contact for trade reference $tr<br/>" if ! $param{'tradereference'.$tr.'_contact'};
			$error .= "Missing phone number for trade reference $tr<br/>" if ! $param{'tradereference'.$tr.'_phone'};
		} # end foreach

# process error conditions
		if ( $error ) {
			$variable{'error'} = $error;
			return;
		} # end if

		$param{'StartYear'} =~ s/\D//g;
		$param{'StartMonth'} =~ s/\D//g;
		$param{'StartMonth'} = 1 if ! $param{'StartMonth'};
		$param{'StartMonth'} = 12 if $param{'StartMonth'} > 12;

		if ( $param{'StartYear'} ) {
			$param{'established'} = sprintf( '%.4d-%.2d-%.2d', @param{'StartYear','StartMonth'}, 1 );
		} # end if 
		$variable{'error'} .= $Company->save( \%param );
		$variable{'error'} .= $Company->save_tradereferences( \%param );
		if ( ! $variable{'error'} ) {
			my %info;
			$info{'Company'} = $Company;
			$info{'User'} = new openprint::User( $session{'user_id'} );
			my $email_template = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/reseller_application_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

			my %mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> $openprint::config{'ResellerApplicationEmail'},
					TO		=> $openprint::config{'ResellerApplicationEmail'},
					SUBJECT	=> 'New Reseller Application',
					);

			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(
							ssi::variable_substitution( \$email_template, \%info )
							), 'text/html', 'quoted-printable' ) );

		} # end if ! error
	} # end if Apply

} # sub reseller_application

sub credit_application {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $Company = $$variable{'Company'} = new openprint::Company( $session{'company_id'} );

	if ( $param{'btnFunction'} eq 'Apply' ) {
		my $error = '';
		$error .= 'Missing legal business name<br>' if ! $param{'business_name'};
		$error .= 'Missing legal form<br/>' if ! $param{'business_form'};
		$error .= 'Missing president/owner<br/>' if ! $param{'president_owner'};
		$error .= 'Missing year established<br/>' if ! $param{'StartYear'};
		$error .= 'Missing number of employees<br/>' if ! $param{'employees'};
		$error .= 'Missing annual sales<br/>' if ! $param{'annual_sales'};
		$error .= 'Missing bank name<br/>' if ! $param{'bank_name'};
		$error .= 'Missing bank branch<br/>' if ! $param{'bank_branch'};
		$error .= 'Missing bank account number<br/>' if ! $param{'bank_account'};
		$error .= 'Missing bank account manager<br/>' if ! $param{'bank_manager'};
		$error .= 'Bad bank phone number entered.<br/>' if ! $param{'bank_phone'};
		foreach my $tr ( 1 .. 3 ) {
			$error .= "Missing company name for trade reference $tr<br/>" if ! $param{'tradereference'.$tr.'_companyname'};
			$error .= "Missing contact for trade reference $tr<br/>" if ! $param{'tradereference'.$tr.'_contact'};
			$error .= "Missing phone number for trade reference $tr<br/>" if ! $param{'tradereference'.$tr.'_phone'};
		} # end foreach
		$error .= 'Missing accounts payable contact<br/>' if ! $param{'AccountsPayableContact'};
		$error .= 'Missing signature<br/>' if ! $param{'Signature'};

# process error conditions
		if ( $error ne '' ) {
			$$variable{'error'} = $error;
			return;
		} # end if

		$param{'StartYear'} =~ s/\D//g;
		$param{'StartMonth'} =~ s/\D//g;
		$param{'StartMonth'} = 1 if ! $param{'StartMonth'};
		$param{'StartMonth'} = 12 if $param{'StartMonth'} > 12;

		if ( $param{'StartYear'} ) {
			$param{'established'} = sprintf( '%.4d-%.2d-%.2d', @param{'StartYear','StartMonth'}, 1 );
		} # end if 
		$variable{'error'} .= $Company->save( \%param );
		$variable{'error'} .= $Company->save_tradereferences( \%param );

		my $creditlimit = $param{'DesiredCreditLimit'};
		$creditlimit =~ s/[^\d\.]//g;
		sql::insert( $log, $dbh, 'CreditApplications',
				'User_Id',	 $session{'user_id'},
				'company_id', $session{'company_id'},
				( defined $param{'Signature'} ? ( 'strSignature',	 $param{'Signature'} ) : () ),
				( defined $param{'FinancialStatementAvailable'} ? ( 'ysnFinancialStatementAvailable', $param{'FinancialStatementAvailable'} ) : () ),
				( defined $param{'FirstOrderValue'} ? ( 'strFirstOrderValue', $param{'FirstOrderValue'} ) : () ),
				( defined $param{'AnnualPurchases'} ? ( 'strAnnualPurchases', $param{'AnnualPurchases'} ) : () ),
				( $creditlimit ne '' ? ( 'dblCreditLimit',	$creditlimit ) : () ),
				'lngTerms',						$param{'DesiredTerms'},
				'strAccountsPayableContact',	$param{'AccountsPayableContact'},
				'strStatus',		'Non-Reviewed',
				'dtmCreationDate',	'NOW()',
				);

# Now send email notifications
		my %info;
		$info{'Company'} = $Company;
		$info{'User'} = new openprint::User( $session{user_id} );

		$_ = 'SELECT MAX(Id) FROM CreditApplications WHERE user_id=? AND company_id=?';
		($info{'CreditAppIndex'}) = sql::execute( $log, $dbh, $_, @session{'user_id','company_id'} );

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/credit_application_notification.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		my $email_template = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );
		my $template = ssi::variable_substitution( \$email_template, \%info );

		my %mail = (
				SMTP	=> $openprint::config{'Mail Server'},
				FROM	=> $openprint::config{'CreditApplicationEmail'},
				TO		=> $openprint::config{'CreditApplicationEmail'},
				SUBJECT => "New Credit Application"
				);

		misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($template), 'text/html', 'quoted-printable' ) );
	} # end if Apply

} # sub credit_application


1;
__END__
