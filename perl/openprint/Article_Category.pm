package openprint::Article_Category;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $table $serial %fields %defaults %transforms %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

require sql;

$table = 'article_categories';
$serial = 'article_categories_id_seq';

%fields = (
	'id'				=>	'id',
	'name'				=>	'name',
	'position'			=>	'position',
	'permalink'			=>	'permalink',
);

%transforms = (
);
%defaults = (
);

1;

__END__
