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
use vars qw( $r %variable %param %session);
*r = \$openprint::r;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;

# displays the login page, and populates the destination variable
sub save_destination {
	my ( $destination ) = @_;

	if ( ! $destination ) {
		$destination = $r->uri();
		if ( %param ) {
			$destination .= '?' . join('&', map { $_ . '=' . $param{$_}} keys %param );
		} # end if
	} # end if

# if someone sets the Destination flag, keep it through the login process.
	if ( $destination =~ /main\/order/ ) {
		$session{'Destination'} = q{Click <a href="} . $destination . q{">here</a> to continue your order.};
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
		( $user_id ) = sql::execute( $log, $dbh, q{SELECT Index FROM Users WHERE strEmail=?}, $email );
		if ( ! $user_id ) {
			$$variable{'details'} = "\"$email\" is not a valid account.	Please try again.";
		} else {
			$$variable{'details'} = "The password you entered was not correct.	Please try again.";
			openprint::logs::insertLogRecord(78,'Invalid Password', $user_id );
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

			my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
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
			-name  => 'SessionID',
			-value => $openprint::session{_session_id},
			-path		=>	'/',
			);
		$Cookie->expires('+3M');
		$Cookie->bake( $r );
	} # end if	

	if ( $changepass eq 'Y' ) {
		if ( $site eq 'A' ) {
		$$variable{'Redirect'} = '/administrator/account/change_password.html';
		} elsif ( $site eq 'E' ) {
		$$variable{'Redirect'} = '/employee/account/change_password.html';
		} else {
		$$variable{'Redirect'} = '/main/account/change_password.html';
		} # end if
		return;
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

	if ( my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' ) ) {
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
		$User->change_password( 'N' );
		$User->save();
	} else {
		$$variable{'error'} = 'You entered the wrong old password.<br/>';
		$$variable{'Redirect'} = '/main/account/change_password.html';
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

1;

__END__
