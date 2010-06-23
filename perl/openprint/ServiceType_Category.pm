package openprint::ServiceType_Category;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'ServiceType_Categories';
$serial = 'ServiceType_Categories_id_seq';

%fields = (
	'id'				=>	'id',
	'name'				=> 'name',
	'sorting'			=> 'sorting',
);
%transforms = (
);
%defaults = (
	'sorting'	=>	undef,
);

my $debug = 0;

1;
__END__
