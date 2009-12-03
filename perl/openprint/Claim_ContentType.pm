package openprint::Claim_ContentType;
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

my $debug = 1;

$table = 'Claim_ContentTypes';
$serial = 'Claim_ContentTypes_id';
%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
);

%transforms = (
);

%defaults = (
);

my %find_cache;
# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my $hash_key = join(';',map { $_, ref $params{$_} eq 'HASH' ? join(';',%{$params{$_}}) :$params{$_} } sort keys %params );
	return @{$find_cache{$hash_key}} if $find_cache{$hash_key};
	my @values;
	my $sql = 'SELECT * FROM '.$table.' WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading $table SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Claim_ContentTypes loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Claim_ContentTypes ($sql) (@values) records:" . @$data );
	} # end if
	@{$find_cache{$hash_key}} = map { new openprint::Claim_ContentType( $_->{id}, $_ ) } @$data;
	return @{$find_cache{$hash_key}};
} # end sub find

sub delete {
	my $self = shift;
    sql::execute( undef, undef, 'DELETE FROM '.$table.' WHERE id=?', $$self{'id'} );
} # end sub delete

1;
__END__
