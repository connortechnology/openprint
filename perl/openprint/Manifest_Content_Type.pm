package openprint::Manifest_Content_Type;
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
require openprint::Manifest;

my $debug = 1;

$table = 'manifest_content_types';
$serial = 'manifest_content_types_id_seq';

%fields = (
	'id'			=>	'id',
	'cost'			=>	'cost',
	'docket'		=>	'docket',
	'po_id'			=>	'po_id',
	'manifest_id'	=>	'manifest_id',
	'paper_id'		=>	'paper_id',
	'supplier_invoice'	=>	'supplier_invoice',
);

%transforms = (
	'paper_id'		=> [ 's/\D//g' ],
	'po_id'		=> [ 's/\D//g' ],
	'docket'	=> [ 's/\D//g' ],
	'cost'		=> [ 's/[^\d\.]//g' ],
);

%defaults = (
	'cost'		=>	undef,
	'docket'	=>	undef,
	'po_id'		=>	undef,
	'paper_id'	=>	undef,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM Manifest_Content_Types WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'id_like'} ) {
		$sql .= " AND id LIKE '%$params{id_like}%'";
	} # end if
	if ( $params{'manifest_id'} ) {
		$sql .= ' AND manifest_id=?';
		push @values, $params{'manifest_id'};
	} # end if
	if ( exists $params{'cost'} ) {
		if ( $params{'cost'} ) {
			$sql .= ' AND cost=?';
			push @values, $params{'cost'};
		} else {
			$sql .= ' AND cost IS NULL';
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Manifest_Content_Type SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Manifest_Content_Type loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Manifest_Content_Type ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Manifest_Content_Type( $_->{id}, $_ ) } @$data;
} # end sub find

sub Paper {
	return new openprint::Paper( $_[0]{'paper_id'} );
} # end sub Paper

sub Manifest {
	return new openprint::Manifest( $_[0]{'manifest_id'} );
} # end sub Manifest

1;
__END__
