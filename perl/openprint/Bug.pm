package openprint::Bug;
@ISA = qw( openprint::Object );
require openprint::Object;
use strict;

require openprint::Bug_Comment;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'bugs';
$serial = 'bugs_id_seq';
%fields = (
	'id'			=>	'id',
	'description'	=>	'description',
	'owner_id'		=>	'owner_id',
	'project_id'	=>	'project_id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'user_id'		=>	'user_id',
	'status_id'		=>	'status_id',
);
%transforms = (
);
%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
);

sub destroy {
	foreach my $C ( openprint::Bug_Comment->find('bug_id'=>$_[0]{'id'}) ) {
		$C->destroy();
	} # end foreach C
	return $_[0]->SUPER::destroy();
} # end sub destroy

1;
__END__
