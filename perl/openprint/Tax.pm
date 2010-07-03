package openprint::Tax;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw($debug $table $serial %fields %transforms %defaults );


$debug = 0;
$table = 'Taxes';
$serial = 'taxes_id_seq';

%fields = (
	'id'				=>	'id',
	'federaltax_rate'	=>	'dblfederalpercent',
	'statetax_rate'		=>	'dblstatepercent',
	'harmonized_rate'	=>	'dblharmonisedpercent',
	'rate'				=>	'rate',
	'state'				=>	'state',
	'country'			=>	'country',
	'name'				=>	'name',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'rate'			=>	[ 's/[^\d\.\-]//g' ],
);

%defaults = (
	'federal'	=>	undef,
	'state'		=>	undef,
	'rate'		=>	undef,
);

1;
__END__
