#!/usr/bin/perl -w
use WWW::Mechanize;
use Digest::SHA1  qw(sha1_base64);
use CGI qw/:standard/;
use strict;

sub error_out {
	print header,
		  start_html('Error'),
		  h1('Error');

foreach my $k ( param() ) {
print " $k => " . param($k) . '<br/>';
}
		  print end_html;
} # end sub error_out

#error_out();

my $mech = WWW::Mechanize->new();

$mech->get('http://laylorperformance.squarespace.com/process/Login?encryptedPassword=vYUF6sJOr3lZ6Vyc9AkDJrt5BZ4%3D&password=&loginStyle=direct&returnUrl=/display/configuration/Home');
if ( 0 ) {
$mech->submit_form(
        form_name => 'dataform',
        fields    => { 
			'encryptedPassword'		=>	sha1_base64('arWy23q9r8ujD9ND7Xwm'),
			'username'				=>	'laylorperformance',
			#'password'				=>	'arWy23q9r8ujD9ND7Xwm',
			'loginStyle'			=>	'regular',
			'SS_CHAIN_TO_ACTION'	=>	'http://laylorperformance.squarespace.com/display/configuration/CreateOrModifyMemberAccount',
		},
    );
}
$mech->get('http://laylorperformance.squarespace.com/display/configuration/CreateOrModifyMemberAccount');
if ( 0 ) {
print header;
print $mech->content(base_href =>'http://www.laylor.com');
exit;
}
$mech->submit_form(
        form_name => 'dataform',
        fields    => { 
			#'filterParameter'	=>	'',
			'login'				=>	param('Login'),
			'displayName'		=>	param('FirstName'). ' ' . param('LastName'),
			'newPassword'		=>	param('Password'),
			'audienceId'		=>	'746468',
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
		print $query->redirect('http://www.laylor.com/register/?error=login&'.$params );
	} elsif ( $mech->content() =~ /The email address provided is already assigned/ ) {
		print $query->redirect('http://www.laylor.com/register/?error=email&'.$params );
	} elsif ( $mech->content() =~ /You must provide a new password/ ) {
		print $query->redirect('http://www.laylor.com/register/?error=password&'.$params);
	} else {
		#print header;
		#print $mech->content(base_href =>'http://www.laylor.com');
	} # end if
	exit;
} # end if
print $query->redirect('http://www.laylor.com/registration-confirmation/');

1;
__END__
