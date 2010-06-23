package openprint::PAR_Area;
@ISA = qw(openprint::Object);

my $debug = 1;

use strict;
use vars qw( $table $serial %fields %defaults %transforms $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;

$table = 'par_areas';
$serial = 'par_areas_id_seq';

%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
	'assignee_id'	=>	'assignee_id',
	'deleted'	=>	'deleted',
	'sorting'	=>	'sorting',
);

%transforms = (
);
%defaults = (
	'deleted'		=> 0,
);


1;
__END__
