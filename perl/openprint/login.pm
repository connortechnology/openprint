package openprint::login;

use Mail::Sendmail;
use MIME::QuotedPrint;
use strict;

require sql;
require ssi;
require misc;

require openprint::user;
require openprint::usergroup;
require openprint::logs;

use openprint ();
use vars qw( $r $dbh $log %variable %param %session %config);
*r = \$openprint::r;
*log = \%openprint::log;
*dbh = \%openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;

# displays the login page, and populates the destination variable
sub save_destination {
	my ( $destination ) = @_;

	if ( ! $destination ) {
		$destination = $r->uri();
        my @values;
        foreach my $key ( keys %param ) {
            next if $key eq 'password';
            push @values, map { $key.'='.$_ } ( ref $param{$key} eq 'ARRAY' ? @{$param{$key}} : $param{$key} );
        } # end ofreach     
        if ( @values ) {
            $destination .= '?' . join('&', @values );
        } # end if
	} # end if

# if someone sets the Destination flag, keep it through the login process.
	if ( $destination =~ /main\/order/ ) {
		$session{'Destination'} = q{Click <a href="} . $destination . q{">here</a> to continue your order.};
	} elsif ( $destination =~ /survey\.html/ ) {
		$session{'Destination'} = q{Click <a href="} . $destination . q{">here</a> to continue the survey.};
	} else {
		$session{'Destination'} = q{Click <a href="} . $destination . q{">here</a> to continue to the page you requested.};
	} # end if
} # end sub save_destination

