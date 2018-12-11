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

$debug = 1;

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
	subtotal_override		=>	'subtotal_override',
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
	sent_on	=>	q`(SELECT date_time FROM logs WHERE object_id=invoices.id AND object_type_id=(SELECT id FROM Object_Types WHERE name='openprint::Invoice') AND action_id=(SELECT id FROM Log_Actions WHERE name='Invoice Sent') LIMIT 1)`,
	product_id	=>	'(SELECT product_id FROM invoiced_products WHERE invoice_id=invoices.id)',
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
	num						=>	undef,
	due_on					=>	undef,
	subtotal_override		=>	0,
);

sub save {
	my ( $self, $param ) = @_;

	$self->set( $param ? $param : {} );

	my $rc;
	# none of these should be set by param ( however employee_accounting will pass in a total if specified.. FIXME
	$$self{subtotal} = $self->subtotal( undef ) if $$self{id} and ! $$self{subtotal_override};
	$self->Taxes( undef );
	$$self{total} = $self->total( undef ) if $$self{id};

	$rc .= $self->SUPER::save( );
	if ( ! $rc ) {
		foreach my $T ( $self->Taxes(undef) ) {
			$rc .= $T->save();
		} # end foreach
		$self->Invoicee()->save({last_invoice_id=>$$self{id}});
	} # end if
	return $rc;
} # end sub save

sub is_paid {
	my ( $self ) = @_;
	if ( ! $$self{posted} ) {
		$openprint::log->debug("Invoice $$self{id} ! is_paid because ! posted") if $debug;
		return 0;
	} # end if
	if ( $debug ) {
		$openprint::log->debug("Invoice $$self{id} owing is " . $self->owing() );
	}
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
		return Math::Round::nearest( .01, $owing * ( 1 - $_[0]{early_payment_amount}/100 ) );
	} else {
$openprint::log->error('Unknown units for early_payment '. $_[0]{early_payment_units} );
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

	if ( @_ > 1 ) {
$openprint::log->debug("Setting subtotal to $_[1]") if $debug;
		$$self{subtotal} = $_[1];
	}

	if ( ! $$self{id} ) {
		$log->error('Invoice:subtotal no id! ref:' . (ref $self) . ' self:' . $self);
#cluck('Invoice:subtotal no id! ref:' . (ref $self) . ' self:' . $self);
		return;
	} # end if

	if ( ( (!$$self{posted}) or ( ! defined $$self{subtotal} ) ) and ( ! $$self{subtotal_override} ) ) {
$log->debug("Recalculating subtotal") if $debug;
		$$self{subtotal} = 0;
		foreach my $T ( openprint::Timetrack->find( invoice_id=>$$self{id} ) ) {
			$$self{subtotal} += $T->value();
$log->debug("T value: " . $T->value() . " subtotal: $$self{subtotal}");
		} # end foreach
		foreach my $P ( openprint::Invoiced_Product->find(invoice_id=>$$self{id}) ) {
			$$self{subtotal} += $P->total();
$log->debug("P value: " . $P->total() . " subtotal: $$self{subtotal}" );
		}# end foreach P
		foreach my $O ( $self->Orders() ) {
			$$self{subtotal} += $O->Order()->subtotal();
$log->debug("O value: " . $O->Order()->subtotal() . " subtotal: $$self{subtotal}" );
		}# end foreach P
	} # end if
	return Math::Round::nearest( .01, $$self{subtotal} );
} # end sub subtotal

sub total {
	my ( $self ) = @_;

	if ( ! $$self{id} ) {
		return;
	} # end if

	if ( @_ > 1 ) {
		$$self{total} = $_[1];
	}

	if ( (!$$self{posted}) or ( ! defined $$self{total} ) ) {
		$$self{total} = $self->subtotal();
		foreach my $Tax ( $self->Taxes() ) {
			$$self{total} += $Tax->amount();
$log->debug("tax $$Tax{amount} toal: $$self{total}");
		} # end foreach Tax
	} # end if
	return Math::Round::nearest( .01, $$self{total} );
} # end sub total

sub interest {
	my ( $self ) = @_;
	if ( @_ == 2 ) {
		$$self{interest} = $_[1];
	} # end if

	if ( (!$$self{posted}) or ( ! defined $$self{interest} ) ) {
		$$self{interest} = misc::sum( map { $_->amount() } openprint::Invoice_Interest->find( invoice_id=>$$self{id}) );
	} # end if
	return $$self{interest};
} # end sub interest

sub paid {
	my $self = shift;
	if ( @_ ) {
		$$self{paid} = $_[0];
	} # end if
	if ( (!$$self{posted}) or !defined $$self{paid} ) {
    # Amount is stored both in the invoice_payment and in the payment
    # Maybe the value in the invoice_payment record should be currency adjusted
		$$self{paid} = misc::sum( map { $_->amount() } openprint::Invoice_Payment->find( invoice_id=>$$self{id}) );
	} # end if
	return $$self{paid};
} # end sub paid

