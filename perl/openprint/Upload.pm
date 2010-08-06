package openprint::Upload;
@ISA = qw( openprint::Object );
use strict;

require openprint::File;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'uploads';
$serial = 'upload_id_seq';
%fields = (
	'id'			=>	'id',
	'start'			=>	'start',
	'size'			=>	'size',
	'total'			=>	'total',
	'finished'		=>	'finished',
	'company_id'	=>	'company_id',
	'user_id'		=>	'user_id',
	'file_path'		=>	'file_path',
	'company'		=>	'company',
);
%defaults = (
	'start'	=>	'NOW()',
	'size'	=>	undef,
	'total'	=>	undef,
	'finished'	=>	0,
);

sub Files {
	my $self = shift;
	return openprint::File->find('upload_id'=>$$self{id});
} # end sub

1;
__END__
