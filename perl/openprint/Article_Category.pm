package openprint::Article_Category;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );

$debug = 1;
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
