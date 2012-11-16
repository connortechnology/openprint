use strict;
package openprint::File;
our @ISA = qw( openprint::Object );
require misc;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'project_files';
$serial = 'project_files_id_seq';
%fields = (
	id			=>	'id',
	project_id	=>	'project_id',
	filename	=>	'filename',
	description	=>	'description',
	upload_id	=>	'upload_id',
	deleted		=>	'deleted',
	size		=>	'size',
	company_id	=>	'company_id',
	archive		=>	'archive',
);
%transforms = (
    filename => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	deleted		=>	0,
	company_id	=>	undef,
	project_id	=>	undef,
	upload_id	=>	undef,
	size		=>	undef,
);

sub size_text {
	return misc::format_bytes( $_[0]{size} );
} #end sub size_text

1;
__END__
