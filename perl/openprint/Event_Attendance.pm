use strict;
require openprint::Event;
require openprint::User;
package openprint::Event_Attendance;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table @identified_by %fields %transforms %defaults );
$debug = 1;
$table = 'event_attendance';
@identified_by = ( 'event_id', 'user_id' );

%fields = (
	'event_id'	=>	'event_id',
	'user_id'	=>	'user_id',
	'attendance'	=>	'attendance',
);

%defaults = (
	'attendance'			=> undef,
);

1;
__END__
