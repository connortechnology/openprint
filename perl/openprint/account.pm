use strict;
package openprint::account;

require Email::Valid;
require sql;
require ssi;
require misc;
require MIME::QuotedPrint;
require Encode;

require countries;
require states;
require provinces;

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
require openprint::Blocklist;

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

sub select_user {
	if ( $param{user_id} ) {
		if ( $session{user_type} ne 'A' ) {
			$variable{error} .= 'You are not an administrator.  You cannot impersonate other users.<br/>';
			return;
		} # end if
		my $User = $variable{User} = new openprint::User( $param{user_id} );
		@session{'company_id','user_id','user_type'} = $User->get('company_id','id','type');
	} # end if user_id
} # end sub select_user

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
	if ( ( ! $param{'company_name'} ) and ( ! $session{'company_id'} ) ) {
		if ( $required_fields{'company_name'} ) {
			$error .= 'Missing company name.<br/>';
		} elsif ( $param{'firstname'} or $param{'lastname'} ) {
			$param{'company_name'} = $param{'firstname'} . ' ' . $param{'lastname'};
		} # end if
	} # end if
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
	if ( $required_fields{email} ) {
	$error .= 'Missing E-mail Address.<br/>' if ! $param{'email'};
	$error .= 'Invalid E-mail Address.<br/>' if ! Email::Valid->address( $param{'email'} );
	}
	if ( $required_fields{password} ) {
	$error .= 'Empty Password.<br/>' if $param{'password'} eq '';
	$error .= 'Passwords do not match.<br/>' if $param{'password'} ne $param{'verifypassword'};
	if ( my $reason = openprint::login::check_password( $param{'password'} ) ) {
		$error .= "Password not good enough.  $reason<br/>";
	} # end if
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
				$error .= 'Captcha validation code incorrect.  Please try again.';
			} # end if
		} # end if
	} # end if

	if ( $error ne '' ) {
$log->warn("registration errors $error");
		$variable{'error'} = $error;
		return;
	} # end if

	my $User;
	if ( $param{email} ) {
		# enforce unique email addresses.
		$param{'email'} =~ tr/[A-Z]/[a-z]/;
		if ( openprint::User->find_one('email lc'=>$param{email},'company_id is null'=>0 ) ) {
			$variable{'error'} = $param{'email'} .' is already a user!';
			return;
		} # end if
		if ( openprint::User->find_one('email lc'=>$param{email},'deleted'=>1 ) ) {
			$variable{'error'} = $param{'email'} .' is already a user, but has been deleted. Please contact us to re-activate your account.';
			return;
		} # end if
		$User = openprint::User->find_one('email lc'=>$param{email},'company_id is null'=>1 );
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
			$Company->activation( $config{'NewCustomerAccountActivation'} );
			if ( sets::isin( $session{'user_type'}, ['E','A'] ) and ! $Company->salesrep_id() ) {
				$Company->salesrep_id( $session{'user_id'} );
			} # end if
			if ( my $error = $Company->save() ) {
				$variable{'error'} .= $error;
				return;
			} # end if
			my @Suppliers = openprint::Company->find('offers_credit'=>1,'order'=>'id');
			foreach my $Supplier ( @Suppliers ) {
# Setup default Credit
				my $Credit = new openprint::Company_Credit();
				$Credit->save({
						'company_id'    =>  $Company->id(),
						'supplier_id'   =>  $Supplier->id(),
						'warndays'      =>  $openprint::config{'DefaultWarnDays'},
						'denydays'      =>  $openprint::config{'DefaultDenyDays'},
						'limit'         =>  $openprint::config{'DefaultCreditLimit'},
						'hold'          =>  $openprint::config{'DefaultCreditHold'},
						'downpayment'   =>  $openprint::config{'DefaultDownpayment'},
						'cod'           =>  $openprint::config{'DefaultCOD'},
						});
			} # end foreach Supplier

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
		$Company = new openprint::Company( );
		$Company->save();
		$Company->name( $Company->id() );
		$Company->set( \%param );
		$Company->activation( $config{'NewCustomerAccountActivation'} );
		if ( my $error = $Company->save() ) {
			$variable{'error'} .= $error;
			return;
		} # end if
		
	} # end if

	if ( $param{email} or $param{firstname} or $param{lastname} ) {
		$User = new openprint::User() if ! $User;
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
				if ( my $Promo = openprint::Promo_Code->find_one('code lc'=>lc openprint::Promo_Code->transform('code',$param{'promo_code'})) ) {
					$log->debug("Found promo code $$Promo{effect}");
					eval $$Promo{'effect'};
					$log->error( "Eval error of promo code $param{'promo_code'}, Reason: " . $@ ) if $@;
				} else {
					$variable{'information'} .= 'Promo code not found.';
				} # end if
			} # end if

			if ( $User->email() ) {
# Send confirmation
				if ( -e $config{'SkinPath'} . '/email_content/first_user_login_app_confirmation.html' ) {
					$info{'ReplacementText'} = misc::load_file( $log, $config{'SkinPath'} . '/email_content/first_user_login_app_confirmation.html' );
				} else {
					$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/first_user_login_app_confirmation.html' );
				} # end if
				$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
				new openprint::Email()->send(
						FROM	=> $agent,
						TO		=> $User,
						SUBJECT => 'New Login Application',
						ATTACHMENTS	=> [ '', MIME::QuotedPrint::encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
						);
			} # end if

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
							ATTACHMENTS	=>	[ '', MIME::QuotedPrint::encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
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

#FIXME
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
							ATTACHMENTS	=> [ '', MIME::QuotedPrint::encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
							);
				} # end foreach

				if ( $User->email() ) {
# Send confirmation to the newly added user
					$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_confirmation.html' );
					$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
					(new openprint::Email())->send(
							FROM	=> $agent,
							TO		=> $User,
							SUBJECT => 'New Login Application',
							ATTACHMENTS	=> [ '', MIME::QuotedPrint::encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
							);
				} # end if
			} # end if User not activated

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/not_first_user_login_app_notification_for_site_admin.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
			foreach my $to ( split(',', $config{'UserRegistrationEmail'} ) ) {
				new openprint::Email()->send(
						FROM	=> $agent,
						TO	=> $to,
						'Reply-To' => sprintf('"%s %s" <%s>', $User->get( 'firstname','lastname','email' ) ),
						SUBJECT => 'New Login Application',
						ATTACHMENTS	=> [ '', MIME::QuotedPrint::encode_qp(ssi::variable_substitution( \$email_template, \%info )), 'text/html', 'quoted-printable' ],
						);
			} # end foreach

			if ( $param{'rdbReasonForPurchase'} eq 'Reseller' ) {
				if ( $Company->reseller() ne 'Y' ) {
					$variable{'Redirect'} = '/account/reseller_application.html';
				} # end if
			} # end if
		} # end if Company has users or not
	} # end if has email first or last name

	if ( sets::isin( $session{'user_type'}, ['E','A'] ) ) {
		# If I'm a salesrep, then only change my company, not the user.
		$session{'company_id'} = $Company->id();
		$variable{'information'} .= 'You are now representing '.$Company->name().'<br/>';
	} elsif ( 
			( (! $session{'company_id'} ) or ( $session{'company_id'} == $Company->id() ) )
			and ( ! $session{'user_id'} ) 
			) { 
$log->debug('U ' . $User->web_active(). ' C' . $Company->activation() );
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
	my $Company;
		$Company = new openprint::Company( $param{company_id} );

	if ( ! $Company->can_view() ) {
		$variable{error} .= 'You cannot view company ' . $Company->id() . '<br/>';
		$Company = $variable{Company} = new openprint::Company();
		return;
	} # end if

	if ( $param{'btnFunction'} eq 'Save' ) {
		if ( ! $Company->id() ) {
			$variable{error} .= 'no company specified.';
			return;
		}
		if ( ! $Company->can_edit() ) {
			$variable{error} .= 'You cannot edit company ' . $Company->id() . '<br/>';
			return;
		} # end if
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
		$Company->Profile()->save( \%param );
	} # end if
	if ( ! $Company->id() ) {
		$Company = new openprint::Company( $session{company_id} );
	}

	$variable{'Company'} = $Company;
} # end sub company_profile

