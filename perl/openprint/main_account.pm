package openprint::main_account;

use Mail::Sendmail;
use MIME::QuotedPrint;
use Email::Valid;

use strict;

require sql;
require ssi;
require misc;
require Encode;
require email;
require openprint::user;
require openprint::usergroup;
require openprint::logs;
require openprint::MarketingCategory;
require openprint::Credit_Application;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;

# called when a salesperson selects a customer to be
sub select_company {
	# everything is done in openprint::init_session
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
	$openprint::param{'business_name'} = $openprint::param{'company_name'} if ! $openprint::param{'business_name'};

	# perform input field validation
	my $error = '';
	$error .= 'Missing company name.<br/>' if ! $openprint::param{'company_name'};
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
	if ( my $reason = openprint::login::check_password( $openprint::param{'password'} ) ) {
		$error .= "Password not good enough.  $reason<br/>";
	} # end if
	if ( ( ! $session{'user_id'} ) and ( $openprint::config{'UseCaptchaOnRegistration'} eq 'Y' ) ) {
		# Remove spaces, because some people want to put spaces between the characters, etc.
		$openprint::param{'Captcha'} =~ s/\s//g;
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
	if ( openprint::User::find('email'=>$openprint::param{email},'deleted'=>1 ) ) {
		$$variable{'error'} = $openprint::param{'email'} .' is already a user, but has been deleted. Please contact us to re-activate your account.';
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
	my ( $cust_id ) = sql::execute( $log, $dbh, q{SELECT Index FROM Company WHERE lower(strName) = lower(?) AND upper(strPostalCode) = ? AND (deleted=false OR deleted IS NULL)}, @openprint::param{'company_name','postalcode'} );
	if ( ! $cust_id ) {
		$openprint::param{'name'} = $openprint::param{'company_name'};

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

		my @Suppliers = openprint::Company->find('offers_credit'=>1,'order'=>'index');
		foreach my $Supplier ( @Suppliers ) {
			# Setup default Credit
			my $Credit = new openprint::Company_Credit();
			$Credit->save({
					'company_id'	=>	$Company->id(),
					'supplier_id'	=>	$Supplier->id(),
					'warndays'		=>	$openprint::config{'DefaultWarnDays'},
					'denydays'		=>	$openprint::config{'DefaultDenyDays'},
					'limit'			=>	$openprint::config{'DefaultCreditLimit'},
					'hold'			=>	$openprint::config{'DefaultCreditHold'},
					'downpayment'	=>	$openprint::config{'DefaultDownpayment'},
					'cod'			=>	$openprint::config{'DefaultCOD'},
					});
		} # end foreach Supplier

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
		$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
		my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
		my %mail = (
				SMTP	=> $openprint::config{'Mail Server'},
				FROM	=> $agent,
				TO		=> sprintf('"%s %s" <%s>', $User->get( 'firstname','lastname','email' ) ),
				SUBJECT => 'New Login Application',
				);
		misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info )), 'text/html', 'quoted-printable' ) );

		# send notification
		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/first_user_login_app_notification.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
		foreach my $to ( split(',', $openprint::config{'UserRegistrationEmail'} ) ) {
			%mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> $agent,
					TO		=> $to,
					SUBJECT => 'New Login Application',
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info )), 'text/html', 'quoted-printable' ) );
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

		my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );

		if ( $openprint::config{'NewNonFirstUserAccountActivation'} ne 'Y') {
			# send notifications
			foreach my $Notification ( openprint::User::find( 'company_id'=>$Company->id(), 'type'=>'Y' ) ) {
				@info{'AdminSalutation','AdminFirstName','AdminLastName'} = $Notification->get('salutation','firstname','lastname');

				$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_notification_for_company_admin.html' );
				$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
				my %mail = (
						SMTP	=> $openprint::config{'Mail Server'},
						FROM	=> $agent,
						TO		=> sprintf('"%s %s" <%s>', $Notification->get('firstname','lastname','email') ),
						SUBJECT => 'New Login Application'
						);
				misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info )), 'text/html', 'quoted-printable' ) );
			} # end foreach
		} # end if

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_notification_for_site_admin.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
		foreach my $to ( split(',', $openprint::config{'UserRegistrationEmail'} ) ) {
			my %mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> $agent,
					TO		=> $to,
					SUBJECT => 'New Login Application'
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info )), 'text/html', 'quoted-printable' ) );
		} # end foreach

		if ( $openprint::config{'NewNonFirstUserAccountActivation'} ne 'Y') {
			# Send confirmation
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_confirmation.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
			my %mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> $agent,
					TO		=> sprintf('"%s %s" <%s>', $User->get('firstname','lastname','email') ),
					SUBJECT => 'New Login Application'
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info )), 'text/html', 'quoted-printable' ) );
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

	my $Company = $variable{'Company'} = new openprint::Company( $param{'company_id'} ? $param{'company_id'} : $openprint::session{'company_id'} );

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
	my $Me = new openprint::User( $session{'user_id'} );
    my $User;
