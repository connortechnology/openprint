package openprint::login;

use Mail::Sendmail;
use MIME::QuotedPrint;
use strict;

require sql;
require ssi;
require misc;

require openprint::usergroup;
require openprint::logs;

use openprint ();
use vars qw( $r %variable %param %session %config);
*r = \$openprint::r;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;

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
	my $email = lc $openprint::param{'email'};
	$email =~ s/^\s*(.*?)\s*$/$1/;

	$log->debug("** Verifying Login for Email Adress: $email **");

	my $password = $openprint::param{'password'};

	# doing it this way allows for multiple accounts with the same email address, identified by their password.
	# however, on user registration, we enforce the uniqueness of email addresses.	Also, the db should have a UNIQUE
	# attribute on the strEmail field.
	my @Users = openprint::User::find('email'=>$email, 'password'=>$password);

	if ( ! @Users ) {
		# user not found.	Let's see if we got the password wrong, or the email wrong.
		if ( @Users = openprint::User::find('email'=>$email) ) {
			$$variable{'information'} = "The password you entered was not correct.	Please try again.";
			openprint::logs::insertLogRecord(78,'Invalid Password', $Users[0]->id() );
		} elsif ( @Users = openprint::User::find('email'=>$email,'deleted'=>1) ) {
			$$variable{'information'} = "\"$email\" Has been deleted.  Please contact us to have your account re-instated.";
			openprint::logs::insertLogRecord(78,'Account Deleted', $Users[0]->id() );
		} else {
			$$variable{'information'} = "\"$email\" is not a valid account.	Please try again.";
			openprint::logs::insertLogRecord(78,'Invalid login: '. $email );
		} # end if
		$$variable{'error'} = 'Authentication Failed.';
		return;
	} # end if
	my $User = @Users[0];

	# Have a valid user now.
	if ( $User->Company()->activation() eq 'N' ) {
		$$variable{'error'} = 'Company not activated.';
		$$variable{'information'} = 'Your company account has not been looked over and activated by an administrator yet. You will be notified when your application has been approved.';
		openprint::logs::insertLogRecord(78,'Company Account Not Activated', $User->id() );
		return;
	} elsif ( $User->Company()->activation() ne 'Y' ) {
		$$variable{'error'} = 'Company Account activation status is unknown.('.$User->Company()->activation().')';
		$$variable{'information'} = 'Please report this error.';
		return;
	} # end if

	# Have a valid user now.
	if ( $User->web_active() eq 'N' ) {
		$$variable{'error'} = "User not activated.";
		$$variable{'information'} = "Applications for existing corporate accounts must be approved by and administrator. You will be notified when you application had been approved.";
		openprint::logs::insertLogRecord(78,'User Account Not Activated', $User->id() );
		return;
	} elsif ( $User->web_active() ne 'Y' ) {
		$$variable{'error'} = "User Account activation status is unknown.";
		$$variable{'information'} = "Please report this error.";
		return;
	} # end if

	if ( $site eq 'E' and ! sets::isin( $User->type, ['E','A'] ) ) {
		$$variable{'error'} = "Not authorised.";
		$$variable{'information'} = "You are not an employee.	You do not have access to the employee site.";
		openprint::logs::insertLogRecord(78,'User not an employee', $User->id() );
		return;
	} elsif ( $site eq 'A' and $User->type() ne 'A' ) {
		$$variable{'error'} = "Not authorised.";
		$$variable{'information'} = "You are not an administrator.	You do not have access to the administrator site.";
		openprint::logs::insertLogRecord(78,'User not an administrator', $User->id() );
		return;
	} # end if

	if ( $User->type() ne 'C' ) {
		if ( $config{'Owner'} and ( $User->company_id() != $config{'Owner'} ) ) {
# Send an email notification
			my %info;
			@info{'UserFirstName','UserLastName','UserEmail'} = $User->get('firstname','lastname','email');
			$info{'Site'} = $site;
			$info{'UserType'} = $User->type();

			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/login_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

			my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
			$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
			my @body = ('', $_, 'text/html', 'quoted-printable');
			my %mail = (
					SMTP	=> $config{'Mail Server'},
					FROM	=> $config{'LoginEmail'},
					TO		=> $config{'LoginEmail'},
					SUBJECT => "Login notification",
					);
			misc::send_email_with_attachment( $log, \%mail, @body );

		} # end if

	} # end if

	@session{'company_id','user_id','email','user_type'} = $User->get('company_id','id','email','type');
	delete $session{'Pricelist_id'};
	openprint::logs::insertLogRecord('2','Success');

	if ( $openprint::param{'rdbRememberMe'} eq 'Y' ) {
		my $Cookie = Apache2::Cookie->new($r,
			-name  => '_session_id',
			-value => $session{_session_id},
			-path		=>	'/',
			);
		$Cookie->expires('+3M');
		$Cookie->bake( $r );
	} # end if	

	if ( $User->changepassword() eq 'Y' ) {
		if ( $site eq 'A' ) {
			$$variable{'Redirect'} = '/administrator/account/change_password.html';
		} elsif ( $site eq 'E' ) {
			$$variable{'Redirect'} = '/employee/account/change_password.html';
		} else {
			$$variable{'Redirect'} = '/account/change_password.html';
		} # end if
		return;
	} elsif ( $session{'Destination'} =~ /^Click <a href="(.*)\.html\??(.*)">here<\/a>/ ) {
     
		$$variable{'Redirect'} = $1.'.html';
		foreach my $p ( split('&', $2 ) ) {
			my ( $k, $v ) = split('=', $p );
			$openprint::log->debug("Psrsmd: $p, $k = $v ");
			$openprint::param{$k} = $v;
		} # end foreach
	} elsif ( $session{'Destination'} =~ /^Click <a href="(.*)\.html\?(.*)">here<\/a> to continue the survey\./ ) {
     
		$$variable{'Redirect'} = $1.'.html';
		foreach my $p ( split('&', $2 ) ) {
			my ( $k, $v ) = split('=', $p );
			$openprint::log->debug("Psrsmd: $p, $k = $v ");
			$openprint::param{$k} = $v;
		} # end foreach
	} # end if

} # sub verify_login

