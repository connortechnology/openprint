use strict;
package openprint::RMA_Status;
our @ISA = qw(openprint::Object);

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'rma_statuses';
$serial = 'rma_statuses_id_seq';

%fields = ( 
	id		=>	'id',
	text	=>	'text',
);
%transforms = (
    text => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = ();

1;
__END__
