use strict;
require Math::Round;
package openprint::Invoice;
our @ISA = qw(openprint::Object);

use vars qw( %config $log %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;

require openprint::Currency;
require openprint::Company;
require openprint::Service;
require openprint::InvoiceLog;
require openprint::Tax;
require openprint::Invoiced_Product;
require openprint::Invoiced_Project;
require openprint::Invoice_Interest;
require openprint::Invoice_Payment;
require openprint::Invoice_Tax;
require openprint::Timetrack;
require openprint::Object_Asset;
require openprint::Order_Invoice;

use vars qw( $debug $table $serial %fields %find_fields %defaults %transforms );

$debug = 0;

$table = 'invoices';
$serial = 'invoices_id_seq';

%fields = (
	id				=>	'id',
	invoicer_id		=>	'invoicer_id',
	invoicee_id		=>	'invoicee_id',
	external_notes	=>	'external_notes',
	internal_notes	=>	'internal_notes',
	posted			=>	'posted',
	subtotal		=>	'subtotal',
	total			=>	'total',
	due_on			=>	'due_on',
	posted_on		=>	'posted_on',
	created_on		=>	'created_on',
	updated_on		=>	'updated_on',
	deleted			=>	'deleted',
	currency_id		=>	'currency_id',
	paid				=>	'paid',
	interest			=>	'interest',
	bad_debt			=>	'bad_debt',
	num					=>	'num',
	monthly_interest	=>	'monthly_interest',
	late_payment_units	=>	'late_payment_units',
	early_payment_date	=>	'early_payment_date',
	early_payment_amount	=>	'early_payment_amount',
	early_payment_units		=>	'early_payment_units',
);

%find_fields = (
	po		=>	'(SELECT po FROM invoiced_products WHERE invoiced_products.invoice_id = invoices.id)',
	sent_on	=>	'(SELECT created_on FROM invoice_logs WHERE invoice_id=invoices.id LIMIT 1)',
);

%transforms = (
	num			=>	[ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
	created_on	=> q`'NOW()'`,
	updated_on	=> q`'NOW()'`,
	deleted		=> 0,
	posted		=> 0,
	interest		=> undef,
	monthly_interest	=> undef,
	paid			=> undef,
	bad_debt		=> 0,
	late_payment_units		=>	undef,
	early_payment_amount	=>	undef,
	early_payment_units		=>	undef,
	early_payment_date		=>	undef,
);

sub save {
	my ( $self, $param ) = @_;
	
	# none of these should be set by param
	$$self{'total'} = $self->total();

	my $rc = $self->SUPER::save( $param );
	if ( ! $rc and $$self{'posted_on'} ) {
		foreach my $T ( $self->Taxes(undef) ) {
			$rc .= $T->save();
		} # end foreach
	} else {
		return $rc;
	} # end if
} # end sub save

sub is_paid {
	my ( $self ) = @_;
	if ( ! $$self{'posted'} ) {
		return 0;
	} # end if
	return $self->owing() > 0 ? 0 : 1;
} # end sub is_paid

sub owing {
#$log->debug("Owing total: " . $_[0]->total() . ' int: ' . $_[0]->interest() . ' paid: ' . $_[0]->paid() );
	return Math::Round::nearest( .01, $_[0]->total() + $_[0]->interest() - $_[0]->paid() );
} # end sub owing
sub owing_early {
#$log->debug("Owing total: " . $_[0]->total() . ' int: ' . $_[0]->interest() . ' paid: ' . $_[0]->paid() );
	my $owing = $_[0]->total() + $_[0]->interest() - $_[0]->paid();
	if ( $_[0]{early_payment_units} eq 'amount' ) {
		return Math::Round::nearest( .01, $owing + $_[0]{early_payment_amount} );
	} elsif ( $_[0]{early_payment_units} eq 'percent' ) {
$openprint::log->debug("doing early payment percent: $_[0]{early_payment_amount}");
		return Math::Round::nearest( .01, $owing * ( 1 - $_[0]{early_payment_amount}/100 ) );
	} else {
$openprint::log->debug('Unknown units for early_payment '. $_[0]{early_payment_units} );
		return Math::Round::nearest( .01, $owing );
	} # end if
} # end sub owing

sub Invoicee {
	return new openprint::Company( $_[0]->invoicee_id() );
} # end sub Invoicee

sub Invoicer {
	return new openprint::Company( $_[0]->invoicer_id() );
} # end sub Invoicer

sub subtotal {
	my ( $self ) = @_;

	if ( ! $$self{'id'} ) {
		$log->error('Invoice:subtotal no id! ref:' . (ref $self) . ' self:' . $self);
#cluck('Invoice:subtotal no id! ref:' . (ref $self) . ' self:' . $self);
		return;
	} # end if

	if ( (!$$self{'posted'}) or ( ! defined $$self{'subtotal'} ) ) {
#$log->debug("Recalculating subtotal");
		$$self{'subtotal'} = 0;
		foreach my $T ( openprint::Timetrack->find('invoice_id'=>$$self{id}) ) {
			$$self{'subtotal'} += $T->value();
		} # end foreach
		foreach my $P ( openprint::Invoiced_Product->find('invoice_id'=>$$self{id}) ) {
			$$self{'subtotal'} += $P->total();
		}# end foreach P
	} # end if
	return Math::Round::nearest( .01, $$self{'subtotal'} );
} # end sub subtotal

sub total {
	my ( $self ) = @_;

	if ( ! $$self{'id'} ) {
		return;
	} # end if

	if ( (!$$self{'posted'}) or ( ! defined $$self{'total'} ) ) {
		$$self{'total'} = $self->subtotal();
		foreach my $Tax ( $self->Taxes() ) {
			$$self{'total'} += $Tax->amount();
		} # end foreach Tax
	} # end if
	return Math::Round::nearest( .01, $$self{'total'} );
} # end sub total

sub interest {
	my ( $self ) = @_;
	if ( @_ == 2 ) {
		$$self{'interest'} = $_[1];
	} # end if

	if ( (!$$self{'posted'}) or ( ! defined $$self{'interest'} ) ) {
		$$self{'interest'} = misc::sum( map { $_->amount() } openprint::Invoice_Interest->find('invoice_id'=>$$self{'id'}) );
	} # end if
	return $$self{'interest'};
} # end sub interest

sub paid {
	my $self = shift;
	if ( @_ ) {
		$$self{'paid'} = $_[0];
	} # end if
	if ( (!$$self{'posted'}) or ( ! defined $$self{'paid'} ) ) {
		$$self{'paid'} = misc::sum( map { $_->amount() } openprint::Invoice_Payment->find('invoice_id'=>$$self{'id'}) );
	} # end if
	return $$self{'paid'};
} # end sub paid

sub add_Payment {
	my ( $self, $Payment ) = @_;
	if ( $Payment->remaining() and $self->owing() ) {
		my $error;
		my $amount = $Payment->remaining() > $self->owing() ? $self->owing() : $Payment->remaining();	
		my $IP = new openprint::Invoice_Payment();
		$error .= $IP->save({'payment_id'=>$Payment->id(),'invoice_id'=>$$self{'id'}, 'amount'=>$amount});
		$Payment->remaining( undef ); # force update
		$error .= $Payment->save();
		$self->paid( undef );
		$error .= $self->save();
		return $error;
	} elsif ( ! $Payment->remaining() ) {
		return 'No money left in payment.';
	} elsif ( ! $self->owing() ) {
		return 'Nothing owing in invoice.';
	} # end if
} # end sub add_Payment

sub del_Payment {
	my ( $self, $Payment ) = @_;

	foreach my $IP ( openprint::Invoice_Payment->find('invoice_id'=>$$self{'id'},'payment_id'=>$$Payment{'id'})) {
		$IP->delete();
	} # endforeach$IP
	$Payment->remaining( undef );
	$Payment->save();
	$self->paid( undef );
	$self->save();
} # end sub del_Payment

sub Payments {
	my ( $self ) = @_;
	return openprint::Invoice_Payment->find('invoice_id'=>$$self{'id'} );
} # end sub Payments

sub Logs {
	return openprint::InvoiceLog->find('invoice_id'=>$_[0]{id},'order'=>'created_on');
} # end sub Logs

sub add_to_log {
	my ( $self, $desc, $user_id ) = @_;
	my $Log = new openprint::InvoiceLog();
	$Log->save({
		invoice_id	=> $$self{id},
		user_id		=> $user_id ? $user_id : $session{user_id},
		description	=> $desc,
	} );
	
} # end sub add_to_log

sub send {
	my ( $self, $To ) = @_;

	my $results;

	my %data = (
			Invoice => $self,
			uri => 'invoice',
			Currency	=>	$self->Currency(),
	);
	my $email_template = ssi::slurp_content('/email_template.html');
	my @attachments;
	$data{'ReplacementText'} = ssi::include( '/email_content/invoice_body.html', \%data );
	push @attachments, '', MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%data ) ) ), 'text/html', 'quoted-printable';
	$data{'ReplacementText'} = ssi::include( '/email_content/invoice.html', \%data );
	my $invoice_html = Encode::encode('utf-8',ssi::variable_substitution( \$email_template, \%data ) );

	my $file_base = 'Invoice'.$$self{id};
	if ( File::Slurp::write_file('/tmp/'.$file_base.'.html', { atomic => 1, err_mode=>'carp' }, \$invoice_html ) ) {
		`wkhtmltopdf "/tmp/$file_base.html" "/tmp/$file_base.pdf"`;
		my $invoice_pdf = File::Slurp::read_file( "/tmp/$file_base.pdf" );
		unlink "/tmp/$file_base.html";
		unlink "/tmp/$file_base.pdf";
		if ( $invoice_pdf ) {
			push @attachments, ($file_base.'.pdf', MIME::Base64::encode_base64($invoice_pdf), 'application/octet-stream', 'base64');
		} else {
			$openprint::log->debug("Error making pdf");
		} # end if has pdf contents
    } # end if successfully wrote html content

    if ( scalar @attachments == 4 ) {
        $results .= 'Unable to make a pdf of this Invoice.  Using HTML version.<br/>';
        push @attachments, ($file_base.'.html', MIME::QuotedPrint::encode_qp($invoice_html), 'text/html', 'quoted-printable');
    } # end if

	my $Email = new openprint::Email();
	$results = $Email->send(
		BCC			=>	new openprint::User( $session{'user_id'} ),
		#'TO'			=>	new openprint::User( $session{'user_id'} ),
		TO			=>	( $To ? $To : [$self->Invoicee()->AccountingContacts()] ),
		FROM		=>	$config{'AccountingEmail'},
		ATTACHMENTS	=>	\@attachments,
		SUBJECT		=>	sprintf('Your Invoice (%1$d) is now available.', $$self{id} ),
	);
	$self->add_to_log( $results );
	return $results;
} # end sub send

