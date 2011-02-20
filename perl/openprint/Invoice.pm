package openprint::Invoice;
@ISA = qw(openprint::Object);
#use Carp qw(cluck);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require openprint::Currency;
require openprint::Company;
require openprint::Service;
require openprint::InvoiceLog;
require openprint::Tax;
require openprint::Invoiced_Product;
require openprint::Invoice_Interest;
require openprint::Invoice_Payment;
require openprint::Invoice_Tax;
require openprint::Timetrack;

use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );

require sql;
$debug = 1;

$table = 'invoices';
$serial = 'invoices_id_seq';

%fields = (
	'id'				=>	'id',
	'invoicer_id'		=>	'invoicer_id',
	'invoicee_id'		=>	'invoicee_id',
	'external_notes'	=>	'external_notes',
	'internal_notes'	=>	'internal_notes',
	'monthly_interest'	=>	'monthly_interest',
	'posted'			=>	'posted',
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
	'bad_debt'			=>	'bad_debt',
);

%transforms = (
);
%defaults = (
	'created_on'	=> q`'NOW()'`,
	'updated_on'	=> q`'NOW()'`,
	'deleted'		=> 0,
	'posted'		=> 0,
	'interest'		=> undef,
	'monthly_interest'		=> undef,
	'paid'			=> undef,
	'bad_debt'			=> 0,
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
	return sprintf('%.2f', $_[0]->total() + $_[0]->interest() - $_[0]->paid() );
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
	return sprintf('%.2f', $$self{'subtotal'} );
} # end sub subtotal

sub total {
	my ( $self ) = @_;

	if ( ! $$self{'id'} ) {
		$log->error('Invoice:total no id! ref:' . (ref $self) . ' self:' . $self);
		return;
	} # end if

	if ( (!$$self{'posted'}) or ( ! defined $$self{'total'} ) ) {
		$$self{'total'} = $self->subtotal();
		foreach my $Tax ( $self->Taxes() ) {
			$$self{'total'} += $Tax->amount();
		} # end foreach Tax
	} # end if
	return sprintf('%.2f', $$self{'total'} );
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
		my $amount = $Payment->remaining() > $self->owing() ? $self->owing() : $Payment->remaining();	
		my $IP = new openprint::Invoice_Payment();
		$IP->save({'payment_id'=>$Payment->id(),'invoice_id'=>$$self{'id'}, 'amount'=>$amount});
		$Payment->remaining( undef ); # force update
		$Payment->save();
		$self->paid( undef );
		$self->save();
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
		'invoice_id'	=> $$self{'id'},
		'user_id'		=> $user_id ? $user_id : $session{'user_id'},
		'description'	=> $desc,
	} );
	
} # end sub add_to_log

sub send {
	my ( $self ) = @_;

	my %data;
	$data{'Invoice'} = $self;
	$data{'uri'} = 'invoice';
	my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
	my @attachments;
	$data{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/invoice_body.html' );
	$data{'ReplacementText'} = ssi::variable_substitution( \$data{'ReplacementText'}, \%data );
	push @attachments, '', MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%data ) ) ), 'text/html', 'quoted-printable';
	$data{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/invoice.html' );
	$data{'ReplacementText'} = ssi::variable_substitution( \$data{'ReplacementText'}, \%data );
	push @attachments, 'Invoice '.$$self{'id'}.'.html', MIME::QuotedPrint::encode_qp( Encode::encode('utf-8',ssi::variable_substitution( \$email_template, \%data ) ) ), 'text/html', 'quoted-printable';

	my $Email = new openprint::Email();
	my $results = $Email->send(
		'BCC'			=>	sprintf('"%s %s" <%s>', new openprint::User( $session{'user_id'} )->get('firstname','lastname','email') ),
		'TO'			=>	[$self->Invoicee()->AccountingContacts()],
		'FROM'			=>	$config{'AccountingEmail'},
		'ATTACHMENTS'	=>	\@attachments,
		'SUBJECT'		=>	sprintf('Your Invoice (%1$d) is now available.', $$self{id} ),
	);
$openprint::log->debug("Email results: $results");
	$self->add_to_log( $results );
	return $results;
} # end sub send

sub Products {
	return openprint::Invoiced_Product->find('invoice_id'=>$_[0]{'id'},'order'=>'id');
} # end sub Products

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
		foreach my $Tax ( openprint::Tax->find(
					'period_start_null_or_<='	=>	$$self{'created_on'},
					'period_end_null_or_>='		=>	$$self{'created_on'},
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
	my $result = openprint::Invoice_Tax->find_one('invoice_id'=>$_[0]{'id'}, 'tax_id'=>$_[1]->id() );
	if ( ! $result ) {
		return new openprint::Invoice_Tax();
	} # end if
	return $result;
} # end sub Tax

1;
__END__
