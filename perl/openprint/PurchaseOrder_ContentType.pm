package openprint::PurchaseOrder_ContentType;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

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

$table = 'PurchaseOrder_ContentTypes';
$serial = 'PurchaseOrder_ContentTypes_id';
%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
);

%transforms = (
);

%defaults = (
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
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
		$log->debug('No PurchaseOrder_ContentTypes loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded PurchaseOrder_ContentTypes ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::PurchaseOrder_ContentType( $_->{id}, $_ ) } @$data;
} # end sub find

sub delete {
	my $self = shift;
    sql::execute( undef, undef, 'DELETE FROM '.$table.' WHERE id=?', $$self{'id'} );
} # end sub delete

1;
__END__
