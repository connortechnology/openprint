package openprint::PurchaseOrder_Content;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%variable $log $dbh $table $serial %config %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require openprint::PurchaseOrder_ContentType;

my $debug = 0;
$table = 'PurchaseOrder_Contents';
$serial = 'PurchaseOrder_Contents_id_seq';

%fields = (
	'id'			=>	'id',
	'po_id'			=>	'po_id',
	'created_on'	=>	'created_on',
	'qty'			=>	'qty',
	'price'			=>	'price',
	'total'			=>	'total',
	'item'			=>	'item',
	'docket'		=>	'docket',
	'description'	=>	'description',
	'type_id'		=>	'type_id',
);

%transforms = (
	'price'			=>	[ 's/[^\-\d\.]//g' ],
	'total'			=>	[ 's/[^\-\d\.]//g' ],
	'qty'			=>	[ 's/[^\-\d\.]//g' ],
);

%defaults = (
	'po_id'			=>	undef,
	'created_on'	=> 'NOW()',
	'price'			=>	undef,
	'total'			=>	undef,
	'qty'			=>	undef,
	'type_id'		=>	undef,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM PurchaseOrder_Contents WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( exists $params{'po_id'} ) {
		if ( $params{'po_id'} ) {
			$sql .= ' AND po_id=?';
			push @values, $params{'po_id'};
		} else {
			$sql .= ' AND po_id IS NULL';
		} # end if
	} # end if
	if ( $params{'item_like'} ) {
		$sql .= ' AND item LIKE ?';
		push @values, $params{'item_like'};
	} # end if
	if ( $params{'description_like'} ) {
		$sql .= ' AND description LIKE ?';
		push @values, $params{'description_like'};
	} # end if
	if ( exists $params{'docket'} ) {
		if ( defined $params{'docket'} ) {
			$sql .= 'AND docket=?';
			push @values, $params{'docket'};
		} else {
			$sql .= 'AND docket IS NULL';
		} # end if
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'}
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND ( created_on >= ?)';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on <= ?)';
		push @values, $params{'created_on_end'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading PurchaseOrder_Contents SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No PurchaseOrder_Contents loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded PurchaseOrder_Contents ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::PurchaseOrder_Content( $_->{id}, $_ ) } @$data;
} # end sub find

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM PurchaseOrder_Contents WHERE id=?}, $$self{'id'} );
} # end sub delete

sub PurchaseOrder {
	return new openprint::PurchaseOrder( $_[0]{po_id} );
} # end sub Supplier

sub Type {
	return new openprint::PurchaseOrder_ContentType( $_[0]{type_id} );
} # end sub Type

sub units {
	my ( $self ) = @_;
	if ( $self->Type()->name() eq 'Roll Stock' ) {
		return 'lbs';
	} elsif ( $self->Type()->name() eq 'Sheet Stock' ) {
		return 'sheets';
	} # end if
	return;
} # end sub units

1;
__END__
