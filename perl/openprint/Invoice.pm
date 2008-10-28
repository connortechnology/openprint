package openprint::Invoice;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
use MIME::QuotedPrint;
use MIME::Base64;

require openprint::Currency;
require openprint::Company;
require openprint::Service;
require openprint::InvoiceLog;

my $debug = 1;

use strict;
use vars qw( %fields %defaults %transforms );

require sql;

%fields = (
	'id'				=>	'id',
	'invoicer_id'		=>	'invoicer_id',
	'invoicee_id'		=>	'invoicee_id',
	'external_notes'	=>	'external_notes',
	'internal_notes'	=>	'internal_notes',
	'monthly_interest'	=>	'monthly_interest',
	'posted'			=>	'posted',
	'statetaxrate'		=>	'statetaxrate',
	'federaltaxrate'	=>	'federaltaxrate',
	'statetax'			=>	'statetax',
	'federaltax'		=>	'federaltax',
	'subtotal'			=>	'subtotal',
	'total'				=>	'total',
	'due_on'			=>	'due_on',
	'posted_on'			=>	'posted_on',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'deleted'			=>	'deleted',
	'currency_id'		=>	'currency_id',
	'paid'				=>	'paid',
	'interest'			=>	'interest',
);

%transforms = (
);
%defaults = (
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'deleted'		=> 0,
);

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM Invoices WHERE 1>0};
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

	if ( $params{'invoicer_id'} ) {
		if ( ref $params{'invoicer_id'} eq 'ARRAY' ) {
			$sql .= q{ AND invoicer_id IN (}.join(',', map {'?'} @{$params{'invoicer_id'}} ).')';
			push @values, @{$params{'invoicer_id'}};
		} else {
			$sql .= q{ AND invoicer_id=?};
			push @values, $params{'invoicer_id'};
		} # end if
	} # end if
	if ( $params{'invoicee_id'} ) {
		if ( ref $params{'invoicee_id'} eq 'ARRAY' ) {
			$sql .= q{ AND invoicee_id IN (}.join(',', map {'?'} @{$params{'invoicee_id'}} ).')';
			push @values, @{$params{'invoicee_id'}};
		} else {
			$sql .= q{ AND invoicee_id=?};
			push @values, $params{'invoicee_id'};
		} # end if
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
	if ( $params{'due_on_start'} and $params{'due_on_end'} ) {
		$sql .= ' AND ( due_on BETWEEN ? AND ? )';
		push @values, @params{'due_on_start','due_on_end'};
	} elsif ( $params{'due_on_start'} ) {
		$sql .= ' AND due_on >= ?';
		push @values, $params{'due_on_start'};
	} elsif ( $params{'due_on_end'} ) {
		$sql .= ' AND due_on <= ?';
		push @values, $params{'due_on_end'};
	} # end if

	if ( $params{'payment_id'} ) {
		$sql .= ' AND id IN ( SELECT invoice_id FROM invoices_payments WHERE payment_id=? )';
		push @values, $params{'payment_id'};
	} # end if

	if ( $params{'deleted'} ) {
		$sql .= ' AND deleted=?';
		push @values, $params{'deleted'};
	} else {
		$sql .= ' AND deleted=?';
		push @values, 0;
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->warn("Error loading Invoices: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug ) {
		$openprint::log->debug("openprint::Invoice::find($sql) (@values)");
	} # end if
	return map { new openprint::Invoice( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Invoices WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub delete {
	my $self = shift;
	return sql::update( undef, undef, 'Invoices', ['id=?', $$self{'id'} ], 'deleted', 1 );
} # end sub delete

sub destroy {
	my $self = shift;
    return sql::execute( undef, undef, q{DELETE FROM Invoices WHERE id=?}, $$self{'id'} );
} # end sub destroy

sub save {
	my ( $self, $param ) = @_;
	
	$self->set( $param ) if $param;

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$k} = $$self{$k};
	} # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('invoices_id_seq')});
		$sql{'id'} = $$self{id};
		if ( my $error = sql::insert( undef, undef, 'Invoices', \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'Invoices', ['id=?', $$self{'id'}], \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return '';
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::Invoice();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

sub Currency {
	return new openprint::Currency( $_[0]{currency_id} );
} # end sub Currency

sub Company {
	return new openprint::Company( $_[0]{company_id} );
} # end sub Company

sub is_paid {
	return ( $_[0]->total() - $_[0]->paid() > 0 ) ? 1 : 0;
} # end sub is_paid

sub owing {
	return $_[0]->total() + $_[0]->interest() - $_[0]->paid();
} # end sub owing

sub Invoicee {
	return new openprint::Company( $_[0]->invoicee_id() );
} # end sub Invoicee

sub Invoicer {
	return new openprint::Company( $_[0]->invoicer_id() );
} # end sub Invoicer

sub subtotal {
	my ( $self ) = @_;

	if ( (!$$self{'posted'}) or ( ! defined $$self{'subtotal'} ) ) {
	} # end if
	return $$self{'subtotal'};
} # end sub subtotal
sub total {
	my ( $self ) = @_;

	if ( (!$$self{'posted'}) or ( ! defined $$self{'total'} ) ) {
	} # end if
	return $$self{'total'};
} # end sub total

sub interest {
	my ( $self ) = @_;

	if ( (!$$self{'posted'}) or ( ! defined $$self{'interest'} ) ) {
		$$self{'interest'} = misc::sum( sql::execute( undef, undef, 'SELECT amount FROM invoice_interests WHERE invoice_id=?', $$self{'id'} ) );
	} # end if
	return $$self{'interest'};
} # end sub interest

sub paid {
	my $self = shift;
	if ( @_ ) {
		$$self{'paid'} = $_[0];
	} # end if
	if ( (!$$self{'posted'}) or ( ! defined $$self{'paid'} ) ) {
		$$self{'paid'} = misc::sum( sql::execute( undef, undef, 'SELECT amount FROM invoices_payments WHERE invoice_id=?', $$self{'id'} ) );
	} # end if
	return $$self{'paid'};
} # end sub paid

sub add_Payment {
	my ( $self, $Payment ) = @_;
	if ( $Payment->remaining() and $self->owing() ) {
		my $amount = $Payment->remaining() > $self->owing() ? $self->owing() : $Payment->remaining();	
		sql::insert( undef, undef, 'invoices_payments', 'payment_id', $Payment->id(), 'invoice_id', $$self{id}, 'amount', $amount );
		$Payment->remaining( undef ); # force update
		$Payment->save();
		$self->paid( undef );
		$self->save();
	} # end if
} # end sub add_Payment

sub del_Payment {
	my ( $self, $Payment ) = @_;

	sql::execute( undef, undef, 'DELETE FROM invoices_payments WHERE invoice_id=? AND payment_id=?', $$self{id}, $$Payment{'id'} );
	$Payment->remaining( undef );
	$Payment->save();
	$self->paid( undef );
	$self->save();
} # end sub del_Payment

sub Payments {
	my ( $self ) = @_;
	return openprint::Payment::find('invoice_id'=>$$self{'id'} );
} # end sub Payments

sub Logs {
	return openprint::InvoiceLog::find('invoice_id'=>$_[0]{id},'order'=>'created_on');
} # end sub Logs

1;

__END__
~       
