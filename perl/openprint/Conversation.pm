use strict;
package openprint::Converation;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );
$debug = 1;
$table = 'conversations';
$serial = 'conversations_id_seq';

%fields = (
	'id'    		=>  'id',
	'subject'		=>	'subject',
	'created_on'	=>	'created_on',
	'created_by'	=>	'created_by',
);
%find_fields = (
);
%transforms = (
    'subject' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'created_by'	=>	q`$session{'user_id'}`,
);

 1;
__END__