sub Products {
	return openprint::Invoiced_Product->find('invoice_id'=>$_[0]{'id'},'order'=>'id');
} # end sub Products
sub Projects {
	return openprint::Invoiced_Project->find('invoice_id'=>$_[0]{'id'},'order'=>'id');
} # end sub Projects
sub Orders {
	return openprint::Order_Invoice->find(invoice_id=>$_[0]{id}, order=>'order_id');
} # end sub Orders

sub Interests {
	my $self = shift;
	my %args = @_;
	$args{'invoice_id'} = $$self{'id'};
	$args{'order'} = 'compounded_on' if ! $args{'order'};
	return openprint::Invoice_Interest->find(%args);
} # end sub Interests

sub calculate_interests {
	my $self = shift;
} # end sub calculate_interests

sub Taxes {
	my ( $self ) = @_;

	if ( @_ > 1 and ! defined $_[1] ) {
		foreach ( openprint::Invoice_Tax->find('invoice_id'=>$$self{'id'}) ) {
			$_->destroy();
		} # end foreach	 Tax
		@{$$self{'Taxes'}} = ();
	} # end if

	if ( ( ! $$self{'Taxes'} ) and $$self{'posted'} ) {
		@{$$self{'Taxes'}} = openprint::Invoice_Tax->find('invoice_id'=>$$self{'id'});
	} # end if
	if ( ! ( $$self{'Taxes'} and @{$$self{'Taxes'}} ) ) {
		$$self{'Taxes'} = [];
		foreach my $Tax ( openprint::Tax->find(
					'period_start null_or_<='	=>	$$self{'created_on'},
					'period_end null_or_>='		=>	$$self{'created_on'},
					'country'	=>	$self->Invoicee()->country(),
					'state'		=>	$self->Invoicee()->state()),
				) {
			my $T = new openprint::Invoice_Tax();
			$T->save({
				'invoice_id'=>	$$self{'id'},
				'tax_id'	=>	$$Tax{'id'},
				'rate'		=>	$$Tax{'rate'},
			});
			push @{$$self{'Taxes'}}, $T;
		} # end foreach Tax
	} # end if
	return @{$$self{'Taxes'}};
} # end sub Taxes

