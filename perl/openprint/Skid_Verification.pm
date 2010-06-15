package openprint::Skid_Verification;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw($log $dbh %config $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require openprint::User;

my $debug = 1;

$table = 'skid_verifications';
$serial = 'skid_verifications_id_seq';
%fields = (
	'id'			=>	'id',
	'code'			=>	'code',
	'created_on'	=>	'created_on',
	'skid_id'		=>	'skid_id',
	'user_id'		=>	'user_id',
);

%transforms = (
);

%defaults = (
	'created_on'	=>	'NOW()',
);

sub User {
	return new openprint::User( $_[0]{'user_id'} );
} # end sub User

1;
__END__
