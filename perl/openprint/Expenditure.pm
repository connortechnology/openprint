package openprint::Expenditure;
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

$table = 'expenditures';
$serial = 'expenditures_id_seq';

%fields = (
	'id'				=>	'id',
	'owner_id'			=>	'owner_id',
	'description'		=>	'description',
	'amount'			=>	'amount',
	'created_on'		=>	'created_on',
	'occurred_on'		=>	'occurred_on',
	'currency_id'		=>	'currency_id',
	'federaltax_rate'	=>	'federaltax_rate',
);

%transforms = (
	'id'				=>	[ 's/\D//g' ],
	'owner_id'			=>	[ 's/\D//g' ],
	'currency_id'		=>	[ 's/\D//g' ],
	'amount'			=>	[ 's/[^\d\.\-]//g' ],
	'federaltax_rate'	=>	[ 's/[^\d\.]//g' ],
);

%defaults = (
	'occurred_on'		=>	'NOW()',
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
	my $sql = 'SELECT * FROM Expenditures WHERE 1>0';

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
		$log->debug("Error loading Expenditurees SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Expenditures loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Expenditures ($sql) (@values) records:" . @$data );
	} # end if
	@{$find_cache{$hash_key}} = map { new openprint::Expenditure( $_->{id}, $_ ) } @$data;
	return @{$find_cache{$hash_key}};
} # end sub find

sub Payor {
	return new openprint::Company( $_[0]{'payor_id'} );
} # end sub Payor

sub Currency {
	return new openprint::Currency( $_[0]{'currency_id'} );
} # end sub Currency

sub federaltax {
	my $self = shift;
	return sprintf('%.2f', $$self{'amount'} * $$self{'federaltax_rate'}/100 );
} # end sub federaltax

1;
#__END__
