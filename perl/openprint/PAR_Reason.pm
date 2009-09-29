package openprint::PAR_Reason;
@ISA = qw(openprint::Object);

my $debug = 1;

use strict;
use vars qw( $table $serial %fields %defaults %transforms $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;

$table = 'par_reasons';
$serial = 'par_reasons_id_seq';

%fields = (
	'id'		=>	'id',
	'name'		=> 'name',
	'deleted'	=> 'deleted',
	'sorting'	=>	'sorting',
);

%transforms = (
);
%defaults = (
	'deleted'		=> 0,
);

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM PAR_Reasons WHERE 1>0};
	my @values;

	if ( exists $params{'deleted'} ) {
		$sql .= ' AND deleted=?';
		push @values, $params{'deleted'};
	} else {
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if
	if ( $params{'area_id'} ) {
		$sql .= ' AND area_id=?';
		push @values, $params{'area_id'};
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->warn("Error loading PAR_Reasons: ($sql) (@values)" . $dbh->errstr );
		return;
	} elsif ($debug) {
		$log->debug("openprint::PAR_Reason::find($sql) (@values) :" . @$data );
	} # end if
	return map { new openprint::PAR_Reason( $_->{id}, $_ ); } @$data;
} # end sub find

1;
__END__
