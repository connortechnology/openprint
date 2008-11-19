package openprint::Tax;
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

$table = 'Taxes';
$serial = 'taxes_id_seq';

%fields = (
	'id'				=>	'id',
	'federaltax_rate'	=>	'dblfederalpercent',
	'statetax_rate'		=>	'dblstatepercent',
	'state'				=>	'state',
	'country'			=>	'country',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
);

%defaults = (
	'federal'	=>	undef,
	'state'		=>	undef,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
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
	return map { new openprint::Tax( $_->{id}, $_ ) } @$data;
} # end sub find

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM Taxes WHERE id=?}, $$self{'id'} );
} # end sub delete

1;
#__END__
