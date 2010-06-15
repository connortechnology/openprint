package openprint::Usergroup;
@ISA = qw( openprint::Object );
use strict;
require sql;

use vars qw( $table $serial %fields %transforms %defaults );

my $debug = 1;

$table = 'usergroups';
$serial = 'usergroups_id_seq';

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
);

%transforms = (
);

%defaults = ( 
);

1;
__END__
