package openprint::Claim;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %fields %transforms %defaults $table $serial );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

require openprint::Claim_Content;
require openprint::PurchaseOrder;
require openprint::Company;


my $debug = 1;

$table = 'claims';
$serial = 'claims_id_seq';

%fields = (
	'id'			=>	'id',
	'created_on'	=>	'created_on',
	'created_by'	=>	'created_by',
	'updated_on'	=>	'updated_on',
	'filed_on'		=>	'filed_on',
	'sent_to_accounts_on'		=>	'sent_to_accounts_on',
	'invoiced_on'	=>	'invoiced_on',
	'invoice_id'	=>	'invoice_id',
	'po_id'			=>	'po_id',
	'docket'		=>	'docket',
	'supplier_id'	=>	'supplier_id',
	'currency_id'	=>	'currency_id',
);

%transforms = (
	'updated_on'	=> [ 's/.*//g' ],
	'po_id'			=>	[ 's/\D//g' ],
	'docket'		=>	[ 's/\D//g' ],
	'supplier_id'	=>	[ 's/\D//g' ],
	'currency_id'	=>	[ 's/\D//g' ],
);

%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'filed_on'	=>	undef,
	'sent_to_accounts_on'	=>	undef,
	'invoiced_on'	=>	undef,
	'po_id'			=>	undef,
	'docket'		=>	undef,
	'supplier_id'	=>	undef,
	'invoice_id'	=>	undef,
	'currency_id'	=>	undef,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM Claims WHERE 1>0';

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
	if ( exists $params{'po_id'} ) {
		if ( ref $params{'po_id'} eq 'ARRAY' ) {
			if ( @{$params{'po_id'}} ) {
				$sql .= ' AND po_id IN ('. join(',', map {'?'} @{$params{'po_id'}} ) . ')';
				push @values, @{$params{'po_id'}};
			} else {
				return ();
			} # end if
		} else {
			$sql .= ' AND po_id=?';
			push @values, $params{'po_id'};
		} # end if
	} # end if
	if ( exists $params{'supplier_id'} ) {
		if ( ref $params{'supplier_id'} eq 'ARRAY' ) {
			if ( @{$params{'supplier_id'}} ) {
				$sql .= ' AND supplier_id IN ('. join(',', map {'?'} @{$params{'supplier_id'}} ) . ')';
				push @values, @{$params{'supplier_id'}};
			} else {
				return ();
			} # end if
		} else {
			$sql .= ' AND supplier_id=?';
			push @values, $params{'supplier_id'};
		} # end if
	} # end if
	if ( exists $params{'docket'} ) {
		if ( ref $params{'docket'} eq 'ARRAY' ) {
			if ( @{$params{'docket'}} ) {
				$sql .= ' AND docket IN ('. join(',', map {'?'} @{$params{'docket'}} ) . ')';
				push @values, @{$params{'docket'}};
			} else {
				return ();
			} # end if
		} else {
			$sql .= ' AND docket=?';
			push @values, $params{'docket'};
		} # end if
	} # end if

	if ( $params{'received_on_start'} and $params{'received_on_end'} ) {
		$sql .= ' AND ( received_on BETWEEN ? AND ? )';
		push @values, @params{'received_on_start','received_on_end'};
	} elsif ( $params{'received_on_start'} ) {
		$sql .= ' AND received_on >= ?';
		push @values, $params{'received_on_start'};
	} elsif ( $params{'received_on_end'} ) {
		$sql .= ' AND received_on <= ?';
		push @values, $params{'received_on_end'};
	} # end if

	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'};
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND created_on >= ?';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND created_on <= ?';
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'updated_on_start'} and $params{'updated_on_end'} ) {
		$sql .= ' AND ( updated_on BETWEEN ? AND ? )';
		push @values, @params{'updated_on_start','updated_on_end'};
	} elsif ( $params{'updated_on_start'} ) {
		$sql .= ' AND updated_on >= ?';
		push @values, $params{'updated_on_start'};
	} elsif ( $params{'updated_on_end'} ) {
		$sql .= ' AND updated_on <= ?';
		push @values, $params{'updated_on_end'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Claim SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Claim loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Claim ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Claim( $_->{id}, $_ ) } @$data;
} # end sub find

sub delete {
    my $self = shift;
    my $ac = sql::start_transaction( );
	foreach my $PO ( openprint::PurchaseOrder::find('claim_id'=>$$self{'id'}) ) {
		$PO->save({'claim_id'=>undef});
	} # end foreach $PO
    sql::execute( undef, undef, q{DELETE FROM Claim_Contents WHERE claim_id=?}, $$self{'id'} );
    sql::execute( undef, undef, q{DELETE FROM Claims WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
	return $dbh->errstr() if $dbh->errstr();
	delete $openprint::Object::cache{'openprint::Claim'}{$$self{'id'}};
	return '';
} # end sub delete

sub Contents {
	my ( $self, %params ) = @_;
	if ( %params ) {
		if ( $$self{'id'} ) {
			return openprint::Claim_Content::find('claim_id'=>$$self{id}, %params );
		} # end if
	} # end if
	if ( ! $$self{'Contents'} ) {
		if ( $$self{'id'} ) {
			@{$$self{'Contents'}} = openprint::Claim_Content::find('claim_id'=>$$self{id} );
		} # end if
	} # end if
	return @{$$self{'Contents'}} if $$self{'Contents'};
	return;
} # end sub Contents

sub Vendor {
	return new openprint::Company( $_[0]{'supplier_id'} );
} # end sub Vendor

sub Currency {
	return new openprint::Currency( $_[0]{'currency_id'} );
} # end sub Currency

sub Creator {
	return new openprint::User( $_[0]{created_by} );
} # end sub Creator

1;
__END__