sub user_profile {
	require Lingua::EN::Inflect;
	my $Me = $variable{Me} = new openprint::User( $session{user_id} );
# IF it's empty, then we are adding a new user! Otherwise editing one
	my $User = new openprint::User( $param{ddmUser} );

	if ( $User->can_edit() ) {
		if ( $param{'btnFunction'} eq '<<' ) {
			$User = $User->Prev( 'company_id'=>$session{'company_id'} );
		} elsif ( $param{'btnFunction'} eq '>>' ) {
			$User = $User->Next( company_id=>$session{company_id} );
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
			} # end if
			if ( $error ne '' ) {
				$variable{'error'} = 'Bad Field';
				$variable{'information'} = $error;
				$variable{'User'} = $User;
				return;
			} # end if

			if ( openprint::User->find_one( 'email lc'=>lc $param{'email'}, ( $User->id() ? ( 'id !='=>$User->id() ) : () ) ) ) {
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
			if ( $config{mail_db_name} ) {
				my @domains = email::domains();
				my ( $user, $domain ) = $User->email() =~ /^([^\@]+)\@(.+)$/;
				if ( sets::isin( $domain, \@domains ) ) {
					if ( $param{'VacationState'} ) {
						email::start_vacation( $User->email(), @param{'VacationSubject','VacationMessage'} );
					} else {
						email::stop_vacation( $User->email() );
					} # end if
					if ( $param{'EmailPassword'} and $param{'EmailPassword'} eq $param{'VerifyEmailPassword'} ) {
						email::set_password( @param{'email','EmailPassword'} );
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

			$variable{'ExternalRedirect'} = '/account/user_profile.html?ddmUser='.$User->id();

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
							ATTACHMENTS	=> [ '', MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%info ) ), 'text/html', 'quoted-printable' ],
							);
					$variable{'information'} = 'The user has been notified by email of the password change.';
				} else {
					$variable{'error'} = 'We were unable to email the new password. Please contact support.';
				} # end if
			} # end if to send changed password notification
		} # end if btnFunction
	} # end if can_edit

	if ( !$User->id() ) {
		if ( $session{company_id} != $Me->company_id() ) {
			$User = openprint::User->find_one( company_id=>$session{company_id}, order=>'lower(firstname),lower(lastname)' );
			$User = new openprint::User() if ! $User;
		} else {
			$User = $Me;
		} # end if
	} # end if 
	$variable{'User'} = $User;
    if ( $config{mail_db_name} ) {
        my @domains = email::domains();
        my ( $user, $domain ) = $User->email() =~ /^([^\@]+)\@(.+)$/;
        if ( sets::isin( $domain, \@domains ) ) {
            $variable{DoEmail} = 1;
            @variable{'VacationState','VacationSubject','VacationMessage'} = email::get_vacation( $User->email() );
            @{$variable{Aliases}} = email::aliases( $User->email() );
        } # end if
    } # end if
} # end sub user_profile

