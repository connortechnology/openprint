use strict;
package openprint::Payment;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );

require sql;
require openprint::PaymentType;
require openprint::Invoice_Payment;
require openprint::Currency;
require openprint::Company;
require openprint::Order;

$debug = 0;
$table = 'payments';
$serial = 'payments_id_seq';

%fields = (
	'id'				=>	'id',
	'order_id'			=>	'order_id',
	'recipient_id'		=>	'owner_id',
	'payor_id'			=>	'payor_id',
	'amount'			=>	'amount',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'method'			=>	'method',
	'currency_id'		=>	'currency_id',
	'transaction_id'	=>	'transaction_id',
	'memo'				=>	'memo',
	'completed'			=>	'completed',
	'received_on'		=>	'received_on',
	'remaining'			=>	'remaining',
	'deleted'			=>	'deleted',
	'type_id'			=>	'type_id',
);

%transforms = (
	amount	=>	[ 's/[^\-\d\.]//g' ],
);
%defaults = (
	order_id	=>	undef,
	created_on	=> q`'NOW()'`,
	updated_on	=> q`'NOW()'`,
	received_on	=>	undef,
	completed	=>	1,
	deleted		=>	0,
	owner_id	=>	q`$openprint::config{owner_id}`,
	amount		=>	undef,
);

sub destroy {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM ledgers WHERE payment_id=?}, $$self{'id'} );
    return $self->SUPER::destroy();
} # end sub destroy

sub Payor {
	return new openprint::Company( $_[0]{payor_id} );
} # end sub Payor

sub Recipient {
	return new openprint::Company( $_[0]{owner_id} );
} # end sub Recipient

sub Currency {
	return new openprint::Currency( $_[0]{currency_id} );
} # end sub Currency
sub Order {
	return new openprint::Order( $_[0]{order_id} );
} # end sub Order

sub remaining {
	my $self = shift;
	if ( @_ ) {
		$$self{remaining} = $_[0];
	} # end if
	if ( ! defined $$self{remaining} ) {
		$$self{'remaining'} = $$self{'amount'} - misc::sum( map { $_->amount() } openprint::Invoice_Payment->find('payment_id'=>$$self{'id'}) );
	} # end if
	return $$self{'remaining'};
} # end sub remaining

sub Type {
	return new openprint::PaymentType( $_[0]{'type_id'} );
} # end sub Type

sub send_receipt {
	my ( $self ) = @_;

	my %data;
	$data{Payment} = $self;
	$data{uri} = 'payment';
	$data{User} = new openprint::User($openprint::session{user_id});
	my $email_template = ssi::slurp_content( '/email_template.html' );
	my @attachments;
	$data{'ReplacementText'} = ssi::include( '/email_content/payment_receipt.html', \%data );

	my $Email = new openprint::Email();
	$Email->html_body( ssi::variable_substitution( \$email_template, \%data ) );
	my $results = $Email->send(
		#TO			=>	new openprint::User( $openprint::session{'user_id'} ),
		TO			=>	[map { $_->User() } $self->Payor()->AccountingContacts()],
		BCC			=>	new openprint::User( $openprint::session{'user_id'} ),
		FROM		=>	$data{User},
		#'ATTACHMENTS'	=>	\@attachments,
		SUBJECT		=>	'Thank you for your payment!',
	);
	$self->add_to_log( $results );
	return $results;
	
} # end sub send_receipt

sub save {
    my ( $self, $data ) = @_;
    my $error = $self->SUPER::save( $data );
	if ( (! $error) and $$self{order_id} ) {
		$self->Order()->paid(undef);
	} # end if
	return $error;
} # end sub save

sub Invoices {
	if ( ! exists $_[0]{Invoices} ) {
		$_[0]{Invoices} = [ openprint::Invoice_Payment->find( payment_id=>$_[0]{id}, order=>'invoice_id' ) ];
	} # end if
	return @{$_[0]{Invoices}};
} # end sub Invoices

1;
__END__
