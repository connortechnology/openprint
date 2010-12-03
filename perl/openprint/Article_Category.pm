use strict;
package openprint::Article_Category;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );

$debug = 1;
$table = 'article_categories';
$serial = 'article_categories_id_seq';

%fields = (
	'id'				=>	'id',
	'name'				=>	'name',
	'description'		=>	'description',
	'position'			=>	'position',
	'permalink'			=>	'permalink',
	'image_filename'	=>	'image_filename',
);

%transforms = (
);
%defaults = (
);

1;
__END__
