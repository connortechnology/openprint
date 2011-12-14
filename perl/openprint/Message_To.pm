use strict;
package openprint::Message_To;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table %fields %defaults @identified_by );
$debug = 1;
$table = 'message_to';
@identified_by = ( 'message_id', 'user_id' );
%fields = (
	'message_id'	=>	'message_id',
	'user_id'	=>	'user_id',
	'viewed'	=>	'viewed',
	'deleted'	=>	'deleted',
);
%defaults = (
	'viewed'	=>	0,
	'deleted'	=>	0,
);
 1;
__END__
