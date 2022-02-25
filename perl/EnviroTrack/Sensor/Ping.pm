use strict;
package EnviroTrack::Sensor::Ping;
our @ISA = qw( EnviroTrack::Sensor openprint::Object );

require sql;
require openprint::Object;

use vars  qw( $table %fields $serial );
$table = 'sensors';
%fields = (
	path => 'path',
	type	=> 'type',
);

sub sensors {

	my @sensors;
	foreach my $sensor ( glob '/sys/class/hwmon/*' ) {
		push @sensors, $sensor;
	}
}

sub inputs {
	# Get a list of available inputs
	my @inputs;
	foreach my $inputs ( glob '/sys/class/hwmon/'.$_[0]{path}.'/*_input' ) {
		my ( $input_name ) = $inputs =~ /^\/sys\/class\/hwmon\/(\w+)_input$/;

		push @inputs, $input_name;
	}
}

sub take_reading {
	my @Inputs = $_[0]->Inputs();
	my @Readings;
	
	foreach my $Input ( @Inputs ) {
	
		
		my $Reading= $Input->take_reading();
		
	} # end foreach input
}

1;
__END__
