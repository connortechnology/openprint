use strict;
package openprint::File;
our @ISA = qw( openprint::Object );

use openprint ();
use vars qw( $log $dbh $debug $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;

$debug = 1;
$table = 'project_files';
$serial = 'project_files_id_seq';
%fields = (
		'project_id'	=>	'project_id',
		'filename'		=>	'filename',
		'description'	=>	'description',
		'id'			=>	'id',
		'upload_id'		=>	'upload_id',
		'size'			=>	'size',
		'deleted'		=>	'deleted',
		'archive'		=>	'archive',
		);
%transforms = (
);
%defaults = (
);

sub size_text {
	my ( $self ) = @_;
	return misc::format_bytes( $$self{'size'} );
} #end sub size_text

1;
__END__
