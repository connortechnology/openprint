package openprint::logAction;
@ISA = qw( openprint::Object );
require openprint::Object;

my $debug = 1;
use strict;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

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

1;
__END__
