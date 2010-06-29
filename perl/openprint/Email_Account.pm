package openprint::Email_Account;
@ISA = qw( openprint::Object );

use strict;

use openprint ();
require openprint::User;
require email;

use vars qw( $table $serial %fields %transforms %defaults $log $dbh %session %config );
*log = \$openprint::log;
*session = \%openprint::session;
*config = \%openprint::config;

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

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM mailbox WHERE 1>0';
	my @values;

	if ( $params{'active'} ) {
		$sql .= ' AND active = ?';
		push @values, $params{'active'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->debug("openprint::Email::find($sql)" . $dbh->errstr);
	} else {
		return map { new openprint::Email_Account( $_->{username}, $_ ); } @$data;
	} # end if
} # end sub find

sub delete {
	
	#sql::execute( undef, $dbh, 'DELETE FROM mailbox WHERE username=?', $_[0]{'id'} );
} # end sub delete
