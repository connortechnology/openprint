use strict;
package openprint::ZM_Monitor;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );
$debug = 1;
$table = 'Monitors';


%fields = (
	'id'	=>	'Id',
	'name'	=>	'Name',
	'type'	=>	'Type',
	'function'		=>	'Function',
	'enabled'	=>	'Enabled',
	'width'		=>	'Width',
	'height'	=>	'Height',
	'max_fps'	=>	'MaxFPS',
	'alarm_max_fps'	=>	'AlarmMaxFPS',
	'path'			=>	'Path',
	'host'			=>	'Host',
	
	'server_host'	=>	'ServerHost',
);

1;
__END__