sub change_password {
}
sub change_password_confirmation {
	openprint::login::change_password();
} # sub change_password

sub login {
	if ( $param{'btnFunction'} eq 'Forgotten Password' ) {
		openprint::login::forgotten_password();
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
					ATTACHMENTS	=> [ '', MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%info ) ), 'text/html', 'quoted-printable' ],
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

		my $App = new openprint::Credit_Application();
		$variable{'error'} .= $App->save({
				'desired_limit'         =>  $param{'DesiredCreditLimit'},
				'user_id'               =>  $session{'user_id'},
				'company_id'            =>  $session{'company_id'},
				'signature'             =>  $param{'Signature'},
				'financialstatementavailable'   =>  $param{'FinancialStatementAvailable'},
				'firstordervalue'       =>  $param{'FirstOrderValue'},
				'annualpurchases'       =>  $param{'AnnualPurchases'},
				'desired_limit'         =>  $param{'DesiredCreditLimit'},
				'desired_terms'         =>  $param{'DesiredTerms'},
				'accountspayablecontact'    =>  $param{'AccountsPayableContact'},
				'status'                =>  'Non-Reviewed',
				});

		if ( ! $variable{'error'} ) {
# Now send email notifications
			my %info;
			$info{'Company'} = $Company;
			$info{'User'} = new openprint::User( $session{user_id} );

			$info{'CreditAppIndex'} = $App->id();

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/credit_application_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
			my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
			my $template = ssi::variable_substitution( \$email_template, \%info );

			new openprint::Email()->send(
					FROM	=> $config{'CreditApplicationEmail'},
					TO	=> $config{'CreditApplicationEmail'},
					SUBJECT => 'New Credit Application',
					ATTACHMENTS	=> [ '', MIME::QuotedPrint::encode_qp(Encode::encode('utf-8',$template)), 'text/html', 'quoted-printable' ],
					);
		} # end if
	} # end if Apply

} # sub credit_application

