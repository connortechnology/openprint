package openprint::CIP3_PPF;
@ISA = qw(openprint::Object);

use strict;

require sql;
require openprint::Object;
use openprint ();

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'CIP3_PPF';
$serial = 'CIP3_PPF_id_seq';
%fields = (
	'id'			=>	'id',
	'created_on'	=>	'created_on',
	'data'			=>	'data',
	'signature'		=>	'signature',
	'side'			=>	'side',
	'docket'		=>	'docket',
);
%defaults = (
	'created_on'	=>	'NOW()',
);
%transforms = (
	'signature'		=> [ 's/\D//g' ],
);
sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM ' . $table . ' WHERE 1>0';
	my @values;

	if ( $params{'docket'} ) {
		$sql .= ' AND docket=?';
		push @values, $params{'docket'};
	} # end if

	$sql .= " ORDER BY $params{order}" if $params{'order'};
	$sql .= " LIMIT $params{limit}" if $params{'limit'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->debug("openprint::CIP3_PPF::find( $sql)" . $dbh->errstr);
	} else {
		return map { new openprint::CIP3_PPF( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

1;

__END__
~       
