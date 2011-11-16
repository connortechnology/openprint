use strict;
require openprint::Object_Type;
require openprint::Object;
package openprint::Keyword;
our @ISA=('openprint::Object');


use vars qw ( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
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
$debug = 1;
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
sub object_type {
	if ( @_ > 1 ) {
		my $Type = openprint::Object_Type->find_one('name lc'=> lc (openprint::Object_Type->transform( 'name', $_[1] ) ) );
		if ( ! $Type ) {
			$Type = new openprint::Object_Type();
			$Type->save({'name'=>$_[1], 'human'=>$_[1]});
		} # end if
		$_[0]{'object_type'} = $Type->name();
		$_[0]{'object_type_id'} = $Type->id();
	} # end if
	if ( ! $_[0]{'object_type'} ) {
		$_[0]{'object_type'} = new openprint::Object_Type( $_[0]{'object_type_id'} )->name();
	} # end if
	return $_[0]{'object_type'};
} # end sub object_type

1;
__END__
