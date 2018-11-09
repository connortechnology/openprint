use strict;
package EnviroTrack::Sensor;
our @ISA = qw( EnviroTrack::Object );

require EnviroTrack::sql;
require EnviroTrack::Object;
#require EnviroTrack::Sensor_in_SensorGroup;

use EnviroTrack ();
use vars qw( $debug %fields %find_fields %transforms %defaults $table $serial $AUTOLOAD $default_sort );
$table = 'sensors';
$serial = 'sensors_id_seq';

$debug = 0;

%fields = (
	id			=>	'id',
	name		=>	'name',
	description	=>	'description',
	url			=>	'url',
	username	=>	'username',
	password	=>	'password',
	created		=>	'created',
	modified	=>	'modified',
	type_id		=>	'type_id',
); # end %fields

%find_fields = (
);

%transforms = (
	id			=>	[ 's/\D//g' ],
	name		=>	[ 's/^\s+//', 's/\s+$//' ],
	password	=>	[ 's/^\s+//', 's/\s+$//' ],
	created		=>	[ 's/.*//g' ],
	modified	=>	[ 's/.*//g' ],
);

%defaults = (
	created				=>	q`'NOW()'`,
	modified			=>	q`'NOW()'`,
	#deleted					=>	0,
);

sub link_to {
    return sprintf('<a href="/account/view.html?user_id=%1$d">%2$s</a>', $_[0]{id}, @_ > 1 ? $_[1] : $_[0]->name() );
} # end sub link_to

sub type {
	if ( ! $_[0]{Type} ) {
		$_[0]->Type();
		$_[0]{type} = $_[0]{Type}->name();
	}
	return $_[0]{type};
}

sub Type {
	if ( ! $_[0]{Type} ) {
		require EnviroTrack::Sensor_Type;
		$_[0]{Type} = new EnviroTrack::Sensor_Type( $_[0]{type_id} );
	}
	return $_[0]{Type};
}

sub find {
	my @Sensors = $_[0]->SUPER::find();
	my @results;
	foreach my $S ( @Sensors ) {
		if ( ! $S->type() ) {
			$EnviroTrack::log->error("No type in Sensor" . $S->to_string() );
			next;
		}
		# can we re-bless?
		require "EnviroTrack/Sensor/$$S{type}.pm";
		push @results, "EnviroTrack::Sensor::$$S{type}"->new($$S{id}, $S);
	}
	return @results;
} # end sub find

sub Inputs {
	require EnviroTrack::Sensor_Input;
	if ( ! $_[0]{Inputs} ) {
		$_[0]{Inputs} = [ EnviroTrack::Sensor_Input->find( sensor_id=>$_[0]{id} ) ];
	}
	return @{$_[0]{Inputs}};
}

1;
__END__
