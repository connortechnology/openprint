use strict;
package openprint::Project_Log;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'project_log';
$serial= '';
%fields = (
	project_id		=>	'project_id',
	company_id		=>	'company_id',
	user_id			=>	'user_id',
	created_on		=>	'dtmtimestamp',
	description		=>	'description',
);
%transforms = (
);
%defaults = (
	created_on	=>	q`'NOW()'`,
);

1;
__END__
