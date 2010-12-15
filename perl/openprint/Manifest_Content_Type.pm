package openprint::Manifest_Content_Type;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config $debug $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require openprint::Manifest;

$debug = 1;

$table = 'manifest_content_types';
$serial = 'manifest_content_types_id_seq';

%fields = (
	'id'			=>	'id',
	'cost'			=>	'cost',
	'docket'		=>	'docket',
	'po_id'			=>	'po_id',
	'manifest_id'	=>	'manifest_id',
	'paper_id'		=>	'paper_id',
	'supplier_invoice'	=>	'supplier_invoice',
);

%transforms = (
	'paper_id'		=> [ 's/\D//g' ],
	'po_id'		=> [ 's/\D//g' ],
	'docket'	=> [ 's/\D//g' ],
	'cost'		=> [ 's/[^\d\.]//g' ],
);

%defaults = (
	'cost'		=>	undef,
	'docket'	=>	undef,
	'po_id'		=>	undef,
	'paper_id'	=>	undef,
);

sub Paper {
	return new openprint::Paper( $_[0]{'paper_id'} );
} # end sub Paper

sub Manifest {
	return new openprint::Manifest( $_[0]{'manifest_id'} );
} # end sub Manifest

1;
__END__
