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
	'posted'		=> 0,
	'interest'		=> undef,
	'paid'			=> undef,
	'statetax'		=> undef,
	'federaltax'	=> undef,
	'statetaxrate'		=> undef,
	'federaltaxrate'	=> undef,
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

	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( (! $data) and $dbh->errstr ) {
		$log->warn("Error loading Invoices: ($sql) (@values)" . $dbh->errstr );
		return;
	} elsif ($debug ) {
		$log->debug("openprint::Invoice::find($sql) (@values)");
	} # end if
	return map { new openprint::Invoice( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $dbh->selectrow_hashref( 'SELECT * FROM Invoices WHERE id=?', {}, $$self{'id'} );
		if ( (! $data) and $dbh->errstr ) { $log->debug($dbh->errstr ); }
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
	
	# none of these should be set by param
	
	$$self{'total'} = $self->total();
	$$self{'federaltax'} = $self->federaltax();
	$$self{'statetax'} = $self->statetax();
	
	$self->set( $param ) if $param;

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$k} = $$self{$k};
	} # end foreach

	my $ac = sql::start_transaction( $dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('invoices_id_seq')});
		$sql{'id'} = $$self{id};
		if ( my $error = sql::insert( undef, undef, 'Invoices', \%sql ) ) {
			$dbh->rollback();
			delete $$self{'id'};
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'Invoices', ['id=?', $$self{'id'}], \%sql ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
	} # end if
	sql::end_transaction( $dbh, $ac );
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
	my ( $self ) = @_;
	if ( ! $$self{'posted'} ) {
		return 0;
	} # end if
	return ( $self->total() - $self->paid() > 0 ) ? 0 : 1;
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
		$$self{'subtotal'} = 0;
		map { $$self{'subtotal'} += $_->value() } openprint::Timetrack::find('invoice_id'=>$$self{id});
	} # end if
	return $$self{'subtotal'};
} # end sub subtotal
sub total {
	my ( $self ) = @_;

	if ( (!$$self{'posted'}) or ( ! defined $$self{'total'} ) ) {
		$$self{'total'} = $self->subtotal();
		$$self{'total'} += $self->federaltax();
		$$self{'total'} += $self->statetax();
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

sub federaltax {
	my ( $self ) = @_;
	if ( ! $$self{'posted'} ) {
		if ( $self->Invoicee()->taxexempt1() eq 'Y' ) {
			return '';
		} # end if
		if ( ! $self->Invoicer()->gst_number() ) {
			return '';
		} # end if
		my ( $tax ) = sql::execute( undef, undef, 'SELECT Federaltax FROM Taxes WHERE State=? AND Country=?', $self->Invoicee()->get('state','country') );
		return '' if ! $tax;
		return $self->subtotal() * ( $tax/100 );
	} # end if
	return $$self{'federaltax'};
} # end sub federaltax
sub statetax {
	my ( $self ) = @_;

	if ( ! $$self{'posted'} ) {
		if ( $self->Invoicee()->taxexempt2() eq 'Y' ) {
			return '';
		} # end if
		if ( ! $self->Invoicer()->pst_number() ) {
			return '';
		} # end if
		my ( $tax ) = sql::execute( undef, undef, 'SELECT Statetax FROM Taxes WHERE State=? AND Country=?', $self->Invoicee()->get('state','country') );
		return '' if ! $tax;
		return $self->subtotal() * ($tax/100 );
	} # end if
	return $$self{'statetax'};
} # end sub statetax

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

sub add_to_log {
	my ( $self, $desc, $user_id ) = @_;
	my $Log = new openprint::InvoiceLog();
	$Log->save({
		'invoice_id'	=> $$self{'id'},
		'user_id'		=> $user_id ? $user_id : $session{'user_id'},
		'description'	=> $desc,
	} );
	
} # end sub add_to_log

sub send {
	my ( $self ) = @_;

	my %data;
	$data{'Invoice'} = $self;

	my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
	my @attachments;
	$data{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/invoice_body.html' );
	$data{'ReplacementText'} = ssi::variable_substitution( \$data{'ReplacementText'}, \%data );
	push @attachments, '', encode_qp( ssi::variable_substitution( \$email_template, \%data ) ), 'text/html', 'quoted-printable';
	$data{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/invoice.html' );
	$data{'ReplacementText'} = ssi::variable_substitution( \$data{'ReplacementText'}, \%data );
	push @attachments, 'Invoice '.$$self{'id'}.'.html', encode_qp( ssi::variable_substitution( \$email_template, \%data ) ), 'text/html', 'quoted-printable';

	#my @recipients = ('iconnor@connortechnology.com');
	my @recipients = map { sprintf('"%s" <%s>', $_->name(), $_->email() ) } $self->Invoicee()->AccountingContacts();
	my %mail = (
			SMTP    => $config{'Mail Server'},
			FROM    => $config{'AccountingEmail'},
			TO      => join(',', @recipients ),
			SUBJECT => sprintf('Your Invoice (%1$d) is now available.', $$self{id} ),
			);
	misc::send_email_with_attachment( $log, \%mail, @attachments );
	$self->add_to_log( 'Emailed to ' . join(', ', @recipients) );
	return 'Sent.';

} # end sub send

1;

__END__
~       