sub paid_value {
	my $self = shift;
	if ( @_ ) {
		$$self{paid_value} = $_[0];
	} # end if
	if ( (!$$self{posted}) or !defined $$self{paid_value} ) {
    # Amount is stored both in the invoice_payment and in the payment
    # Maybe the value in the invoice_payment record should be currency adjusted
		$$self{paid_value} = misc::sum( map { $_->value() } openprint::Invoice_Payment->find( invoice_id=>$$self{id}) );
	} # end if
	return $$self{paid_value};
} # end sub paid_value

sub add_Payment {
	my ( $self, $Payment ) = @_;
	if ( $Payment->remaining() ) {
		if ( $self->owing() ) {
			my $error;
			my $amount = $Payment->remaining() > $self->owing() ? $self->owing() : $Payment->remaining();
			my $IP = new openprint::Invoice_Payment();
			$error .= $IP->save({ payment_id=>$Payment->id(), invoice_id=>$$self{id}, amount=>$amount });
			$error .= $Payment->save( { remaining => undef } );
			$self->paid( undef );
			$error .= $self->save();
			return $error;
		} else {
			return 'Invoice is already paid.';
		} # end if
	} elsif ( ! $Payment->remaining() ) {
		return 'No money left in payment.';
	} elsif ( ! $self->owing() ) {
		return 'Nothing owing in invoice.';
	} # end if
} # end sub add_Payment

sub del_Payment {
	my ( $self, $Payment ) = @_;

	foreach my $IP ( openprint::Invoice_Payment->find('invoice_id'=>$$self{id},'payment_id'=>$$Payment{id})) {
		$IP->delete();
	} # endforeach$IP
	$Payment->remaining( undef );
	$Payment->save();
	$self->paid( undef );
	$self->save();
} # end sub del_Payment

sub Payments {
	my ( $self ) = @_;
  if ( ! $_[0]{Payments} ) {
    $_[0]{Payments} = [ openprint::Invoice_Payment->find( invoice_id=>$$self{id} ) ];
  }
  return @{$_[0]{Payments}};
} # end sub Payments

sub Logs {
	return openprint::Log->find(object_id=>$_[0]{id},object_type=>'openprint::Invoice', order=>'date_time');
} # end sub Logs

sub send {
	my ( $self, $To ) = @_;

	my $Email = new openprint::Email();

	my %data = (
			Invoice => $self,
			uri => 'invoice',
			Currency	=>	$self->Currency(),
	);

  my $skin_path = '';
  if ( -e ($openprint::config{SkinPath}.'/'.$self->Invoicer()->name() ) ) {
  $skin_path = '/'.$self->Invoicer()->name();
  $openprint::log->debug("Have skinpath at $skin_path");
} else {
  $openprint::log->debug("Have no skinpath at " . $openprint::config{SkinPath}.'/'.$self->Invoicer()->name() );
}

	my $email_template = ssi::slurp_content($skin_path.'/email_template.html');
	$email_template = ssi::slurp_content('/email_template.html') if ! $email_template;

  my $invoice_template = ssi::slurp_content($skin_path.'/invoice_template.html');
  $invoice_template = ssi::slurp_content('/invoice_template.html') if ! $invoice_template;

	my @attachments;
	$data{ReplacementText} = ssi::include($skin_path.'/email_content/invoice_body.html', \%data);
	$data{ReplacementText} = ssi::include('/email_content/invoice_body.html', \%data) if ! $data{ReplacementText};
  $Email->html_body( ssi::variable_substitution( \$email_template, \%data ) );

	$data{ReplacementText} = ssi::include( '/email_content/invoice.html', \%data );
	my $invoice_html = Encode::encode('utf-8',ssi::variable_substitution( \$invoice_template, \%data ) );
  $Email->add_pdf_attachment_from_html('Invoice'.$$self{id}, $invoice_html);

	$Email->add_html_attachment("Invoice$$self{id}.html", $invoice_html ) if $To and ( $To->email() =~ /^iconnor/);
	my $results = $Email->send(
		BCC			=>	new openprint::User( $session{user_id} ),
		#TO			=>	new openprint::User( $session{user_id} ),
		TO			=>	( $To ? $To : [$self->Invoicee()->AccountingContacts()] ),
		FROM		=>	$config{AccountingEmail},
		ATTACHMENTS	=>	\@attachments,
		SUBJECT		=>	sprintf('%1$s Invoice (%2$d) is now available.', $self->Invoicer()->name(), $$self{id} ),
	);
	(new openprint::Log())->save({Object=>$self, action=>'Invoice Sent', note=>$results});
	return $results;
} # end sub send

sub Products {
	return openprint::Invoiced_Product->find(invoice_id=>$_[0]{id}, order=>'id');
} # end sub Products
sub Projects {
	return openprint::Invoiced_Project->find(invoice_id=>$_[0]{id}, order=>'id');
} # end sub Projects
sub Orders {
	return openprint::Order_Invoice->find(invoice_id=>$_[0]{id}, order=>'order_id');
} # end sub Orders

sub Interests {
	my $self = shift;
	my %args = @_;
	$args{invoice_id} = $$self{id};
	$args{order} = 'compounded_on' if ! $args{order};
	return openprint::Invoice_Interest->find(%args);
} # end sub Interests

