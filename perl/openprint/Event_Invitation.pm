use strict;
require openprint::Event;
require openprint::User;

package openprint::Event_Invitation;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table @identified_by %fields %transforms %defaults );
$debug = 1;
$table = 'event_invitations';
@identified_by = ( 'event_id', 'user_id' );

%fields = (
	'event_id'	=>	'event_id',
	'user_id'	=>	'user_id',
	'created_on'	=>	'created_on',
);

%defaults = (
	'attending'		=> undef,
	'created_on'	=>	q`'NOW()'`,
);

1;
__END__
