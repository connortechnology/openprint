package openprint::logAction;
@ISA = qw( openprint::Object );
require openprint::Object;

my $debug = 1;
use strict;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'log_Actions';
$serial = 'log_actions_id_seq';

%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'description'	=>	'description',
);
%transforms = (
);
%defaults = (
);

sub find {
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM log_actions WHERE 1>0};
	if ( $params{'id'} ) {
		$sql .= ' AND id=?';
		push @values, $params{'id'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->error("Error loading logAction: ($sql) (@values) reason: " . $dbh->errstr() );
		return;
	} elsif ( $debug ) {
		$log->debug("Loading logAction: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::logAction( $_->{id}, $_ ); } @$data;
} # end sub find

return 1;
__END__
