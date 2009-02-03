package openprint::ManifestContent;
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
require openprint::Manifest_Content_Type;

my $debug = 1;

$table = 'manifestcontents';
$serial = 'manifestcontents_id_seq';

%fields = (
	'id'				=>	'id',
	'manifest_id'		=>	'manifest_id',
	'skid_id'			=>	'skid_id',
	'quantity'			=>	'quantity',
	'type_id'			=>	'type_id',
);

%transforms = (
	'quantity'	=> [ 's/\D//g' ],
	'type_id'	=> [ 's/\D//g' ],
);

%defaults = (
	'quantity'	=> 0,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM ManifestContents WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'manifest_id'} ) {
		$sql .= ' AND manifest_id=?';
		push @values, $params{'manifest_id'};
	} # end if
	if ( $params{'type_id'} ) {
		$sql .= ' AND type_id=?';
		push @values, $params{'type_id'};
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
		$log->debug("Error loading ManifestContent SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No ManifestContent loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded ManifestContent ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::ManifestContent( $_->{id}, $_ ) } @$data;
} # end sub find

sub Skid {
	return new openprint::Skid( $_[0]{skid_id} );
} # end sub Skid

sub Manifest {
	return new openprint::Manifest( $_[0]{manifest_id} );
} # end sub Manifest

sub Type {
	return new openprint::Manifest_Content_Type( $_[0]{type_id} );
} # end sub Type


1;
__END__
