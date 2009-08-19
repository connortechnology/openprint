package openprint::PAR_Area;
@ISA = qw(openprint::Object);

my $debug = 1;

use strict;
use vars qw( $table $serial %fields %defaults %transforms $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;

$table = 'par_areas';
$serial = 'par_areas_id_seq';

%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
	'assignee_id'	=>	'assignee_id',
	'deleted'	=>	'deleted',
	'sorting'	=>	'sorting',
);

%transforms = (
);
%defaults = (
	'deleted'		=> 0,
);

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM PAR_Areas WHERE 1>0};
	my @values;

	if ( exists $params{'deleted'} ) {
		$sql .= ' AND deleted=?';
		push @values, $params{'deleted'};
	} else {
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->warn("Error loading PAR_Areas: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug ) {
		$openprint::log->debug("openprint::PAR_Area::find($sql) (@values) :" . @$data );
	} # end if
	return map { new openprint::PAR_Area( $_->{id}, $_ ); } @$data;
} # end sub find

1;
__END__
