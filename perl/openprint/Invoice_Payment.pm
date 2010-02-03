package openprint::Invoice_Payment;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

use strict;
use vars qw( $table $serial %fields %defaults %transforms );

$table = 'invoices_payments';
$serial = 'invoices_payments_id_seq';

require sql;
require openprint::Invoice;
require openprint::Payment;

%fields = (
	'id'				=>	'id',
	'amount'			=>	'amount',
	'invoice_id'		=>	'invoice_id',
	'payment_id'		=>	'payment_id',
);

%transforms = (
	'amount'	=>	[ 's/[^\d\.]//g' ],
);
%defaults = (
	'amount'		=>	0,
);

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM ' . $table . ' WHERE 1>0';
	my @values;
	if ( $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= q{ AND id IN (}.join(',', map {'?'} @{$params{'id'}} ).')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= q{ AND id=?};
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'invoice_id'} ) {
		if ( ref $params{'invoice_id'} eq 'ARRAY' ) {
			$sql .= q{ AND invoice_id IN (}.join(',', map {'?'} @{$params{'invoice_id'}} ).')';
			push @values, @{$params{'invoice_id'}};
		} else {
			$sql .= q{ AND invoice_id=?};
			push @values, $params{'invoice_id'};
		} # end if
	} # end if
	if ( $params{'payment_id'} ) {
		if ( ref $params{'payment_id'} eq 'ARRAY' ) {
			$sql .= q{ AND payment_id IN (}.join(',', map {'?'} @{$params{'payment_id'}} ).')';
			push @values, @{$params{'payment_id'}};
		} else {
			$sql .= q{ AND payment_id=?};
			push @values, $params{'payment_id'};
		} # end if
	} # end if

	if ( $params{'received_on_start'} and $params{'received_on_end'} ) {
		$sql .= ' AND ( (SELECT date FROM Payments WHERE Payments.id=payment_id) BETWEEN ? AND ? )';
		push @values, @params{'received_on_start','received_on_end'};
	} elsif ( $params{'received_on_start'} ) {
		$sql .= ' AND (SELECT date FROM Payments WHERE Payments.id=payment_id) >= ?';
		push @values, $params{'received_on_start'};
	} elsif ( $params{'received_on_end'} ) {
		$sql .= ' AND (SELECT date FROM Payments WHERE Payments.id=payment_id) <= ?';
		push @values, $params{'received_on_end'};
	} 

	if ( $params{'received_on_>'} ) {
		$sql .= ' AND (SELECT date FROM Payments WHERE Payments.id=payment_id) > ?';
		push @values, $params{'received_on_>'};
	} 
	if ( $params{'received_on_<'} ) {
		$sql .= ' AND (SELECT date FROM Payments WHERE Payments.id=payment_id) < ?';
		push @values, $params{'received_on_<'};
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->warn("Error loading Invoice_Payment: ($sql) (@values)" . $dbh->errstr );
		return;
	} elsif ($debug ) {
		$log->debug("openprint::Invoice_Payment::find($sql) (@values) " . @$data . ' records');
	} # end if
	return map { new openprint::Invoice_Payment( $_->{id}, $_ ); } @$data;
} # end sub find

sub save {
	my ( $self, $data ) = @_;
	my $ac = sql::start_transaction( $dbh );
	my $error = $self->SUPER::save( $data );
	$error .= $self->Invoice()->save({'paid'=>undef});
	$error .= $self->Payment()->save({'remaining'=>undef});
	sql::end_transaction( $dbh, $ac );
	return $error;
} # end sub save

sub Invoice {
	return new openprint::Invoice( $_[0]{invoice_id} );
} # end sub Order
sub Payment {
	return new openprint::Payment( $_[0]{payment_id} );
} # end sub Order

1;

__END__
