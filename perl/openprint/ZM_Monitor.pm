use strict;
package openprint::ZM_Monitor;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );
$debug = 0;
$table = 'Monitors';

%fields = (
	'id'			=>	'Id',
	'name'			=>	'Name',
	'type'			=>	'Type',
	'function'		=>	'Function',
	'enabled'		=>	'Enabled',
	'width'			=>	'Width',
	'height'		=>	'Height',
	'max_fps'		=>	'MaxFPS',
	'alarm_max_fps'	=>	'AlarmMaxFPS',
	'path'			=>	'Path',
	'jpg_path'		=>	'JPGPath',
	'mjpeg_path'	=>	'MJPGPath',
	'host'			=>	'Host',
	'server_host'	=>	'ServerHost',
	public			=>	'public',
	protocol		=>	'Protocol',
	method			=>	'Method',

);

sub source_stream_url {
	return ($_[0]{'type'} eq 'Remote' and $_[0]{protocol} eq 'http' ) ? 'http://'.$_[0]{'host'}.$_[0]{'path'} :
                          sprintf('http://%2$s/cgi-bin/zms?mode=jpeg&amp;monitor=%1$d&amp;maxfps=%3$d&amp;user=all',
                              $_[0]{'id'}, $_[0]{'server_host'}.'.internal.point-one.com', int($_[0]{'max_fps'}) ? $_[0]{'max_fps'} : 1 );
} # end sub source_stream_url

sub source_snapshot_url {
	return $_[0]{'type'} eq 'Remote' ? 'http://'.$_[0]{'host'}.($_[0]{'jpg_path'}?$_[0]{'jpg_path'}:$_[0]{'path'}) :
                          sprintf('http://%2$s/cgi-bin/zms?mode=single&amp;monitor=%1$d&amp;maxfps=%3$d&amp;user=all',
                              $_[0]{'id'}, $_[0]{'server_host'}, $_[0]{'max_fps'} );
} # end sub source_snapshot_url

sub can_view {
return 1 if $_[0]{public};
return 1 if $openprint::session{user_type} eq 'A';
return 0;
} # end sub can_view

1;
__END__