sub calculate_interests {
	my $self = shift;
} # end sub calculate_interests

sub Taxes {
	my ( $self ) = @_;

	if ( @_ > 1 and ! defined $_[1] ) {
$log->debug("Getting rid of taxes") if $debug;
		if ( $$self{id} ) {
			foreach ( openprint::Invoice_Tax->find( invoice_id=>$$self{id} ) ) {
				$_->destroy();
			} # end foreach	 Tax
		}
		$$self{Taxes} = [];
	} # end if

	if ( ( ! $$self{Taxes} ) and $$self{posted} ) {
		$log->debug("Loading taxes");
		@{$$self{Taxes}} = openprint::Invoice_Tax->find( invoice_id=>$$self{id} );
	} # end if

	if ( ! ( $$self{Taxes} and @{$$self{Taxes}} ) ) {
$log->debug("Generating taxes");
		$$self{Taxes} = [];
		foreach my $Tax ( openprint::Tax->find(
					'period_start null_or_<='	=>	$$self{created_on},
					'period_end null_or_>='		=>	$$self{created_on},
					country	=>	$self->Invoicee()->country(),
					state	=>	$self->Invoicee()->state()),
				) {
			my $T = new openprint::Invoice_Tax();
			$T->set({
				tax_id		=>	$$Tax{id},
				rate 		=>	$$Tax{rate},
			});
			$T->save({ invoice_id	=>	$$self{id} } ) if $$self{id};
			push @{$$self{Taxes}}, $T;
		} # end foreach Tax
	} # end if
	return @{$$self{Taxes}};
} # end sub Taxes

sub Tax {
	my ( $self, $Tax ) = @_;
	if ( ! $_[0]{Taxes} ) {
		@{$_[0]{Taxes}} = openprint::Invoice_Tax->find( invoice_id=>$_[0]{id} );
	} # end if

	foreach my $IT ( @{$_[0]{Taxes}} ) {
		if ( $$IT{tax_id} == $$Tax{id} ) {
			return $IT;
		}
	} # end if
	return new openprint::Invoice_Tax();
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
	if ( $openprint::session{user_type} eq 'A' ) {
	return 1;
	}
	if ( $openprint::session{user_type} eq 'E' ) {
		if ( $_[0]->Invoicee()->salesrep_id() == $openprint::session{user_id} ) {
			return 1;
		}
	}
	return 0;
} # end sub can_view

sub can_send {
	my $User = $_[1] ? $_[1] : $openprint::User;

	if ( $$User{type} eq 'A' ) {
		$log->debug("$$User{firstname} Is administrator") if $debug;
		return 1;
	} # end if

	if ( openprint::usergroup::is_user_in( ['Accounting'], $$User{id} ) )  {
		$log->debug("$$User{firstname} Is in Accounting'") if $debug;
		return 1;
	} # end i
	return 0;
} # end sub can_send

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

sub paid_on {
  if ( ! $_[0]{paid_on} ) {
    foreach my $Invoice_Payment ( reverse sort { $a->Payment()->received_on() cmp $b->Payment()->received_on() } $_[0]->Payments() ) {
      $log->debug( $Invoice_Payment->Payment()->to_string() );
      $_[0]{paid_on} = $Invoice_Payment->Payment()->received_on();
    }
  }
  return $_[0]{paid_on};
} # end sub paid_on

sub Currency {
  my $self = shift;
  if ( ! $$self{Currency} ) {
    $$self{Currency} = new openprint::Currency($$self{currency_id});
  }
  return $$self{Currency};
} # end sub Currency

sub first_sent_on {
	if ( ! exists $_[0]{first_sent_on} ) {
		if ( my $Log = openprint::Log->find_one(
					object_id=>$_[0]{id},
					object_type=>'openprint::Invoice', 
					action=>'Invoice Sent',
					order	=>	'id ASC',
					) ) {
			$_[0]{first_sent_on} = $Log->date_time();
		}
	} # end ! exists first_sent_on
	return $_[0]{first_sent_on};
} # end sub first_sent_on

sub paid_days {
  if ( ! $_[0]{paid_on} ) {
    $openprint::log->debug("No paid_on");
    return;
  }
  my $sent = $_[0]->first_sent_on();
  if ( ! $sent ) {
    $openprint::log->debug("No sent");
    return;
  }

  my $paid_time = Date::Parse::str2time( $_[0]{paid_on} );
  my $sent_time = Date::Parse::str2time( $sent );
  my $days = int( ($paid_time-$sent_time) / 86400 );
  return $days;
}

sub sent_on {

  if ( ! $_[0]{sent_on} ) {
    ( $_[0]{sent_on} ) = sql::execute( undef, undef, q`
      SELECT MIN(date_time) FROM logs WHERE object_id=?
      AND object_type_id=(SELECT id FROM Object_Types WHERE name='openprint::Invoice') 
      AND action_id=(SELECT id FROM log_actions WHERE name='Invoice Sent') 
      LIMIT 1`, $_[0]{id});
  }
  return $_[0]{sent_on};
}

1;
__END__
