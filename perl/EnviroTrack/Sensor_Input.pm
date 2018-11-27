use strict;
package EnviroTrack::Sensor_Input;
our @ISA = qw( openprint::Object );

require sql;
require openprint::Object;
require EnviroTrack::Sensor;
require EnviroTrack::Sensor_Reading;

use vars qw( $debug %fields %find_fields %transforms %defaults $table $serial $AUTOLOAD $default_sort );
$table = 'sensor_inputs';
$serial = 'sensor_inputs_id_seq';

$debug = 0;

%fields = (
	id			=>	'id',
	name		=>	'name',
	label		=>	'label',
  #created		=>	'created',
  #modified	=>	'modified',
	sensor_id	=>	'sensor_id',
  min       =>  'min',
  max       =>  'max',
); # end %fields

%find_fields = (
);

%transforms = (
	id			=>	[ 's/\D//g' ],
	name		=>	[ 's/^\s+//', 's/\s+$//' ],
	label		=>	[ 's/^\s+//', 's/\s+$//' ],
	min			=>	[ 's/[\d\.\-]//g' ],
	max			=>	[ 's/[\d\.\-]//g' ],
  #created		=>	[ 's/.*//g' ],
  #modified	=>	[ 's/.*//g' ],
);

%defaults = (
  #created				=>	q`'NOW()'`,
  #modified			=>	q`'NOW()'`,
	#deleted					=>	0,
  min    =>  undef,
  max    =>  undef,
);

sub take_reading {
	my $Sensor = $_[0]->Sensor();

	my $input_file = $Sensor->url().'/'.$_[0]{name} . '_input';
	my $content;
    open(my $fh, '<', $input_file) or die "cannot open file $input_file";
    {
        local $/;
        $content = <$fh>;
    }
    close($fh);

	my $Reading = new EnviroTrack::Sensor_Reading();
	$Reading->save({
		sensor_input_id	=>	$_[0]{id},
		value	=>	$content,
	});
}
1;
__END__
