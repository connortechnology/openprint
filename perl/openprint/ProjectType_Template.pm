package openprint::ProjectType_Template;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %session $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

require sql;
require ssi;
require misc;

my $debug = 1;

$table = 'projecttemplate';
$serial = 'projecttemplate_id_seq';

%fields = (
	'id'				=>	'id',
	'projecttype_id'	=>	'projecttype_id',
	'type'				=>	'type',
	'description'		=>	'description',
	'finished_width'	=>	'dblfinishedwidth',
	'finished_height'	=>	'dblfinishedheight',
	'flat_width'		=>	'dblflatwidth',
	'flat_height'		=>	'dblflatheight',
);

%transforms = (
	'id'				=>	[ 's/\D//g' ],
	'finished_width'	=>	[ 's/[^\.\d]//g' ],
	'finished_height'	=>	[ 's/[^\.\d]//g' ],
	'flat_width'		=>	[ 's/[^\.\d]//g' ],
	'flat_height'		=>	[ 's/[^\.\d]//g' ],
);

%defaults = (
);

1;
__END__
