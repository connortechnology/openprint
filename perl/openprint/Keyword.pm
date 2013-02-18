use strict;
require openprint::Object_Type;
require openprint::Object;
package openprint::Keyword;
our @ISA=('openprint::Object');


use vars qw ( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'keywords';
$serial = 'keywords_id_seq';
%fields = (
	'id'	=>	'id',
	'word'	=>	'word',
);
%transforms = (
	'name' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+$/ /g', 'tr/[A-Z]/[a-z]/' ],
);

package openprint::Object_Keyword;
our @ISA=('openprint::Object');
use vars qw ( $debug $table %fields %find_fields %transforms %defaults @identified_by );
$debug = 0;
$table = 'object_keywords';
@identified_by = ( 'object_type_id', 'object_id', 'keyword_id' );

%fields = (
	'object_id'		=>	'object_id',
	'object_type_id'	=>	'object_type_id',
	'object_type'		=>	undef,
	'keyword_id'	=>	'keyword_id',
);
%find_fields = (
	'object_type'	=>	'(SELECT name FROM object_types WHERE id=object_type_id)',
);

sub word {
	return $_[0]->Keyword()->word();
} # end sub word

sub Keyword {
	return new openprint::Keyword( $_[0]{'keyword_id'} );
} # end sub Keyword

1;
__END__