sub view {
	$variable{Me} = new openprint::User( $session{user_id} );
	$variable{User} = new openprint::User( $param{'user_id'} ? $param{'user_id'} : $session{'user_id'} );
	if ( ! $variable{User}->can_view() ) {
		$variable{User} = new openprint::User();
		$variable{error} .= 'You cannot view this user.';
	} else {
		if ( $variable{User}->id() and $session{user_id} ) {
			my $View = openprint::View->find_one(object_type=>'openprint::User', object_id=>$variable{User}->id(), user_id=>$session{user_id} );
			if ( ! $View ) {
				$View = new openprint::View();
				$View->save({object_type=>'openprint::User', object_id=>$variable{User}->id(), user_id=>$session{user_id}});
			} # end if
		} # end if
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
	} # end if
} # end sub view

sub couple_search {
	_couple_search();
	ssi::setup_date_select( '/account/couple_search.html', 'created_on_start', '' );
	ssi::setup_date_select( '/account/couple_search.html', 'created_on_end', '' );
	ssi::setup_date_select( '/account/couple_search.html', 'last_online_start', '' );
	ssi::setup_date_select( '/account/couple_search.html', 'last_online_end', '' );
} # end sub couple_search

sub _couple_search {
	ssi::save_params( '/account/couple_search.html', ( 
				'created_on_start_year', 'created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'last_online_start_year', 'last_online_start_month','last_online_start_day',
				'last_online_end_year','last_online_end_month','last_online_end_day', 'distance',
				map { 'field-'.$_->id() } openprint::Company_Profile_Field->find('order'=>'sort,name') 
				) );
} # end sub _couple_search
sub search {
	if ( $param{'action'} eq 'Delete' ) {
		my $User = new openprint::User( $param{'user_id'} );
		if ( $User->can_edit() ) {
			$variable{'error'} .= $User->delete();
		} else {
			$variable{'error'} .= 'You do not have rights to delete this profile.';
		} # end if
	} elsif ( $param{action} eq 'Block' ) {
		my $User = new openprint::User( $param{user_id} );
		if ( ! $$User{id} ) {
			$variable{error} .= 'Invalid user specified.  Nobody blocked.';
			return;
		} # end if
		if ( openprint::Blocklist->find_one(blockee=>$session{user_id},blocker=>$$User{id}) ) {
			$variable{error} .= 'User already blocked.';
			return;
		} # end if
		if ( openprint::Blocklist->find_one(blocker=>$session{user_id},blockee=>$$User{id}) ) {
			$variable{error} .= 'User already blocked you.';
			return;
		} # end if
		my $Block = new openprint::Blocklist();
		$variable{error} .= $Block->save({blockee=>$$User{id},blocker=>$session{user_id}});
		$variable{information} .= 'User blocked.' if ! $variable{error};
	} # end if
	_search();
	ssi::setup_date_select( '/account/search.html', 'created_on_start', '' );
	ssi::setup_date_select( '/account/search.html', 'created_on_end', '' );
	ssi::setup_date_select( '/account/search.html', 'last_online_start', -365 );
	ssi::setup_date_select( '/account/search.html', 'last_online_end', '' );
	$session{'/account/search.html?paging_per_page'} = 20;
} # end sub search

