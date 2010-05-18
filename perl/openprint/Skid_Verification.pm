package openprint::Skid_Verification;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw($log $dbh %config $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require openprint::User;

my $debug = 1;

$table = 'skid_verifications';
$serial = 'skid_verifications_id_seq';

%fields = (
	'id'			=>	'id',
	'code'			=>	'code',
	'created_on'	=>	'created_on',
	'skid_id'		=>	'skid_id',
	'user_id'		=>	'user_id',
);

%transforms = (
);

%defaults = (
	'created_on'	=>	'NOW()',
);

sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM skid_verifications WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'skid_id'} ) {
		$sql .= ' AND skid_id=?';
		push @values, $params{'skid_id'};
	} # end if
	if ( $params{'code'} ) {
		$sql .= ' AND code=?';
		push @values, $params{'code'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading Skid Verifications SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No Skid Verifications loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded Skid Verifications ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Skid_Verification( $_->{id}, $_ ) } @$data;
} # end sub find

sub User {
	return new openprint::User( $_[0]{'user_id'} );
} # end sub User

1;
__END__
