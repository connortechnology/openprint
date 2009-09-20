package openprint::Claim_Content;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

my $debug = 0;

$table = 'manifestcontents';
$serial = 'manifestcontents_id_seq';

%fields = (
	'id'				=>	'id',
	'claim_id'			=>	'claim_id',
	'skid_id'			=>	'skid_id',
	'quantity'			=>	'quantity',
	'reason'			=>	'reason',
);

%transforms = (
	'quantity'	=> [ 's/\D//g' ],
);

%defaults = (
	'quantity'	=> 0,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM Claim_Contents WHERE 1>0';

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
	if ( $params{'id_like'} ) {
		$sql .= " AND id LIKE '%$params{id_like}%'";
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Claim_Content SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Claim_Content loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Claim_Content ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Claim_Content( $_->{id}, $_ ) } @$data;
} # end sub find

sub Skid {
	return new openprint::Skid( $_[0]{skid_id} );
} # end sub Skid

sub Claim {
	return new openprint::Claim( $_[0]{claim_id} );
} # end sub Manifest

1;
__END__