sub logout {
	openprint::logs::insertLogRecord('3',);
	foreach my $k ( keys %session ) {
		next if sets::isin( $k, [ 'Currency_id', '_session_id','Country' ] );
		delete $session{$k};
	} # end foreach
} # sub logout

sub email_password {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $email = lc $openprint::param{'txtEmail2'};

	my @Users = openprint::User::find('email'=>$email);

	if ( ! @Users ) {
		return misc::error( $log, $dbh, $variable, 'Account doesn\'t exist.', 'The account you entered does not exist.' );
	} # end if

	if ( my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' ) ) {
		my %info;
		
		my $content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/forgotten_password.html' );
		foreach my $User ( @Users ) {
			$info{'ReplacementText'} = ssi::variable_substitution( \$content, \%info );
			$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
			my @body = ('', $_, 'text/html', 'quoted-printable');

			my %mail = (
					SMTP	=> $config{'Mail Server'},
					FROM 	=> $config{'AdministratorEmail'},
					TO		=> $openprint::param{'txtEmail2'},
					SUBJECT	=> 'Forgotten Password',
					);
			misc::send_email_with_attachment( $log, \%mail, @body );
		} # end foreach $User
	} else {
		return misc::error( $log, $dbh, $variable, 'System Error.', 'We were unable to email your password to you.	Please contact support.' );
	} # end if
} # sub email_password

sub login_password {
	my ( $r, $log, $dbh, $variable ) = @_;

	$_ = $config{'customerlogin'};
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

	my $User = new openprint::User( $session{'user_id'} );

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

	my $idletime = $config{'idletime'};

	if ( $session{'lastupdated'} and $session{'user_id'} and $idletime and ( time - $session{'lastupdated'} > $idletime ) ) {
		logout( $log, $dbh, $variable, $cookie, $site );
		$$variable{'idletime'} = $idletime;
		$$variable{'Destination'} = misc::get_destination( $r, $r->uri() );
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
