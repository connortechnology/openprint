use strict;
package openprint::Email_Account;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %transforms %defaults );

$table = 'mailbox';

%fields = (
	'id'		=>	'username',
	'password'	=>	'password',
	'name'		=>	'name',
	'maildir'	=>	'maildir',
	'quota'		=>	'quota',
	'domain'	=>	'domain',
	'created_on'	=>	'created',
	'updated_on'	=>	'modified',
	'active'		=>	'active',
);

1;
__END__
