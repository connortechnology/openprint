use strict;
package EnviroTrack::Sensor_Type;
our @ISA = qw( openprint::Object );

require openprint::Object;
require openprint;

use vars qw( $debug %fields %find_fields %transforms %defaults $table $serial $AUTOLOAD $default_sort );
$table = 'sensor_types';
$serial = 'sensor_types_id_seq';

$debug = 0;

%fields = (
	id			=>	'id',
	name		=>	'name',
); # end %fields

%find_fields = (
);

%transforms = (
	id			=>	[ 's/\D//g' ],
	name		=>	[ 's/^\s+//', 's/\s+$//' ],
);

%defaults = (
);

1;
__END__
