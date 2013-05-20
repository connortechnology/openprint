use strict;
package Configuration;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table @identified_by %fields %transforms %defaults );
$debug = 1;
$table = 'configuration';
@identified_by = ( 'name' );

%fields = ( 
	name		=>	'name',
	value		=>	'value',
	type		=>	'type',
	category	=>	'category',
	description	=>	'description',
);
%transforms = (
    name => [ 's/\s/_/g' ],
    description => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
    category => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
    value => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = ();

1;
__END__
