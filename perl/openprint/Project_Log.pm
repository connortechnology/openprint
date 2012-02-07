use strict;
package openprint::Project_Log;
our @ISA = qw(openprint::Object);

use vars qw( $table $serial %fields %transforms %defaults );

$table = 'project_log';
$serial= 'project_log_id_seq';
%fields = (
	'project_id'		=>	'project_id',
	'company_id'		=>	'company_id',
	'user_id'			=>	'user_id',
	'created_on'		=>	'dtmtimestamp',
	'description'		=>	'description',
);
%transforms = (
);
%defaults = (
);

1;
__END__
