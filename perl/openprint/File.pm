package openprint::File;
@ISA = qw( openprint::Object );
use strict;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'project_files';
$serial = 'project_files_id_seq';
%fields = (
	'id'	=>	'id',
	'project_id'	=>	'project_id',
	'filename'		=>	'filename',
	'description'	=>	'description',
	'upload_id'		=>	'upload_id',
	'deleted'		=>	'deleted',
	'size'			=>	'size',
);
%defaults = (
	'deleted'		=>	0,
);

1;
__END__