sub Tax {
	my $result = openprint::Invoice_Tax->find_one( invoice_id =>$_[0]{id}, tax_id=>$_[1]->id() );
	if ( ! $result ) {
		return new openprint::Invoice_Tax();
	} # end if
	return $result;
} # end sub Tax

sub num {
	if ( @_ > 1 ) {
		$_[0]{num} = $_[1];
	}
	if ( ! $_[0]{num} ) {
		$_[0]{num} = $_[0]{id};
	} # end if
	return $_[0]{num};
} # end sub num

sub can_edit {
	return 1;
} # end sub can_edit

sub can_view {
	return 1;
} # end sub can_view

sub upload {
	openprint::Object_Asset::upload( @_ );
} # end sub upload

sub url_to {
	return '/invoice/view.html?invoice_id='.$_[0]{id};
}

sub link_to {
	if ( $_[0]{id} ) {
		my $text = $_[1] ? $_[1] : ( $_[0]{num} ? $_[0]{num} : 'id ' . $_[0]{id} );
		return sprintf('<a href="/invoice/view.html?invoice_id=%d">%s</a>', $_[0]{id}, $text );
	}
	return '';
} # end sub link_to

sub Pricelist {
	return $_[0]->Invoicee()->Pricelist();
} # end sub Pricelist

1;
__END__
