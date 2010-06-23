package openprint::Claim_ContentType;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

my $debug = 1;

$table = 'Claim_ContentTypes';
$serial = 'Claim_ContentTypes_id';
%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
);

%transforms = (
);

%defaults = (
);

1;
__END__