sub _search {
	ssi::save_params( '/account/search.html', ( 
				'created_on_start_year', 'created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'last_online_start_year', 'last_online_start_month','last_online_start_day',
				'last_online_end_year','last_online_end_month','last_online_end_day', 'distance',
				'photos',
				( map { 'field-'.$_->id() } openprint::User_Profile_Field->find( ) ),
				) );
	# Special case for checkboxes because they don't get passed if nothing is checked
	foreach my $F ( openprint::User_Profile_Field->find( type =>'checkbox' ) ) {
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
			author_id	=>	$session{user_id},
			message		=>	$param{message},
			( $param{'reply_to'} ? ('reply_to'=>$param{'reply_to'}) : () ),
			});
		if ( $param{'reply_to'} ) {
			my $Parent = new openprint::Wall( $param{'reply_to'} );
			if ( ! $Parent->has_replies() ) {
				$Parent->save({'has_replies'=>1});
			} # end if
		} # end if
	} elsif ( $param{'action'} eq 'delete' ) {
		my $Wall = openprint::Wall->find_one('id'=>$param{'wall_id'});
		if ( $Wall and $Wall->can_edit() ) {
			$variable{'error'} .= $Wall->delete();
		} # end if
	} # end if
} # end sub _wall

sub _wall_reply {
	$variable{'User'} = new openprint::User( $param{'user_id'} );
} # end sub _wall_reply

sub forgotten_password {
} # end sub forgotten_password


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
			$variable{'information'} .= 'Your request has been sent.' if ! $variable{'error'};
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

sub _block_popup {
	$param{user_id} = openprint::User->transform( 'id', $param{user_id} ) if $param{user_id};
	$variable{User} = new openprint::User( $param{user_id} );
} # end sub _block_popup

sub blocklist {
} # end sub blocklist 

sub _blocklist_unblocked {
} # end sub _blocklist_unblocked
sub _blocklist_blocked {
} # end sub _blocklist_blocked

sub _blocklist_actions {
	if ( $param{action} eq 'unblock' ) {
		if ( $param{blockee} ) {
			my $Block = openprint::Blocklist->find_one( blockee=>$param{blockee}, blocker=>$session{user_id} );
			if ( $Block ) {
				if ( $$Block{unblock} ) {
					$variable{error} .= 'You have already requested to remove this bloock.  The other person must accept before the block will be removed.';
				} else {
					$variable{error} .= $Block->save({'unblock'=>1});
				} # end if
			} else {
				$variable{error} .= 'Block not found.';
			} # end if
		} elsif ( $param{blocker} ) {
			my $Block = openprint::Blocklist->find_one( blocker=>$param{blocker}, blockee=>$session{user_id}, unblock=>1 );
			$variable{error} .= $Block->destroy();
		} else {
			$log->error("Attempt to unblock with no blockee or blocker");
		} # end if
	} elsif ( $param{action} eq 'reinstate' ) {
		my $Block = openprint::Blocklist->find_one( blockee=>$param{blockee}, blocker=>$session{user_id} );
		$variable{error} .= $Block->save({unblock=>0});
	} # end if
} # end sub _blocklist_actions

sub companies {
   _companies();
    ssi::setup_date_select( '/account/companies.html', 'created_on_start', '' );
    ssi::setup_date_select( '/account/companies.html', 'created_on_end', '' );
    ssi::setup_date_select( '/account/companies.html', 'last_ordered_start', '' );
    ssi::setup_date_select( '/account/companies.html', 'last_ordered_end', '' );
    ssi::setup_date_select( '/account/companies.html', 'last_called_start', '' );
    ssi::setup_date_select( '/account/companies.html', 'last_called_end', '' );
} # end sub companies

sub _companies {
    ssi::save_params( '/account/companies.html', (
                ( map { 'created_on_start_' . $_ } ( 'year', 'month','day' ) ),
                ( map { 'created_on_end_' . $_ } ( 'year', 'month','day' ) ),
                ( map { 'last_ordered_on_start_' . $_ } ( 'year', 'month','day' ) ),
                ( map { 'last_ordered_on_end_' . $_ } ( 'year', 'month','day' ) ),
                ( map { 'last_called_on_start_' . $_ } ( 'year', 'month','day' ) ),
                ( map { 'last_called_on_end_' . $_ } ( 'year', 'month','day' ) ),
                ( map { 'field-'.$_->id() } openprint::Company_Profile_Field->find(order=>'sort,name') ),
				'company_name','salesrep_id', 'salesrep_id_exclude', 'marketingcategory_id', 'deleted',
                ) );
} # end sub _companies

1;
__END__
