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
	'id'				=>	'id',
	'federaltax_rate'	=>	'federaltax',
	'statetax_rate'		=>	'statetax',
	'harmonizedtax_rate'	=>	'harmonizedtax',
	'state'				=>	'state',
	'country'			=>	'country',
);

%transforms = (
	'id'					=>	[ 's/\D//g' ],
	'federaltax_rate'		=>	[ 's/[^\d\.]//g' ],
	'statetax_rate'			=>	[ 's/[^\d\.]//g' ],
	'harmonizedtax_rate'	=>	[ 's/[^\d\.]//g' ],
);

%defaults = (
	'federaltax_rate'		=>	undef,
	'statetax_rate'			=>	undef,
	'harmonizedtax_rate'	=>	undef,
);

1;
__END__
