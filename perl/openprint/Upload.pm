package openprint::Upload;
@ISA = qw( openprint::Object );
use strict;

require openprint::File;

my $debug = 1;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'uploads';
$serial = 'upload_id_seq';
%fields = (
	'id'			=>	'id',
	'company_id'	=>	'company_id',
	'user_id'		=>	'user_id',
	'started_on'	=>	'started_on',
);

sub Files {
	my $self = shift;
	return openprint::File->find('upload_id'=>$$self{id});
} # end sub

1;
__END__