# IF it's empty, then we are adding a new user! Otherwise editing one
    if ( exists $param{'ddmUser'} ) {
        $User = new openprint::User($param{ddmUser});
    } elsif ( $session{company_id} == $$Me{company_id} ) {
        $User = $Me;
	} else {
		$User = new openprint::User();
    } # end if

	if ( $User->can_edit() ) {
		if ( $param{'btnFunction'} eq '<<' ) {
			$User = $User->Prev( 'company_id'=>$session{'company_id'} );
		} elsif ( $param{'btnFunction'} eq '>>' ) {
			$User = $User->Next( 'company_id'=>$session{'company_id'} );
		} elsif ( $param{'btnFunction'} eq 'Delete' ) {
			$User->delete();
			$User = $User->Next( 'company_id'=>$session{'company_id'} );
		} elsif ( $param{'btnFunction'} eq 'Save' ) {

			my $error = "";
			if ( $param{'password'} ne $User->password() ) {
				if ( ! $param{'verifypassword'} ) {
					$variable{'warning'} .= 'Verify password left blank, password not changed.<br/>';
					delete $param{'password'};
				} else {
					$error .= "Password fields do not match.<br/>" if $param{'password'} ne $param{'verifypassword'};
				} # end if
			} # end if
			$error .= "First Name cannot be blank.<br/>" if ! $param{'firstname'};
			$error .= "Last Name cannot be blank.<br/>" if ! $param{'lastname'};
			$error .= "Email Cannot be blank.<br/>" if ! $param{'email'};
			if ( $error ne '' ) {
				return misc::error( $log, $dbh, \%variable, 'Bad Field', $error );
			} # end if

			foreach my $U ( openprint::User::find('email'=>lc $param{'email'}) ) {
				if ( $U->id() != $User->id() ) {
					return misc::error( $log, $dbh, \%variable, 'User already exists.', $param{'email'} . " is already a user." );
				} # end if
			} # end foreach
			if ( ! $param{'ddmUser'} ) { # add
				$User->company_id( $session{company_id} ) if ! $User->company_id();
			} # end if
			my $oldpassword = $User->password();
			if ( $param{'password'} and ( $oldpassword ne $param{'password'} ) ) {
# Are changing passwords
				if ( my $reason = openprint::login::check_password( $param{'password'} ) ) {
					return misc::error( $log, $dbh, \%variable, 'Bad Field', "The new password you entered was not good enough: $reason.<br/>" );
				} # end if
				$param{'change_password'} = 'N' if $param{'password'};
				$param{'password_changed_on'} = 'NOW()';
			} # end if

			$variable{'error'} .= $User->save( \%param );
			if ( ! $variable{error} ) {
				if ( $config{mail_db_name} and $param{'email'} =~ /(.*)\@point\-one\.com/ ) {
					if ( $param{'VacationState'} ) {
						email::start_vacation( @param{'email','VacationSubject','VacationMessage'} );
					} else {
						email::stop_vacation( $param{'email'} );
					} # end if
					if ( $param{'EmailPassword'} ) {
						if ( ! $param{'VerifyEmailPassword'} ) {
							$variable{'warning'} .= 'Verify Email password left blank, password not changed.<br/>';
						} elsif ( $param{'EmailPassword'} eq $param{'VerifyEmailPassword'} ) {
							email::set_password( @param{'email','EmailPassword'} );
						} else {
							$variable{'error'} .= 'Email Password fields do not match.<br/>';
						} # end if
					} # end if
					my @aliases = ();
					foreach my $alias ( split "\r\n", $param{'aliases'} ) {
						next if ! $alias;
						push @aliases, $alias;
					} # end foreach
					push @aliases, $User->email() if ! @aliases;
					email::aliases( $User->email(), @aliases );
				} # end if
			} # end if

			if ( $param{'ddmUser'} and ( $param{'ddmUser'} != $session{'user_id'} ) and ( $oldpassword ne $User->password() ) ) {
# Send password change email
				if ( my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' ) ) {
					my %info = (
							'User' =>$User,
							);

					$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/changed_password.html' );
					$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
					$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ) );
					my @body = ('', $_, 'text/html', 'quoted-printable');

					my %mail = (
							SMTP    => $config{'Mail Server'},
							FROM    => $config{'AdministratorEmail'},
							TO      => sprintf('"%s %s" <%s>', $User->get('firstname','lastname','email') ),
							SUBJECT => 'Password Changed',
							);
					misc::send_email_with_attachment( $log, \%mail, @body );
					$variable{'information'} = 'The user has been notified by email of the password change.';
				} else {
					$variable{'error'} = 'We were unable to email the new password. Please contact support.';
				} # end if
			} # end if to send changed password notification

		} # end if
	} # end if can_edit

	$variable{'Me'} = $Me;
	if ( $User->company_id() != $session{'company_id'} ) {
		$User = new openprint::User();
	} # end if
	$variable{'User'} = $User;
    if ( $config{mail_db_name} and $User->email() =~ /(.*)\@point\-one\.com/ ) {
        @variable{'VacationState','VacationSubject','VacationMessage'} = email::get_vacation( $User->email() );
        @{$variable{'Aliases'}} = email::aliases( $User->email() );
    } else {
        @{$variable{'Aliases'}} = ();
    } # end if

} # end sub user_profile

