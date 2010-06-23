package openprint::LabelType;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

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

$table = 'labeltypes';
$serial = 'labeltypes_id_seq';
%fields = (
	'id'			=>	'id',
	'name'		=>	'name',
);

%transforms = (
);

%defaults = (
);

1;
__END__
