use strict;
package openprint::logAction;
our @ISA = qw( openprint::Object );
require openprint::Object;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'log_Actions';
$serial = 'log_actions_id_seq';

%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'description'	=>	'description',
);
%transforms = (
);
%defaults = (
);

return 1;
__END__