# login verification.	called when someone logs in
sub verify_login {
	my ( $r, $log, $dbh, $cookie, $variable, $site ) = @_;
		
	# convert the email address to lower case. All email addresses stored in DB will be lower case.
	my $email = $openprint::param{'email'};
	$email =~ s/^\s*(.*?)\s*$/$1/;
	$email =~ tr/[A-Z]/[a-z]/;
	if ( ! $email ) {
		$$variable{'details'} = "\"$email\" is not a valid account.	Please try again.";
		$$variable{'error'} = 'Authentication Failed.';
		return;
	} # end if

	$log->debug("** Verifying Login for Email Adress: $email **");

	my $password = $openprint::param{'password'};

	# doing it this way allows for multiple accounts with the same email address, identified by their password.
	# however, on user registration, we enforce the uniqueness of email addresses.	Also, the db should have a UNIQUE
	# attribute on the strEmail field.
	$_ = q{SELECT Index, CompanyIndex, strSalutation, strFirstName, strLastName, chrType, ysnAccountActivation, ysnChangePassword } .
		q{, (SELECT ysnAccountActivation FROM Company WHERE Index=CompanyIndex)}.
		q{FROM Users WHERE strEmail = ? AND strPassword=? AND (deleted = false OR deleted IS NULL)};
	my ( $user_id, $cust_id, $salutation, $first_name, $last_name, $user_type, $user_activated, $changepass, $company_activated ) = sql::execute( $log, $dbh, $_, $email, $password );

	if ( ! $user_id ) {
		# user not found.	Let's see if we got the password wrong, or the email wrong.
		my @user_ids = sql::execute( $log, $dbh, q{SELECT Index FROM Users WHERE strEmail=?}, $email );
		if ( ! @user_ids ) {
			$$variable{'details'} = "\"$email\" is not a valid account.	Please try again.";
		} else {
			$$variable{'details'} = "The password you entered was not correct.	Please try again.";
			foreach ( @user_ids ) {
				openprint::logs::insertLogRecord(78,'Invalid Password. Username='.$email, $_, new openprint::User($_)->company_id() );
			} # end foreach
		} # end if
		$$variable{'error'} = 'Authentication Failed.';
		return;
	} # end if

	# Have a valid user now.
	if ( $company_activated eq 'N' ) {
		$$variable{'error'} = 'Company not activated.';
		$$variable{'details'} = 'Your customer account has not been looked over and activated by an administrator yet. You will be notified when your application has been approved.';
		openprint::logs::insertLogRecord(78,'Company Account Not Activated', $user_id );
		return;
	} elsif ( $company_activated ne 'Y' ) {
		$$variable{'error'} = "Customer Account activation status is unknown.";
		$$variable{'details'} = "Please report this error.";
		return;
	} # end if

	# Have a valid user now.
	if ( $user_activated eq 'N' ) {
		$$variable{'error'} = "User not activated.";
		$$variable{'details'} = "Applications for existing corporate accounts must be approved by and administrator. You will be notified when you application had been approved.";
		openprint::logs::insertLogRecord(78,'User Account Not Activated', $user_id );
		return;
	} elsif ( $user_activated ne 'Y' ) {
		$$variable{'error'} = "User Account activation status is unknown.";
		$$variable{'details'} = "Please report this error.";
		return;
	} # end if

	if ( $site eq 'E' and $user_type ne 'E' and $user_type ne 'A' ) {
		$$variable{'error'} = "Not authorised.";
		$$variable{'details'} = "You are not an employee.	You do not have access to the employee site.";
		openprint::logs::insertLogRecord(78,'User not an employee', $user_id );
		return;
	} elsif ( $site eq 'A' and $user_type ne 'A' ) {
		$$variable{'error'} = "Not authorised.";
		$$variable{'details'} = "You are not an administrator.	You do not have access to the administrator site.";
		openprint::logs::insertLogRecord(78,'User not an administrator', $user_id );
		return;
	} # end if

	if ( $user_type ne 'C' ) {
		if ( $cust_id != $openprint::config{'Owner'} ) {
# Send an email notification
			my %info;
			my $User = new openprint::User( $user_id );
			@info{'UserFirstName','UserLastName','UserEmail'} = $User->get('firstname','lastname','email');
			$info{'Site'} = $site;
			$info{'UserType'} = $user_type;

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/login_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );

			my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
			$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ) );
			my @body = ('', $_, 'text/html', 'quoted-printable');
			my %mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> $openprint::config{'LoginEmail'},
					TO		=> $openprint::config{'LoginEmail'},
					SUBJECT => "Login notification",
					);
			misc::send_email_with_attachment( $log, \%mail, @body );

		} # end if

	} # end if

	@openprint::session{'company_id','user_id','email','user_type'} = ( $cust_id, $user_id, $email, $user_type );
	delete $openprint::session{'Pricelist_id'};
	openprint::logs::insertLogRecord('2','Success');

	if ( $openprint::param{'rdbRememberMe'} eq 'Y' ) {
		my $Cookie = Apache2::Cookie->new($r,
			-name  => '_session_id',
			-value => $openprint::session{_session_id},
			-path		=>	'/',
			);
		$Cookie->expires('+3M');
		$Cookie->bake( $r );
	} # end if	
	if ( $changepass eq 'Y' ) {
		if ( ! $session{'Destination'} ) {
			save_destination( $r->uri() );
		} # end if
		$$variable{'Redirect'} = '/main/account/change_password.html';
		return;
	} elsif ( $session{'Destination'} =~ /^Click <a href="(.*)\.html\??(.*)">here<\/a>/ ) {
     
		$$variable{'Redirect'} = $1.'.html';
		foreach my $p ( split('&', $2 ) ) {
			my ( $k, $v ) = split('=', $p );
			$openprint::log->debug("verify_login: Parsmd: $p, $k = $v ");
			if ( $openprint::param{$k} ) {
				if ( ref $openprint::param{$k} eq 'ARRAY' ) {
					push @{$openprint::param{$k}}, $v;
				} else {
					$openprint::param{$k} = [ $openprint::param{$k}, $v ];
				} # end if
			} else {
				$openprint::param{$k} = $v;
			}
		} # end foreach
		delete $session{'Destination'};
	} elsif ( $session{'Destination'} =~ /^Click <a href="(.*)\.html\?(.*)">here<\/a> to continue the survey\./ ) {
     
		$$variable{'Redirect'} = $1.'.html';
		foreach my $p ( split('&', $2 ) ) {
			my ( $k, $v ) = split('=', $p );
			$openprint::log->debug("Psrsmd: $p, $k = $v ");
			if ( $openprint::param{$k} ) {
				if ( ref $openprint::param{$k} eq 'ARRAY' ) {
					push @{$openprint::param{$k}}, $v;
				} else {
					$openprint::param{$k} = [ $openprint::param{$k}, $v ];
				} # end if
			} else {
				$openprint::param{$k} = $v;
			}
		} # end foreach
		delete $session{'Destination'};
	} # end if

} # sub verify_login

