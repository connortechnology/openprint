package openprint::Tax;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %session $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

require sql;

my $debug = 1;

$table = 'Taxes';
$serial = 'taxes_id_seq';

%fields = (
	'id'			=>	'id',
	'rate'			=>	'rate',
	'state'			=>	'state',
	'country'		=>	'country',
	'period_start'	=>	'period_start',
	'period_end'	=>	'period_end',
	'name'			=>	'name',
);

%transforms = (
	'id'					=>	[ 's/\D//g' ],
	'rate'		=>	[ 's/[^\d\.]//g' ],
);

%defaults = (
	'rate'		=>	undef,
	'period_start'	=>	undef,
	'period_end'	=>	undef,
);

1;
__END__
