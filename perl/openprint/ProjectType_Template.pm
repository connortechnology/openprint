use strict;
package openprint::ProjectType_Template;
our @ISA = qw(openprint::Object);
require openprint::Object;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;

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
'finished_width'	=> undef,
'finished_height'	=> undef,
'flat_width'	=> undef,
'flat_height'	=> undef,
);

1;
__END__
