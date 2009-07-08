package openprint::PaymentType;
@ISA = qw(openprint::Object);

use strict;

require sql;
use openprint ();
use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'paymenttypes';
$serial = 'paymenttypes_id_seq';

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'description'	=>	'description',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
);
my $debug = 1;

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM PaymentTypes WHERE 1>0';
	my @values;

	if ( $params{'name'} ) {
		$sql .= ' AND name=?';
		push @values, $params{'name'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->debug("openprint::PaymentType::find( $sql)" . $dbh->errstr);
		return;
	} elsif ( $debug ) {
		$log->debug("openprint::PaymentType::find($sql) (@values) : " . @$data );
	} # end if
	return map { new openprint::PaymentType( $_->{id}, $_ ); } @$data;
} # end sub find

1;

__END__
~       
