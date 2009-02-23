package openprint::logAction;
@ISA = qw( openprint::Object );
require openprint::Object;

my $debug = 1;
use strict;
use Date::Handler;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'log_Actions';
$serial = 

sub find {
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM log_actions WHERE 1>0};
	if ( $params{'id'} ) {
		$sql .= ' AND id=?';
		push @values, $params{'id'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading logAction: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading logAction: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::logAction( $_->{id}, $_ ); } @$data;
} # end sub find

return 1;
__END__
