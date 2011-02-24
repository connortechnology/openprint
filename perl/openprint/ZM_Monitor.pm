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

sub source_stream_url {
	return $_[0]{'type'} eq 'Remote' ? $_[0]{'host'}.$_[0]{'path'} :
                          sprintf('http://%2$s.internal.point-one.com/cgi-bin/zms?mode=jpeg&amp;monitor=%1$d&amp;maxfps=%5$d',
                              $_[0]{'id'}, $_[0]{'server_host'}, $_[0]{'max_fps'} );
} # end sub source_stream_url

sub source_snapshot_url {
	return $_[0]{'type'} eq 'Remote' ? $_[0]{'host'}.$_[0]{'path'} :
                          sprintf('http://%2$s.internal.point-one.com/cgi-bin/zms?mode=single&amp;monitor=%1$d&amp;maxfps=%5$d',
                              $_[0]{'id'}, $_[0]{'server_host'}, $_[0]{'max_fps'} );
} # end sub source_snapshot_url
1;
__END__
