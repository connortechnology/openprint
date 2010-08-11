package openprint::Usergroup;
@ISA = qw( openprint::Object );
use strict;
require sql;

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );

$debug = 1;

$table = 'usergroups';
$serial = 'usergroups_id_seq';

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
);
%find_fields = (
	'user_id'		=>	'(SELECT user_id FROM users_in_usergroups WHERE usergroup_id=usergroups.id)',
);

%transforms = (
);

%defaults = ( 
);

1;
__END__