sub change_password {
}
sub change_password_confirmation {
	openprint::login::change_password();
} # sub change_password

sub login {
	if ( $openprint::param{'btnFunction'} eq 'Forgotten Password' ) {
		openprint::login::forgotten_password();
	} elsif ( $openprint::param{'btnFunction'} eq 'Login' ) {
		openprint::login::verify_login( $r, $log, $dbh, $session{_session_id}, \%variable, 'C' );
	} # end if
} # end sub login

sub logout {
	openprint::logs::insertLogRecord('3',);
	delete @openprint::session{'user_id','company_id','email','user_type','OrderID','project_id','quote_id','Pricelist_id','Destination'};
	#openprint::order::delete_unfinished_orders( $openprint::log, $openprint::dbh, $openprint::session{_session_id} );
	#sql::insert( $log, $dbh, 'log', 'action_type', '3', 'user_id', "$user_id", 'date_time', 'NOW()', 'ip_address', $ENV{REMOTE_ADDR},);
	
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
			my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/reseller_application_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );

			my %mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> $openprint::config{'ResellerApplicationEmail'},
					TO		=> $openprint::config{'ResellerApplicationEmail'},
					SUBJECT	=> 'New Reseller Application',
					);

			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(
							ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info )
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

		my $App = new openprint::Credit_Application();
		$variable{'error'} .= $App->save({
				'desired_limit'			=>	$param{'DesiredCreditLimit'},
				'user_id'				=>	$session{'user_id'},
				'company_id'			=>	$session{'company_id'},
				'signature'				=>	$param{'Signature'},
				'financialstatementavailable'	=>	$param{'FinancialStatementAvailable'},
				'firstordervalue'		=>	$param{'FirstOrderValue'},
				'annualpurchases'		=>	$param{'AnnualPurchases'},
				'desired_limit'			=>	$param{'DesiredCreditLimit'},
				'desired_terms'			=>	$param{'DesiredTerms'},
				'accountspayablecontact'	=>	$param{'AccountsPayableContact'},
				'status'				=>	'Non-Reviewed',
				});

		if ( ! $variable{'error'} ) {
# Now send email notifications
			my %info;
			$info{'Company'} = $Company;
			$info{'User'} = new openprint::User( $session{user_id} );
			$info{'CreditAppIndex'} = $App->id();

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/credit_application_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
			my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
			my $template = ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info );

			$_ = ( new openprint::Email() )->send(
					FROM	=>	$openprint::config{'CreditApplicationEmail'},
					TO		=>	$openprint::config{'CreditApplicationEmail'},
					BCC		=>	'iconnor@point-one.com',
					SUBJECT =>	'New Credit Application',
					ATTACHMENTS	=>	[ '', MIME::QuotedPrint::encode_qp(Encode::encode('utf-8', $template)), 'text/html', 'quoted-printable' ],
					);
			$log->error($_) if $_;
		} # end if Apply
	} # end if error

} # sub credit_application


1;
__END__
