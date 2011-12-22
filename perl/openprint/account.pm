package openprint::account;

use Mail::Sendmail;
use MIME::QuotedPrint;
use Email::Valid;

use strict;

require sql;
require ssi;
require misc;

require openprint::usergroup;
require openprint::logs;
require openprint::MarketingCategory;
require openprint::User;
require openprint::User_Profile_Field;
require openprint::Company;
require openprint::Company_Profile_Field;
require openprint::Photo_Album;
require openprint::Video_Album;
require openprint::Event;
require openprint::User_Relationship;
require openprint::Wall;

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
	# Taken care of in openprint.pm
} # end sub select_company

sub registration {
	if ( $param{'btnFunction'} ne 'Register' ) {
		$log->debug("Not registering");
		return;
	} else {
		$log->debug("Registering");
	} # end if

	$param{'business_name'} = $param{'company_name'} if ! $param{'business_name'};

	# perform input field validation
	my $error = '';
	my %required_fields = map{$_,$_} misc::trim( split(',', $config{'RegistrationRequiredFields'} ) );
	$error .= 'Missing company name.<br/>' if $required_fields{'company_name'} and ! $param{'company_name'};
	$error .= 'Missing contact first name.<br/>' if $required_fields{'firstname'} and ! $param{'firstname'};
	$error .= 'Missing contact last name.<br/>' if $required_fields{'lastname'} and ! $param{'lastname'};
	$error .= 'Missing Salutation.<br/>' if $required_fields{'salutation'} and ! $param{'salutation'};
	$error .= 'Missing position.<br/>' if $required_fields{'title'} and ! $param{'title'};
	$error .= 'Missing address.<br/>' if $required_fields{'address1'} and ! $param{'address1'};
	$error .= 'Missing city.<br/>' if $required_fields{'city'} and ! $param{'city'};
	$error .= 'Missing state/province.<br/>' if $required_fields{'state'} and ! $param{'state'}; 
	$error .= 'Missing country.<br/>' if $required_fields{'country'} and ! $param{'country'};
	if ( ! $session{'company_id'} ) {
		$error .= 'You must agree to the terms.<br/>' if $required_fields{'agree_terms'} and ! $param{'agree_terms'};
		if ( $required_fields{'postalcode'} ) {
			$error .= 'Missing Postal Code.<br/>' if ! $param{'postalcode'};
			$error .= 'Postal Code too long.<br/>' if length $param{'postalcode'} > 12;
		} # en dif
		$error .= 'Missing Phone Number.<br/>' if $required_fields{'phone'} and ! $param{'phone'};
		if ( $required_fields{'howdidyouhearaboutus'} and exists $param{'howdidyouhearaboutus'} ) {
			$error .= 'Please tell us how you heard about us.<br/>' if ! $param{'howdidyouhearaboutus'};
			$error .= 'Please tell us how you heard about us.<br/>' if ( $param{'howdidyouhearaboutus'} eq 'Other' ) and ( ! $param{'howdidyouhearaboutusother'} );
			$error .= 'Please tell us which csr referred you.<br/>' if ( $param{'howdidyouhearaboutus'} eq 'CSR' ) and ! ( $param{'howdidyouhearaboutusother'} or $param{'salesrep_id'} );
		} # end if
	} # end if
	$error .= 'Missing E-mail Address.<br/>' if ! $param{'email'};
	$error .= 'Invalid E-mail Address.<br/>' if ! Email::Valid->address( $param{'email'} );
	$error .= 'Empty Password.<br/>' if $param{'password'} eq '';
	$error .= 'Passwords do not match.<br/>' if $param{'password'} ne $param{'verifypassword'};
	if ( my $reason = openprint::login::check_password( $param{'password'} ) ) {
		$error .= "Password not good enough.  $reason<br/>";
	} # end if
	if ( ( ! $session{'company_id'} ) and ( $config{'UseCaptchaOnRegistration'} eq 'Y' ) ) {
		if ( ! -e $config{'SkinPath'}.'/images/captcha' ) {
			$log->error("Needtocreatecaptcha directory!");
		} elsif ( ! $param{'MD5SUM'} ) {
			$log->error("No MD5SUM, there must have been a problem creating the png!");
		} else {
			require Authen::Captcha;
			my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
			# Remove spaces, because some people want to put spaces between the characters, etc.
			$param{'Captcha'} =~ s/\s//g;
			if ( 1 != $Captcha->check_code( @param{'Captcha','MD5SUM'} ) ) {
				$error .= 'Validation Code incorrect.  Please try again.';
			} # end if
		} # end if
	} # end if

	if ( $error ne '' ) {
		$variable{'error'} = $error;
		return;
	} # end if

	# enforce unique email addresses.
	$param{'email'} =~ tr/[A-Z]/[a-z]/;
	if ( openprint::User->find_one('email lc'=>$param{email} ) ) {
		$variable{'error'} = $param{'email'} .' is already a user!';
		return;
	} # end if
	if ( openprint::User->find_one('email lc'=>$param{email},'deleted'=>1 ) ) {
		$variable{'error'} = $param{'email'} .' is already a user, but has been deleted. Please contact us to re-activate your account.';
		return;
	} # end if

	my @agents = split(',', $config{'UserRegistrationEmail'} );
	my $agent = $agents[0] if @agents;
	
	# No errors, We are in go status
	my %info;
	foreach my $key ( keys %param ) {
		$info{$key} = $param{$key};
	} # end foreach

	$info{'date'} = localtime;
	$info{'CustomerServiceEmail'} = $config{'CustomerServiceEmail'};

	# CLean up the postal code
	if ( exists $param{'postalcode'} ) {
		$param{'postalcode'} =~ s/[^[[:alnum:]]]//g;
		$param{'postalcode'} = uc $param{'postalcode'};
	} # end if

	my @Users;
	# if Company already exists in the DB, then just add the user to that company.	Otherwise, add the company
	my $Company;
	if ( $param{'company_name'} ) {
		$Company = openprint::Company->find_one( 'name lc'=>lc openprint::Company->transform('name',$param{'company_name'}),
			( exists $param{'postalcode'} ? ( 'postalcode uc'=>$param{'postalcode'} ) : () )
			);

		if ( ! $Company ) {
			$param{'name'} = $param{'company_name'};

			$Company = new openprint::Company();
			$Company->set( \%param );
			$Company->taxexempt1( $param{'gstnumber'} ? 'Y' : 'N' );
			$Company->taxexempt2( $param{'pstnumber'} ? 'Y' : 'N' );
			$Company->activation( $config{'NewCustomerAccountActivation'} );
			if ( sets::isin( $session{'user_type'}, ['E','A'] ) and ! $Company->salesrep_id() ) {
				$Company->salesrep_id( $session{'user_id'} );
			} # end if
			if ( my $error = $Company->save() ) {
				$variable{'error'} .= $error;
				return;
			} # end if

			# Setup default Credit
			my $customer_credit = new openprint::customer_credit( $Company->id() );
			my %params = (
					'WarnDays'	=>	1*$config{'DefaultWarnDays'},
					'DenyDays'	=>	1*$config{'DefaultDenyDays'},
					'Limit'	=>	1*$config{'DefaultCreditLimit'},
					'Hold'	=>	$config{'DefaultCreditHold'},
					'Downpayment'	=>	1*$config{'DefaultDownpayment'},
					);
			$customer_credit->set( \%params );
		} else {
			if ( $config{'Require Unique Company'} eq 'Y' ) {
				$variable{'error'} .= $param{'company_name'} . ' is already taken.';
				return;
			} # end if
		} # end if
	} elsif ( $session{'company_id'} ) {
		$Company = new openprint::Company( $session{'company_id'} );
		@Users = openprint::User->find('company_id'=>$Company->id());
	} else {
		# Don't know what company to assign
	} # end if

	my $User = new openprint::User();
	$User->set( \%param );
	$User->company_id( $Company->id() );
	$User->ftp_active( 'Y' );
	$User->type( 'C' );
	$User->change_password( 'N' );
	$User->howdidyouhearaboutus( $param{'howdidyouhearaboutus'} );
	$User->howdidyouhearaboutusother( $param{'howdidyouhearaboutusother'} );
	$info{'Company'} = $Company;
	$info{'User'} = $User;

	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	if ( ! @Users ) {
		$User->web_active( $config{'NewFirstUserAccountActivation'} );
		$User->administrator( 'Y' );
		$variable{'error'} .= $User->save();		
		return if $variable{'error'};
		$variable{'information'} .= 'Registration was successful.<br/><br/>';
		$variable{'success'} = 1;
		$variable{'error'} .= $User->Profile()->save(\%param);
		$variable{'error'} .= ( new openprint::Log())->save({'action'=>'Create User', 'company_id'=>$Company->id(), 'user_id'=>$User->id()});

		# Promo Codes can only happen when we are creating a new company. Otherwise they breach the security of the existing company.
		if ( $param{'promo_code'} ) {
			require openprint::Promo_Code;
			if ( my $Promo = openprint::Promo_Code->find_one('code'=>$param{'promo_code'}) ) {
				$log->debug("Found promo code $$Promo{effect}");
				eval $$Promo{'effect'};
				$log->error( "Eval error of promo code $param{'promo_code'}, Reason: " . $@ ) if $@;
			} else {
				$variable{'information'} .= 'Promo code not found.';
			} # end if
		} # end if

		# Send confirmation
		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/first_user_login_app_confirmation.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		new openprint::Email()->send(
				FROM	=> $agent,
				TO		=> $User,
				SUBJECT => 'New Login Application',
				ATTACHMENTS	=> [ '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
				);

		if ( ! sets::isin( $session{'user_type'}, ['E','A'] ) ) {
# send notification
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/first_user_login_app_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
			foreach my $to ( split(',', $config{'UserRegistrationEmail'} ) ) {
				new openprint::Email()->send(
						FROM	=> $agent,
						TO	=> $to,
						SUBJECT => 'New Login Application',
						'Reply-To' => sprintf('"%s %s" <%s>', $User->get( 'firstname','lastname','email' ) ),
						ATTACHMENTS	=>	[ '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
						);
			} # end foreach
		} # end if

		# Can only do the additional user thing if it's the initial couple creation
		if ( exists $param{'additional_user'} ) {
			$variable{'additional_user'} = $param{'additional_user'};
			$session{'company_id'} = $Company->id();
			%param = ();
		} # end if
	} else {

		$User->web_active( $session{'company_id'} ? 'Y' : $config{'NewNonFirstUserAccountActivation'} );
		$User->administrator( 'N' );
		$variable{'error'} .= $User->save();		
		return if $variable{'error'};
		$variable{'information'} .= 'Registration was successful.<br/><br/>';
		$variable{'success'} = 1;
		$variable{'error'} .= $User->Profile()->save(\%param);
		$variable{'error'} .= ( new openprint::Log())->save({'action'=>'Create User', 'company_id'=>$Company->id(), 'user_id'=>$User->id()});

		if ( $User->web_active ne 'Y') {
			# send notifications
			foreach my $Notification ( openprint::User->find( 'company_id'=>$Company->id(), 'administrator'=>'Y' ) ) {
				@info{'AdminSalutation','AdminFirstName','AdminLastName'} = $Notification->get('salutation','firstname','lastname');

				$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_notification_for_company_admin.html' );
				$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
				(new openprint::Email())->send(
						FROM	=> $agent,
						TO		=> $Notification,
						SUBJECT => 'New Login Application',
						ATTACHMENTS	=> [ '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
						);
			} # end foreach

			# Send confirmation to the newly added user
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_confirmation.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
			(new openprint::Email())->send(
					FROM	=> $agent,
					TO		=> $User,
					SUBJECT => 'New Login Application',
					ATTACHMENTS	=> [ '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
					);
		} # end if User not activated

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_notification_for_site_admin.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		foreach my $to ( split(',', $config{'UserRegistrationEmail'} ) ) {
			new openprint::Email()->send(
					FROM	=> $agent,
					TO	=> $to,
					'Reply-To' => sprintf('"%s %s" <%s>', $User->get( 'firstname','lastname','email' ) ),
					SUBJECT => 'New Login Application',
					ATTACHMENTS	=> [ '', encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
					);
		} # end foreach

		if ( $param{'rdbReasonForPurchase'} eq 'Reseller' ) {
			if ( $Company->reseller() ne 'Y' ) {
				$variable{'Redirect'} = '/account/reseller_application.html';
			} # end if
		} # end if
	} # end if Company has users or not

	if ( sets::isin( $session{'user_type'}, ['E','A'] ) ) {
		# If I'm a salesrep, then only change my company, not the user.
		$session{'company_id'} = $Company->id();
		$variable{'information'} .= 'You are now representing '.$Company->name().'<br/>';
	} else { 
		# auto log in.
		if ( $User->web_active() eq 'Y' and $Company->activation() eq 'Y') {
			@session{'company_id','user_id','email','user_type'} = ( $Company->id(), $User->id(), $User->email(), 'C' );
			(new openprint::Log())->save({'action'=>'Login', 'note'=>'Automatic login after registration.'});
			$variable{'information'} .= '<p>Your account has been activated and you have been automatically logged in.</p>';
		} else {
			$variable{'information'} .= 'At this time your login remains inactive.<br/><br/>You will be notified via email when your account is activated.<br/>';
		} # end if
	} # end if

} # end sub registration

sub _check_company_name {
} # end sub _check_company_name

sub login_password {
	$_ = $config{'customerlogin'};
	if ($ENV{'HTTP_REFERER'} =~ /$_/) {
		$variable{'message'} = "Your account has been activated.	While it is not required, it is recommended you change your password now.";
	} else {
		$variable{'message'} = "Please enter the required information to change your password.";
	} # end if
} # login password

sub company_profile {
	my $Company = $variable{'Company'} = new openprint::Company( $session{'company_id'} );

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
				$variable{'error'} = $error;
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
	my $Me = $variable{'Me'} = new openprint::User( $session{'user_id'} );
	my $User;
# IF it's empty, then we are adding a new user! Otherwise editing one
	if ( exists $param{'ddmUser'} ) {
		$User = openprint::User->find_one('id'=>$param{'ddmUser'} );
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
			my $error = '';
			if ( $param{'password'} ne $User->password() ) {
				if ( ! $param{'verifypassword'} ) {
					$variable{'warning'} .= 'Verify password left blank, password not changed.<br/>';
					delete $param{'password'};
				} else {
					$error .= "Password fields do not match.<br/>" if $param{'password'} ne $param{'verifypassword'};
				} # end if
			} # end if

			$error .= 'Email Cannot be blank.<br/>' if ! $param{'email'};
			if ( $config{'UserProfileRequiredFields'} ) {
				foreach my $field ( split(',',$config{'UserProfileRequiredFields'} ) ) {
					$error .= $field . ' cannot be blank.<br/>' if ! $param{$field};
				} # end foreach required field
			} else {
				$error .= 'First Name cannot be blank.<br/>' if ! $param{'firstname'};
				$error .= 'Last Name cannot be blank.<br/>' if ! $param{'lastname'};
				$error .= 'Salutation cannot be blank.<br/>' if ! $param{'salutation'};
				$error .= 'Phone cannot be blank.<br/>' if ! $param{'phone'};
			} # end if
			if ( $error ne '' ) {
				$variable{'error'} = 'Bad Field';
				$variable{'information'} = $error;
				$variable{'User'} = $User;
				return;
			} # end if

			if ( openprint::User->find_one( 'email lc'=>lc $param{'email'}, 'id !='=>$User->id() ) ) {
				$variable{'error'} = 'User already exists.';
				$variable{'information'} = $param{'email'} . ' is already a user.';
				$variable{'User'} = $User;
				return;
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
				$param{'change_password'} = 'N';
				$param{'password_changed_on'} = 'NOW()';
			} # end if

			$variable{'error'} .= $User->save( \%param );

			$User->Profile()->save( \%param );
$log->debug("Back from profile sae");

			if ( $param{'ddmUser'} and ( $param{'ddmUser'} != $session{'user_id'} ) and ( $oldpassword ne $User->password() ) ) {
$log->debug("Sending password change");
# Send password change email
				if ( my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' ) ) {
					my %info = (
							'User' =>$User,
						   );

					$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/changed_password.html' );
					$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

					(new openprint::Email())->send(
							FROM    => $config{'AdministratorEmail'},
							TO      => $User,
							SUBJECT => 'Password Changed',
							ATTACHMENTS	=> [ '', encode_qp( ssi::variable_substitution( \$email_template, \%info ) ), 'text/html', 'quoted-printable' ],
							);
					$variable{'information'} = 'The user has been notified by email of the password change.';
				} else {
					$variable{'error'} = 'We were unable to email the new password. Please contact support.';
				} # end if
			} # end if to send changed password notification
		} # end if btnFunction
	} # end if can_edit

	if ( (!$User->id()) and ( $session{'company_id'} != $Me->company_id() ) ) {
		$User = openprint::User->find_one('company_id'=>$session{'company_id'} );
	} # end if 
	if ( ! ($User and $User->id()) ) {
		$User = $Me;
	} # end if
	$variable{'User'} = $User;
} # end sub user_profile

sub change_password {
}
sub change_password_confirmation {
	openprint::login::change_password();
} # sub change_password

sub login {
	if ( $param{'btnFunction'} eq 'Forgotten Password' ) {
		if ( ! $param{'email'} ) {
			$variable{'error'} = 'Please enter the email address of the account to retrieve.';
			return;
		} # end if

		my $User = openprint::User->find_one('email lc'=> lc $param{'email'} );
		if ( ! $User ) {
			$variable{'error'} = 'The account you entered does not exist.';
			return;
		} # end if

		if ( my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' ) ) {
			my %info = ( 'User' => $User );

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/forgotten_password.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
			my $results = (new openprint::Email())->send(
					FROM 	=> $config{'AdministratorEmail'},
					TO		=> $User,
					SUBJECT	=> 'Forgotten Password',
					ATTACHMENTS	=> [ '', encode_qp( ssi::variable_substitution( \$email_template, \%info ) ), 'text/html', 'quoted-printable'],
					);
			if ( $results ) {
				$variable{'information'} = 'Your password has been mailed to you.';
			} else {
				$variable{'error'} .= 'Your password was not email for some reason. Please contact support.';
			} # end if
		} else {
			$variable{'error'} = 'We were unable to email your password to you.	Please contact support.';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Login' ) {
		if ( ! $param{'email'} ) {
			$variable{'error'} = 'Please enter the email address of the account to retrieve.';
			return;
		} # end if
		if ( $session{'user_id'} ) {
			openprint::login::logout();
		} # end if
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
			my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/reseller_application_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

			new openprint::Email()->send(
					FROM	=> $config{'ResellerApplicationEmail'},
					TO	=> $config{'ResellerApplicationEmail'},
					SUBJECT	=> 'New Reseller Application',
					ATTACHMENTS	=> [ '', encode_qp( ssi::variable_substitution( \$email_template, \%info ) ), 'text/html', 'quoted-printable' ],
					);

		} # end if ! error
	} # end if Apply

} # sub reseller_application

sub credit_application {
	my $Company = $variable{'Company'} = new openprint::Company( $session{'company_id'} );

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
		my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
		my $template = ssi::variable_substitution( \$email_template, \%info );

		new openprint::Email()->send(
				FROM	=> $config{'CreditApplicationEmail'},
				TO	=> $config{'CreditApplicationEmail'},
				SUBJECT => 'New Credit Application',
				ATTACHMENTS	=> [ '', encode_qp($template), 'text/html', 'quoted-printable' ],
				);
	} # end if Apply

} # sub credit_application

sub view {
	$variable{'Me'} = new openprint::User( $session{'user_id'} );
	$variable{'User'} = new openprint::User( $param{'user_id'} ? $param{'user_id'} : $session{'user_id'} );
	if ( exists $param{'relationship_type_id'} ) {
		if ( $variable{'User'}->id() == $variable{'Me'}->id() ) {
			$variable{'error'} .= "We already know you love yourself.  Frequently.";
			return;
		} # endif
		my $Relationship = openprint::User_Relationship->find_one('user_id1'=>$session{'user_id'}, 'user_id2'=>$variable{'User'}->id() );
		if ( ! $Relationship ) {
			$Relationship = new openprint::User_Relationship();
			$Relationship->set({'user_id1'=>$session{'user_id'}, 'user_id2'=>$variable{'User'}->id()});
		} # end if
		$variable{'error'} .= $Relationship->save({'type_id'=>$param{'relationship_type_id'}});
	} # end if
} # end sub view

sub couple_search {
	_couple_search();
	ssi::setup_date_select( '/account/couple_search.html', 'created_on_start', '' );
	ssi::setup_date_select( '/account/couple_search.html', 'created_on_end', '' );
	ssi::setup_date_select( '/account/couple_search.html', 'last_online_start', -31 );
	ssi::setup_date_select( '/account/couple_search.html', 'last_online_end', '' );
} # end sub search

sub _couple_search {
	ssi::save_params( '/account/couple_search.html', ( 
				'created_on_start_year', 'created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'last_online_start_year', 'last_online_start_month','last_online_start_day',
				'last_online_end_year','last_online_end_month','last_online_end_day',
				map { 'field-'.$_->id() } openprint::Company_Profile_Field->find('order'=>'sort,name') 
				) );
} # end sub _search
sub search {
	_search();
	ssi::setup_date_select( '/account/search.html', 'created_on_start', '' );
	ssi::setup_date_select( '/account/search.html', 'created_on_end', '' );
	ssi::setup_date_select( '/account/search.html', 'last_online_start', -31 );
	ssi::setup_date_select( '/account/search.html', 'last_online_end', '' );
	$session{'/account/search.html?paging_per_page'} = 5;
} # end sub search

sub _search {
	ssi::save_params( '/account/search.html', ( 
				'created_on_start_year', 'created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'last_online_start_year', 'last_online_start_month','last_online_start_day',
				'last_online_end_year','last_online_end_month','last_online_end_day',
				( map { 'field-'.$_->id() } openprint::User_Profile_Field->find( ) ),
				'paging_page',
				) );
	# Special case for checkboxes because they don't get passed if nothing is checked
	foreach my $F ( openprint::User_Profile_Field->find( ) ) {
		if ( ! $param{'field-'.$F->id()} ) {
			delete $session{'/account/search.html?field-'.$F->id()};
		} # end if
	} # end foreach Field

} # end sub _search

sub _wall { 
	$variable{'User'} = new openprint::User( $param{'user_id'} );
	if ( $param{'message'} ) {
		my $Wall = new openprint::Wall();
		$variable{'error'} = $Wall->save({'user_id'=>$param{'user_id'},
			'author_id'	=>	$session{'user_id'},
			'message'	=>	$param{'message'},
			});
	} elsif ( $param{'action'} eq 'delete' ) {
		my $Wall = openprint::Wall->find_one('id'=>$param{'wall_id'});
		if ( $Wall and $Wall->can_edit() ) {
			$Wall->delete();
		} # end if
	} # end if
} # end sub _wall

sub forgotten_password {
} # end sub forgotten_password

sub _location_ddm {
} # end sub _location_ddm

sub _relationships {
	if ( $param{'action'} eq 'delete' ) {
		my $R = new openprint::User_Relationship( { map { $_, $param{$_} } ( 'user_id1','user_id2','type_id' ) } );
		if ( sets::isin( $session{'user_id'}, [ $R->user_id1(), $R->user_id2() ] ) ) {
			$variable{'error'} .= $R->delete();
		} else {
			$log->error("Can't delete a relationship taht we are not in.");
			$variable{'error'} .= 'You cannot delete a relationship that you are not a part of.';
		} # end if
	} elsif ( $param{'action'} eq 'approve' ) {
		my $R = new openprint::User_Relationship( { map { $_, $param{$_} } ( 'user_id1','user_id2','type_id' ) } );
		if ( $R->user_id2() != $session{'user_id'} ) {
			$variable{'error'} .= 'You cannot approve that relationship.';
			$log->error("Invalid attempt to approve relationship");
		} else {
			if ( $R->approved() ) {
				$log->warn('Relationship already approved.');
			} else {
				$variable{'error'} .= $R->save({'approved'=>1});
			} # end if
		} # end if
	} elsif ( $param{'action'} eq 'add' ) {
		if ( $param{'company_id'} ) {
		} else {
		my $R = new openprint::User_Relationship( { map { $_, $param{$_} } ( 'user_id1','user_id2','type_id' ) } );
		$variable{'error'} .= $R->save({map { $_, $param{$_} } ( 'user_id1','user_id2','type_id' ) } );
		} # end if
	} # end if
	$variable{'User'} = new openprint::User( $param{'user_id'} );
} # end sub _relationships

sub relationships {
} # end sub relationships

# Assume that user_id2 is session{user_id}
sub _unapproved_relationships {
	if ( $param{'action'} eq 'delete' ) {
		my $R = new openprint::User_Relationship( { 'user_id1' => $param{'user_id1'},'user_id2'=>$session{'user_id'},'type_id'=>$param{'type_id'} } );
		if ( $R->user_id2() == $session{'user_id'} ) {
			$variable{'error'} .= $R->delete();
		} else {
			$log->error("Can't delete a relationship that we are not in.");
			$variable{'error'} .= 'You cannot delete a relationship that you are not a part of.';
		} # end if
	} elsif ( $param{'action'} eq 'approve' ) {
		my $R = new openprint::User_Relationship( { 'user_id1' => $param{'user_id1'},'user_id2'=>$session{'user_id'},'type_id'=>$param{'type_id'} } );
		if ( $R->user_id2() == $session{'user_id'} ) {
			$variable{'error'} .= $R->save({'approved'=>1});
		} else {
			$log->error("Can't approve a relationship that we are not in.");
			$variable{'error'} .= 'You cannot approve a relationship that you are not a part of.';
		} # end if
	} # end if
} # end sub _unapproved_relationships

sub couple_view {
	my $Company = $variable{'Company'} = new openprint::Company( $param{'company_id'} );
	$variable{'Me'} = new openprint::User( $session{'user_id'} );
} # end sub couple_view

1;
__END__
