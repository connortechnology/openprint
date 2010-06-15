package openprint::CAR_Reason;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

use strict;
use vars qw( $table $serial %fields %defaults %transforms );

require sql;

$table = 'car_reasons';
$serial = 'car_reasons_id_seq';

%fields = (
	'id'		=>	'id',
	'name'		=> 'name',
	'deleted'	=> 'deleted',
	'sorting'	=>	'sorting',
);

%transforms = (
);
%defaults = (
	'deleted'		=> 0,
);

1;
__END__
