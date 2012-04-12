use strict;
require openprint::Company;
require openprint::User;

package openprint::Credit_Application;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );

$debug = 1;

$table = 'creditapplications';
$serial = 'lngCreditAppIndex_seq';

%fields = (
	'id'					=>	'id',
	'user_id'				=>	'user_id',
	'company_id'			=>	'company_id',
	'signature'				=>	'strsignature',
	'financialstatementavailable'	=>	'ysnfinancialstatementavailable',
	'firstordervalue'		=>	'strfirstordervalue',
	'annualpurchases'		=>	'strannualpurchases',
	'desired_limit'			=>	'dblcreditlimit',
	'desired_terms'			=>	'lngterms',
	'accountspayablecontact'	=>	'straccountspayablecontact',
	'created_on'			=>	'dtmcreationdate',
	'status'				=>	'strstatus',
	'granted_terms'			=>	'lnggrantedterms',
	'granted_limit'			=>	'dblgrantedcreditlimit',
	'granted_downpayment'	=>	'dblgranteddownpayment',
	'granted_cod'			=>	'grantedcod',

);

%transforms = (
    'signature' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	'granted_terms'	=>	[ 's/\D//g' ],
	'desired_terms'	=>	[ 's/\D//g' ],
	'granted_limit'	=>	[ 's/[^\d\.]//g' ],
	'desired_limit'	=>	[ 's/[^\d\.]//g' ],
	'granted_downpayment'	=>	[ 's/[^\d\.]//g' ],
	'granted_cod'	=>	[ 's/[^\d\.]//g' ],

);
%defaults = (
	'created_on'	=>	'NOW()',
	'desired_terms'	=>	undef,
	'desired_limit'	=>	undef,
	'granted_terms'	=>	undef,
	'granted_limit'	=>	undef,
	'granted_cod'	=>	undef,
	'granted_downpayment'	=>	undef,
);

sub Company {
	return new openprint::Company( $_[0]{'company_id'} );
} # end sub Company

sub User {
	return new openprint::User( $_[0]{'user_id'} );
} # end sub User
1;
__END__
