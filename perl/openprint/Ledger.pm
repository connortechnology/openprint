package openprint::Ledger;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %session $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

require sql;
require ssi;
require misc;

my $debug = 0;

$table = 'Ledgers';
$serial = 'ledgers_id_seq';

%fields = (
	'id'				=>	'id',
	'owner_id'			=>	'owner_id',
	'payor_id'			=>	'payor_id',
	'memo'				=>	'memo',
	'credit'			=>	'credit',
	'debit'				=>	'debit',
	'payment_id'		=>	'payment_id',
	'created_on'		=>	'created_on',
	'total'				=>	'total',
	'occurred_on'		=>	'occurred_on',
	'currency_id'		=>	'currency_id',
	'account_id'		=>	'account_id',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'owner_id'		=>	[ 's/\D//g' ],
	'payor_id'		=>	[ 's/\D//g' ],
	'payment_id'	=>	[ 's/\D//g' ],
	'currency_id'	=>	[ 's/\D//g' ],
	'account_id'	=>	[ 's/\D//g' ],
	'credit'		=>	[ 's/[^\d\.\-]//g' ],
	'debit'			=>	[ 's/[^\d\.\-]//g' ],
	'total'			=>	[ 's/[^\d\.\-]//g' ],
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

#$openprint::log->debug("Hash key: $hash_key");
	my @values;
	my $sql = 'SELECT * FROM Ledgers WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'occurred_on_start'} and $params{'occurred_on_end'} ) {
		$sql .= ' AND ( occurred_on BETWEEN ? AND ? )';
		push @values, @params{'occurred_on_start','occurred_on_end'};
	} elsif ( $params{'occurred_on_start'} ) {
		$sql .= ' AND occurred_on >= ?';
		push @values, $params{'occurred_on_start'};
	} elsif ( $params{'occurred_on_end'} ) {
		$sql .= ' AND occurred_on <= ?';
		push @values, $params{'occurred_on_end'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Ledgeres SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Ledgers loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Ledgers ($sql) (@values) records:" . @$data );
	} # end if
	@{$find_cache{$hash_key}} = map { new openprint::Ledger( $_->{id}, $_ ) } @$data;
	return @{$find_cache{$hash_key}};
} # end sub find

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM Ledgers WHERE id=?}, $$self{'id'} );
} # end sub delete

sub Payor {
	return new openprint::Company( $_[0]{'payor_id'} );
} # end sub Payor

sub credit {
	my $self = shift;
	if ( @_ ) {
		$$self{'credit'} = int($_[0] * 100);
	} # end if
	return sprintf('%.2f', $$self{'credit'} / 100 );
} # end sub credit

sub debit {
	my $self = shift;
	if ( @_ ) {
		$$self{'debit'} = int($_[0] * 100);
	} # end if
	return sprintf('%.2f', $$self{'debit'} / 100 );
} # end sub debit

sub Currency {
	return new openprint::Currency( $_[0]{'currency_id'} );
} # end sub Currency

1;
#__END__
