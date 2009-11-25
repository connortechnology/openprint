package openprint::Tax;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %session $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

require sql;

my $debug = 1;

$table = 'Taxes';
$serial = 'taxes_id_seq';

%fields = (
	'id'				=>	'id',
	'federaltax_rate'	=>	'federaltax',
	'statetax_rate'		=>	'statetax',
	'harmonizedtax_rate'	=>	'harmonizedtax',
	'state'				=>	'state',
	'country'			=>	'country',
);

%transforms = (
	'id'					=>	[ 's/\D//g' ],
	'federaltax_rate'		=>	[ 's/[^\d\.]//g' ],
	'statetax_rate'			=>	[ 's/[^\d\.]//g' ],
	'harmonizedtax_rate'	=>	[ 's/[^\d\.]//g' ],
);

%defaults = (
	'federaltax_rate'		=>	undef,
	'statetax_rate'			=>	undef,
	'harmonizedtax_rate'	=>	undef,
);

my %find_cache;
# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my $hash_key = join(';',map { $_, ref $params{$_} eq 'HASH' ? join(';',%{$params{$_}}) :$params{$_} } sort keys %params );
	return @{$find_cache{$hash_key}} if $find_cache{$hash_key};

#$openprint::log->debug("Hash key: $hash_key");
	my @values;
	my $sql = 'SELECT * FROM Taxes WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( exists $params{'state'} ) {
		$sql .= ' AND state=?';
		push @values, $params{'state'};
	} # end if
	if ( exists $params{'country'} ) {
		$sql .= ' AND country=?';
		push @values, $params{'country'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Taxes SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Taxs loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Taxs ($sql) (@values) records:" . @$data );
	} # end if
	@{$find_cache{$hash_key}} = map { new openprint::Tax( $_->{id}, $_ ) } @$data;
	return @{$find_cache{$hash_key}};
} # end sub find

1;
#__END__
