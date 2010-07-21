package openprint::File;
@ISA = qw( openprint::Object );
use strict;

my $debug = 1;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'project_files';
$serial = 'upload_id_seq';

1;
__END__
