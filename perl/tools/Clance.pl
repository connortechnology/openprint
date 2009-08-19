#!/usr/bin/perl -w
use WWW::Mechanize;
use Digest::SHA1  qw(sha1_base64);
use CGI qw/:standard/;


my $mech = WWW::Mechanize->new();
$mech->get('http://laylorperformance.squarespace.com/display/configuration/Home');
$mech->submit_form(
        form_name => 'dataform',
        fields    => { 
			'encryptedPassword'		=>	sha1_base64('arWy23q9r8ujD9ND7Xwm'),
			'loginStyle'			=>	'regular',
			'SS_CHAIN_TO_ACTION'	=>	'http://laylorperformance.squarespace.com/display/configuration/Home',
			'username'				=>	'laylorperformance',
			'password'				=>	'arWy23q9r8ujD9ND7Xwm',
		},
    );
$mech->get('http://laylorperformance.squarespace.com/display/configuration/CreateOrModifyMemberAccount');
$mech->submit_form(
        form_name => 'dataform',
        fields    => { 
			'SS_AUTHKEY'	=>	'QAGBOEAZ',
			'filterParameter'	=>	'',
			'login'				=>	$param{'Login'},
			'displayName'		=>	$param{'FirstName'}. ' ' . $param{'LastName'},
			'newPassword'		=>	$param{'Password'},
			'audienceId'		=>	'746468',
			'isPersonalAccount'	=>	'true',
			'isEnabled'			=>	'true',
			'isConfirmed'		=>	'true',
			'sendInvitation'	=>	'false',
			'email'				=>	$param{'Email'},
			'firstName'			=>	$param{'FirstName'},
			'lastName'			=>	$param{'LastName'},
			'title'				=>	'',
			'officeNumber'		=>	'',
			'mobileNumber'		=>	'',
			'homeNumber'		=>	$param{'Phone'},
			'faxNumber'			=>	'',
			'imName'			=>	'',
			
		},
    );
