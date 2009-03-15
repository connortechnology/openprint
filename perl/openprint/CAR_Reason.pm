package openprint::CAR_Reason;
@ISA = qw(openprint::Object);

use MIME::QuotedPrint;
use MIME::Base64;
use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

use strict;
use vars qw( $table $serial %fields %defaults %transforms );

require sql;

$table = 'car_reasons';
$serial = 'car_reasons_id_seq';

%fields = (
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

	my $sql = q{SELECT * FROM CAR_Reasons WHERE 1>0};
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

	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->warn("Error loading CAR_Reasons: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug) {
		$openprint::log->debug("openprint::CAR_Reason::find($sql) (@values) :" . @$data );
	} # end if
	return map { new openprint::CAR_Reason( $_->{id}, $_ ); } @$data;
} # end sub find

1;
__END__
