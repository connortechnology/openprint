use strict;
package openprint::Bug;
our @ISA = qw( openprint::Object );
require openprint::Object;

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
	'company_id'	=>	'company_id',
);
%transforms = (
);
%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'user_id'		=>	q`$session{'user_id'}`,
	'owner_id'		=>	q`$config{'owner_id'}`,
	'company_id'	=>	q`$session{'company_id'}`,
);

sub destroy {
	foreach my $C ( openprint::Bug_Comment->find('bug_id'=>$_[0]{'id'}) ) {
		$C->destroy();
	} # end foreach C
	return $_[0]->SUPER::destroy();
} # end sub destroy

1;
__END__
