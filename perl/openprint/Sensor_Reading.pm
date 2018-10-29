use strict;
package EnviroTrack::Sensor_Reading;
our @ISA = qw( EnviroTrack::Object );

require EnviroTrack::sql;
require EnviroTrack::Object;

use EnviroTrack ();
use vars qw( $debug %fields %find_fields %transforms %defaults $table $serial $AUTOLOAD $default_sort );
$table = 'sensor_readings';
$serial = 'sensor_readings_id_seq';

$debug = 0;

%fields = (
	id			=>	'id',
	taken	=>	'taken',
	sensor_input_id		=>	'sensor_input_id',
	value		=>	'value',
); # end %fields

%find_fields = (
);

%transforms = (
	id			=>	[ 's/\D//g' ],
	value			=>	[ 's/[^\d\.\-]//g' ],
	sensor_input_id	=>	[ 's/\D//g' ],
	taken	=>	[ 's/.*//g' ],
);

%defaults = (
	taken				=>	q`'NOW()'`,
);

sub Sensor_Input {
	if ( ! $_[0]{Sensor_Input} ) {
		$_[0]{Sensor_Input} = new EnviroTrack::Sensor_Input( $_[0]{sensor_input_id} );
	}
	return $_[0]{Sensor_Input};
}

sub Sensor {
	return $_[0]->Sensor_Input()->Sensor();
}
1;
__END__