sub logout {
	my ( $log, $dbh, $variable, $cookie, $site ) = @_;

	openprint::logs::insertLogRecord('3',);
	foreach my $k ( keys %openprint::session ) {
		next if sets::isin( $k, [ 'Currency_id', '_session_id','Country','Pricelist_id' ] );
		delete $openprint::session{$k};
	} # end foreach
	
} # sub logout

sub email_password {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $email = $openprint::param{'txtEmail2'};
	$email =~ tr/[A-Z]/[a-z]/;

	my ($user_id) = sql::execute( $log, $dbh, "SELECT Index FROM Users WHERE strEmail = '$email'" );
	if ( ! $user_id ) {
		return misc::error( $log, $dbh, $variable, 'Account doesn\'t exist.', 'The account you entered does not exist.' );
	} # end if

	if ( my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' ) ) {
		my %info = (
			'siteURL' => $r->dir_config('siteURL'),
			'SecureSiteURL' => $r->dir_config('SecureSiteURL'),
			'SiteTitle' => $r->dir_config('SiteTitle'),
		);
		
		openprint::user::load( $log, $dbh, $user_id, \%info );
		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/forgotten_password.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
		$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');

		my %mail = (
				SMTP	=> $openprint::config{'Mail Server'},
				FROM 	=> $openprint::config{'AdministratorEmail'},
				TO		=> $openprint::param{'txtEmail2'},
				SUBJECT	=> 'Forgotten Password',
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} else {
		return misc::error( $log, $dbh, $variable, 'System Error.', 'We were unable to email your password to you.	Please contact support.' );
	} # end if
} # sub email_password

sub login_password {
	my ( $r, $log, $dbh, $variable ) = @_;

	$_ = $openprint::config{'customerlogin'};
	if ($ENV{'HTTP_REFERER'} =~ /$_/) {
		$$variable{'message'} = "Your account has been activated.	While it is not required, it is recommended you change your password now.";
	} else {
		$$variable{'message'} = "Please enter the required information to change your password.";
	} # end if
} # login password

sub change_password {

	if ( $openprint::param{'txtNewPassword'} ne $openprint::param{'txtConfirmPassword'} ) {
		$variable{'error'} = 'The new password, and the verification passwords you entered do not match.<br/>';
		$variable{'Redirect'} = '/main/account/change_password.html';
		return;
	} # end if

	if ( $openprint::param{'txtNewPassword'} eq '' ) {
		$variable{'error'} = 'The new password you entered was blank.This is too insecure, and will not be allowed.<br/>';
		$variable{'Redirect'} = '/main/account/change_password.html';
		return;
	} # end if


	my $User = new openprint::User( $openprint::session{'user_id'} );

	if ( $openprint::param{'txtNewPassword'} eq $User->password() ) {
		$variable{'error'} = 'The new password you entered was the same as your current password. Please try again.</br>';
		$variable{'Redirect'} = '/main/account/change_password.html';
		return;
	} # end if

	if ( my $reason = check_password( $openprint::param{'txtNewPassword'} ) ) {
		$variable{'error'} = "The new password you entered was not good enough: $reason.<br/>";
		$variable{'Redirect'} = '/main/account/change_password.html';
		return;
	} # end if
	
	if ( $User->password() eq $openprint::param{'txtOldPassword'} ) {
		$User->password( $openprint::param{'txtNewPassword'} );
		$User->change_password( 'N' );
		$User->password_changed_on('NOW()');
		$User->save();
		if ( $session{'Destination'} =~ /^Click <a href="(.*)\.html\??(.*)">here<\/a>/ ) {
			$variable{'ExternalRedirect'} = $1.'.html?'.$2;
			delete $session{'Destination'};
		} # end if Destination
	} else {
		$variable{'error'} = 'You entered the wrong old password.<br/>';
		$variable{'Redirect'} = '/main/account/change_password.html';
		return;
	} # end if
} # sub change_password

# handles logout if timeout
sub verify_user {
	my ( $r, $log, $dbh, $cookie, $variable, $site ) = @_;

	return if ! $cookie;

	my $idletime = $openprint::config{'idletime'};

	if ( $openprint::session{'lastupdated'} and $openprint::session{'user_id'} and $idletime and ( time - $openprint::session{'lastupdated'} > $idletime ) ) {
		logout( $log, $dbh, $variable, $cookie, $site );
		$$variable{'idletime'} = $idletime;
		$$variable{'Destination'} = misc::get_destination( $r, $log );
		if ( $site eq 'C' ) {
			$$variable{'Redirect'} = '/error/idle_timeout.html';
		} elsif ( $site eq 'A' ) {
			$$variable{'Redirect'} = '/administrator/error/idle_timeout.html';
		} elsif ( $site eq 'E' ) {
			$$variable{'Redirect'} = '/employee/error/idle_timeout.html';
		} # end if
	} # end if
} # end sub verify_user

sub check_password {
	my ( $password ) = @_;
	if ( $openprint::config{'password_checks_min_length'} and ( length $password < $openprint::config{'password_checks_min_length'} ) ) {
		return "Too short.  Passwords must be at least $openprint::config{'password_checks_min_length'} characters long.";
	} # end if
	if ( $openprint::config{'password_checks_max_length'} and ( length $password < $openprint::config{'password_checks_max_length'} ) ) {
		return "Too long.  Passwords must be at most $openprint::config{'password_checks_max_length'} characters long.";
	} # end if
	if ( $openprint::config{'password_checks_uppercase'} eq 'yes' and ! ( $password =~ /[A-Z]/ ) ) {
		return "Password must contain at least 1 uppercase character.";
	} # end if
	if ( $openprint::config{'password_checks_lowercase'} eq 'yes' and ! ( $password =~ /[a-z]/ ) ) {
		return "Password must contain at least 1 lowercase character.";
	} # end if
	if ( $openprint::config{'password_checks_numbers'} eq 'yes' and ! ( $password =~ /[0-9]/ ) ) {
		return "Password must contain at least 1 number.";
	} # end if
	if ( $openprint::config{'password_checks_punctuation'} eq 'yes' and ! ( $password =~ /[!,@,#,$,%,^,&,*,?,_,~]/ ) ) {
		return 'Password must contain at least 1 of !,@,#,$,%,^,&,*,?,_,~.';
	} # end if
	if ( $openprint::config{'password_checks_min_score'} ) {
		my $strength = password_strength( $password );
		if ( $strength < $openprint::config{'password_checks_min_score'} ) {
			return "Password's strength score ( $strength ) must be at least $openprint::config{'password_checks_min_score'}.";
		} # end if
	} # end if
} # end sub check_password

sub password_strength {
	my ( $password ) = @_;

	my $score = 0;
	my $length = length $password;
	if ( $length < 5 ) {
		$score += 3;
	} elsif ( $length >= 5 and $length < 8 ) {
		$score += 6;
	} elsif ( $length >= 8 and $length < 16 ) {
		$score += 12;
	} elsif ( $length >= 16 ) {
		$score += 18;
	} # end if

	$score += 1 if $password =~ /[a-z]/;
	$score += 5 if $password =~ /[A-Z]/;
	$score += 5 if $password =~ /\d/;
	$score += 5 if $password =~ /(.*\d.*\d.*\d)/;
	$score += 5 if $password =~ /.[!,@,#,$,%,^,&,*,?,_,~]/;
	$score += 5 if $password =~ /(.*[!,@,#,$,%,^,&,*,?,_,~].*[!,@,#,$,%,^,&,*,?,_,~])/;
	$score += 2 if $password =~ /([a-z].*[A-Z])|([A-Z].*[a-z])/;
	$score += 2 if ( $password =~ /[a-zA-Z]/ and $password =~ /[0-9]/ );
	$score += 2 if $password =~ /([a-zA-Z0-9].*[!,@,#,$,%,^,&,*,?,_,~])|([!,@,#,$,%,^,&,*,?,_,~].*[a-zA-Z0-9])/;
	return $score;

} # end sub password_strength

sub forgotten_password {
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

	if ( my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' ) ) {
		my %info = (
				'User' =>$Users[0],
				);

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/forgotten_password.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
		$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');

		my %mail = (
				SMTP    => $openprint::config{'Mail Server'},
				FROM    => $openprint::config{'AdministratorEmail'},
				TO      => sprintf('"%s %s" <%s>', $Users[0]->get('firstname','lastname','email') ),
				SUBJECT => 'Forgotten Password',
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
		$variable{'information'} = 'Your password has been mailed to you.';
	} else {
		$variable{'error'} = 'We were unable to email your password to you. Please contact support.';
	} # end if
} # end sub forgotten_password
1;

__END__
