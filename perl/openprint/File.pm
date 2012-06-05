use strict;
package openprint::File;
our @ISA = qw( openprint::Object );
require misc;

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
	'company_id'	=>	'company_id',
	'archive'		=>	'archive',

%transforms = (
);
%defaults = (
	'deleted'		=>	0,
	'company_id'	=>	undef,
	'project_id'	=>	undef,
	'upload_id'		=>	undef,
);

sub size_text {
	my ( $self ) = @_;
	return misc::format_bytes( $$self{'size'} );
} #end sub size_text

1;
__END__
