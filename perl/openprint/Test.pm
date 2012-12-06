use strict;
package openprint::Test;
our @ISA = qw(openprint::Object);

use vars qw( $table $serial %fields %transforms %detests );
$table = 'tests';
$serial = 'tests_id_seq';

%fields = ( 
	id	=>	'id',
	name=>	'name',
	description=>	'description',
);
%transforms = (
    name => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
    description => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%detests = ();

1;
__END__
