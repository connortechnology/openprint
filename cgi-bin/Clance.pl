#!/usr/bin/perl 
use lib '/etc/apache2/lib/perl';
use WWW::Mechanize;
use Digest::SHA1  qw(sha1_base64);
use CGI qw/:standard/;

use strict;
require sql;
require logger;

if ( ! param('site') ) {
	print STDERR "No site specified.\n";
	exit 1;
} # end if

my $log = logger->new();
$log->{level} = "warn";
my $dbh = sql::open_sql( $log,
		'database'  => 'penultima',
		'driver'    => 'Pg',
		'host'      => '',
		'login'     => 'penultima',
		'password'  => 'penultima',
		);
if ( ! $dbh ) {
	print STDERR "Failed to connect to db.\n";
	exit 1;
} # end if

my ( $data ) = sql::execute( $log, $dbh, 'SELECT data FROM squarespace_settings WHERE site=?', param('site') );
if ( ! $data ) {
	print STDERR "Failed to load data for site ".param('site').".\n";
	exit 1;
} # end if

my %settings = map { split('=',$_) } split(',', $data );

my $mech = WWW::Mechanize->new;

$mech->get("$settings{adminurl}/process/Login?encryptedPassword=$settings{password}&password=&loginStyle=direct&returnUrl=/display/configuration/Home");
$mech->get($settings{adminurl}.'/display/configuration/CreateOrModifyMemberAccount');
if ( 0 ) {
print header;
print $mech->content(base_href =>$settings{'url'});
exit;
}
$mech->submit_form(
        form_name => 'dataform',
        fields    => { 
			#'filterParameter'	=>	'',
			'login'				=>	param('Login'),
			'displayName'		=>	param('FirstName'). ' ' . param('LastName'),
			'newPassword'		=>	param('Password'),
			'audienceId'		=>	$settings{'audienceId'},
			'isPersonalAccount'	=>	'true',
			'isEnabled'			=>	'true',
			'isConfirmed'		=>	'true',
			#'sendInvitation'	=>	'false',
			'email'				=>	param('Email'),
			'firstName'			=>	param('FirstName'),
			'lastName'			=>	param('LastName'),
			'title'				=>	'',
			'officeNumber'		=>	'',
			'mobileNumber'		=>	'',
			'homeNumber'		=>	param('Phone'),
			'faxNumber'			=>	'',
			'imName'			=>	'',
			
		},
    );
my $query = new CGI;
if ( $mech->content() =~ /We were unable/ ) {
	my $params = join('&', map { $_.'='.param($_) } ('Login','FirstName','LastName','Email','Phone','Password') );
	if ( $mech->content() =~ /This login name is already taken/ ) {
		print $query->redirect($settings{'url'}.'/register/?error=logininuse&'.$params );
	} elsif ( $mech->content() =~ /Logins must be between 3-25 characters in length/ ) {
		print $query->redirect($settings{'url'}.'/register/?error=invalidlogin&'.$params );
	} elsif ( $mech->content() =~ /The email address provided is already assigned/ ) {
		print $query->redirect($settings{'url'}.'/register/?error=email&'.$params );
	} elsif ( $mech->content() =~ /The email address you provided is invalid/ ) {
		print $query->redirect($settings{'url'}.'/register/?error=invalidemail&'.$params );
	} elsif ( $mech->content() =~ /You must provide a new password/ ) {
		print $query->redirect($settings{'url'}.'/register/?error=nopassword&'.$params);
	} elsif ( $mech->content() =~ /Your new password must be between 6 and 25 characters./ ) {
		print $query->redirect($settings{'url'}.'/register/?error=invalidpassword&'.$params);
	} else {
		print header;
		print $mech->content(base_href =>'http://www.laylor.com');
	} # end if
	exit;
} # end if
print $query->redirect($settings{'url'}.'/registration-confirmation/');
$dbh->disconnect();

if ( $settings{'infusionsofturl'} ) {
	eval {
		my $mech = WWW::Mechanize->new;
		$mech->get('https://laylorps.infusionsoft.com/');
		$mech->submit_form(
				form_name => 'loginForm',
				fields    => { 
					'username'	=>	$settings{'infusionsoftusername'},
					'password'	=>	$settings{'infusionsoftpassword'},
				} 
		);
		$mech->get('https://laylorps.infusionsoft.com/Contact/add/addPerson.jsp');
		$mech->submit_form(
				form_name	=> 'person',
				fields		=> {
					'Contact0OwnerID'	=>	$settings{'infusionsoft_Contact0OwnerID'},
					'Contact0LeadSourceId'	=>	$settings{'infusionsoft_Contact0LeadSourceId'},
					'Contact0FirstName'	=>	param('FirstName'),
					'Contact0LastName'	=>	param('LastName'),
					'Contact0Phone1'	=>	param('Phone'),
					'Contact0Email'		=>	param('Email'),
				} );
	} # end eval
} # end if

if ( $settings{'notify'} ) {
	require Mail::Sendmail;

	my %email_info = (
		smtp	=> 'localhost',
		From	=> 'squarespace@connortechnology.com',
		To		=> $settings{'notify'},
		Subject	=> 'New user registration at ' . $settings{'url'},
		Body	=>	"
Someone has registered at $settings{url}.  " . ( $settings{'infusionsofturl'} ? 'They should also have been automatically entered into your infusionsoft system.' : '' ) . "

Details are as follows:
FirstName: " . param('FirstName')."
LastName:  " . param('LastName')."
Phone:     " . param('Phone')."
Email:     " . param('Email')."
Login:     " . param('Login')."
		"
	);

	my $res = Mail::Sendmail::sendmail(%email_info);
	unless ($res) {
		my $timestamp = scalar(localtime());
		print STDERR "Clance.pl: $timestamp: error sending email: $Mail::Sendmail::error\n";
	}
} # end if

1;
__END__
