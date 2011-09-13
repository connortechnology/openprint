use strict;
package openprint::PurchaseOrder;
our @ISA = qw(openprint::Object);
require openprint::Object;

use openprint ();
use vars qw( $debug %variable $log $dbh %config %session $table $serial %fields %find_fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

require sql;
require ssi;
require misc;
require openprint::Company;
require openprint::Currency;
require openprint::User;
require openprint::Tax;
require openprint::PurchaseOrder_Content;
require openprint::PurchaseOrder_Log;
require openprint::PurchaseOrder_Tax;
require openprint::Email;
require openprint::Manifest;

$debug = 1;

$table = 'PurchaseOrders';
$serial = 'Purchaseorders_id_seq';

%fields = (
	'id'				=>	'id',
	'company_id'		=>	'company_id',
	'currency_id'		=>	'currency_id',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'created_by'		=>	'created_by',
	'authorized'		=>	'authorized',
	'authorized_by'		=>	'authorized_by',
	'authorized_on'		=>	'authorized_on',
	'delivered_on'		=>	'delivered_on',
	'delivered_on_switch'		=>	'delivered_on_switch',
	'total'				=>	'total',
	'subtotal'			=>	'subtotal',
	'deleted'			=>	'deleted',
	'supplier_id'		=>	'supplier_id',
	'shipping_method'	=>	'shipping_method',
	'shipping_terms'	=>	'shipping_terms',
	'vendor_contact'	=>	'vendor_contact',
	'vendor_name'		=>	'vendor_name',
	'vendor_address1'	=>	'vendor_address1',
	'vendor_address2'	=>	'vendor_address2',
	'vendor_city'		=>	'vendor_city',
	'vendor_country'	=>	'vendor_country',
	'vendor_state'		=>	'vendor_state',
	'vendor_postalcode'	=>	'vendor_postalcode',
	'vendor_phone'		=>	'vendor_phone',
	'vendor_fax'		=>	'vendor_fax',
	'vendor_sms'		=>	'vendor_sms',
	'vendor_email'		=>	'vendor_email',
	'shipto_contact'	=>	'shipto_contact',
	'shipto_name'		=>	'shipto_name',
	'shipto_address1'	=>	'shipto_address1',
	'shipto_address2'	=>	'shipto_address2',
	'shipto_city'		=>	'shipto_city',
	'shipto_country'	=>	'shipto_country',
	'shipto_state'		=>	'shipto_state',
	'shipto_postalcode'	=>	'shipto_postalcode',
	'shipto_phone'		=>	'shipto_phone',
	'shipto_mobile'		=>	'shipto_mobile',
	'shipto_fax'		=>	'shipto_fax',
	'shipto_sms'		=>	'shipto_sms',
	'shipto_email'		=>	'shipto_email',
	'manifest_id'		=>	'manifest_id',
	'cancelled'			=>	'cancelled',
);

%find_fields = (
	'docket'	=>	'(SELECT docket FROM PurchaseOrder_Contents WHERE PurchaseOrder_Contents.po_id=PurchaseOrders.id)',
	'item_id'	=>	'(SELECT item_id FROM PurchaseOrder_Contents WHERE PurchaseOrder_Contents.po_id=PurchaseOrders.id)',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
);

%defaults = (
	'supplier_id'	=>	undef,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'deleted'		=>	0,
	'currency_id'	=> $session{'Currency_id'},
	'tax'			=>	0,
	'total'			=>	0,
	'subtotal'		=>	0,
	'manifest_id'	=>	undef,
	'cancelled'		=>	0,
);

sub save {
	my ( $self, $param ) = @_;

$log->debug("Sacving PO");
	# force recalculation
	$self->subtotal(undef);
	foreach my $Tax ( $self->Taxes() ) {
		$Tax->PurchaseOrder( $self );
		$Tax->amount(undef);
	} # end foreach Tax
	$self->total(undef);
	if ( ! $$self{'currency_id'} ) {
		my $Currency = openprint::Currency::get_current();
		$$self{'currency_id'} = $Currency->id();
	} # end if
	my $error = $self->SUPER::save( $param );

	# Taxes
	foreach my $T ( $self->Taxes() ) {
		$error .= $T->save({'purchaseorder_id'=>$$self{'id'}, 'PurchaseOrder'=>$self});
	} # end foreach

	return $error;
} # end sub save

sub Currency {
	my ( $self ) = @_;
	if ( ! $$self{'currency_id'} ) {
		$$self{'currency_id'} = openprint::Currency::get_current()->id();
	} # end if
	return new openprint::Currency( $_[0]{currency_id} );
} # end sub Currency

sub Supplier {
	return new openprint::Company( $_[0]{supplier_id} );
} # end sub Supplier
sub Creator {
	return new openprint::User( $_[0]{created_by} );
} # end sub Creator
sub Authorized_By {
	return new openprint::User( $_[0]{authorized_by} );
} # end sub Authorized_By

sub Contents {
	if ( $_[0]{'id'} and ! $_[0]{'Contents'} ) {
		@{$_[0]{'Contents'}} = openprint::PurchaseOrder_Content->find('po_id'=>$_[0]{'id'},'order'=>'id');
	} # end if
	return @{$_[0]{'Contents'}} if $_[0]{'Contents'};
	return ();
} # end sub Contents

sub send_approval_required_notification {
	my ( $self ) = @_;

	my $Me = new openprint::User( $session{'user_id'} );
	my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
	my %info;
	$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/purchase_order_notification.html\"-->";
	$info{'From'} = $Me;
	$info{'PurchaseOrder'} = $self;

	foreach my $U ( openprint::User::find('company_id'=>$Me->company_id(),'purchasing_limit_>='=>$self->total() ) ) {
		next if $U->id() == $Me->id();
		next if ! Email::Valid->address($U->email() );

		$_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%info ) ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $config{'Mail Server'},
				FROM    => sprintf( '"%s" <%s>', $Me->name(), $Me->email() ),
				TO      => sprintf( '"%s" <%s>', $U->name(), $U->email() ),
				SUBJECT => 'Purchase Order requiring approval: ' . $self->id(),
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end foreach U
} # end sub send_approval_required_notification

sub send_to_vendor {
	my ( $self ) = @_;

	my $From = new openprint::User( $session{'user_id'} );
	
	my %info = (
			'PurchaseOrder'	=>	$self,
			'From'			=>	$From,
			);
	my @attachments = ();

	my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
	$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/purchase_order_body.html\"-->";
	$_ = MIME::QuotedPrint::encode_qp( ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%info ) );
	push @attachments, ('', $_, 'text/html', 'quoted-printable');

	my $purchase_order = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/purchase_order.html' );
	push @attachments, $From->Company()->name().'-PO'.$$self{'id'}.'.html', MIME::QuotedPrint::encode_qp( Encode::encode('utf-8',ssi::variable_substitution( undef, $log, $dbh, \$purchase_order, \%info ) ) ), 'text/html', 'quoted-printable';

	my %mail = (
			SMTP    => $config{'Mail Server'},
			FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
			SUBJECT => 'Purchase Order ' . $self->id() . ' from ' . $self->vendor_name(),
			);

	my $results = 'PO ' . $$self{'id'} . ' emailed to the following recipients:<br/>';
	foreach my $email ( split(',', $self->vendor_email() ) ) {
		$email =~ s/^\s*(.*)\s*$/$1/;
		next if ! $email;
		$mail{'TO'}	= $email;
		misc::send_email_with_attachment( $log, \%mail, @attachments );
		$results .= ssi::htmlize( $mail{'TO'} ) . '<br/>';
	} # end foreach
	if ( $self->shipto_email() and ( $self->vendor_email() ne $self->shipto_email() ) ) {
		my $Email = new openprint::Email();
		$results .= $Email->send( 
				TO	=>	[ split(',', $self->shipto_email() ) ],
				FROM	=>	$mail{'FROM'},
				SUBJECT	=>	$mail{'SUBJECT'},
				ATTACHMENTS =>	\@attachments,
				);
	} # end if
	if ( $self->notifications() ) {
		$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/purchase_order_notification.html\"-->";
		$_ = MIME::QuotedPrint::encode_qp( ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%info ) );
		@attachments = ('', $_, 'text/html', 'quoted-printable');
		my $Email = new openprint::Email();
		$results .= 'Notifications: <br/>' . $Email->send( 
				TO	=>	[ map { new openprint::User( $_ ) } $self->notifications() ],
				FROM	=>	$mail{'FROM'},
				SUBJECT	=>	$mail{'SUBJECT'},
				ATTACHMENTS =>	\@attachments,
				);
	} # end if

	my $L = new openprint::PurchaseOrder_Log();
	$L->save({
			'user_id'	=>	$session{'user_id'},
			'po_id'		=>	$$self{'id'},
			'reason'	=>	$results,
			});

	return $results;

} # end sub send_to_vendor

sub subtotal {
	if ( @_ > 1 ) {
		$_[0]{'subtotal'} = $_[1];
	} # end if
	if ( ! defined $_[0]{'subtotal'} ) {
		$_[0]{'subtotal'} = 0;
$openprint::log->debug("subtotal");
		foreach my $C ( $_[0]->Contents() ) {
$openprint::log->debug("Content : " . $C->total() );
			$_[0]{'subtotal'} += $C->total();
		} # end foreach
		$_[0]{'subtotal'} = sprintf( '%.2f', $_[0]{'subtotal'} );
	} # end if
$openprint::log->debug("subtotal: $_[0]{subtotal}");
	return $_[0]{'subtotal'};
} # end sub subtotal

sub total {
	my ( $self ) = @_;
	if ( @_ == 2 ) {
		$$self{'total'} = $_[1];
	} # end if
	if ( ! $$self{'total'} ) {
		$$self{'total'} = $self->subtotal();
        foreach my $Tax ( $self->Taxes() ) {
            $$self{'total'} += $Tax->amount();
        } # end foreach Tax
		$$self{'total'} = sprintf('%.2f', $$self{'total'} );
	} # end if
	return $$self{'total'};
} # end sub total

sub Company {
	return new openprint::Company( $_[0]{'company_id'} );
} # end sub Company

sub authorize {
	my ( $self ) = @_;
	$$self{'authorized'} = 1;
	$$self{'authorized_by'} = $session{'user_id'};
	$$self{'authorized_on'} = 'NOW()';
	my $L = new openprint::PurchaseOrder_Log();
	$L->save({
			'po_id'		=> $$self{'id'},
			'user_id'	=> $session{'user_id'},
			'reason'	=> 'Authorized by ' . new openprint::User( $session{'user_id'} )->name(),
			});
	return $self->save();
} # end sub authorize

sub decline {
	my ( $self, $reason ) = @_;
	$$self{'authorized'} = 0;
	$$self{'authorized_by'} = $session{'user_id'};
	$$self{'authorized_on'} = 'NOW()';
	my $L = new openprint::PurchaseOrder_Log();
	$L->save({
			'po_id'		=> $$self{'id'},
			'user_id'	=> $session{'user_id'},
			'reason'	=> 'Declined by ' . new openprint::User( $session{'user_id'} )->name() . ': ' . $reason,
			});
	return $self->save();
} # end sub decline

sub notifications {
	my ( $self, $new ) = @_;
	if ( $new ) {
		@{$$self{'notifications'}} = @{$new};
		if ( $$self{'id'} ) {
			sql::execute( undef, undef, 'DELETE FROM PurchaseOrder_Notifications WHERE po_id=?', $$self{'id'} );
			foreach ( @{$$self{'notifications'}} ) {
				sql::insert( undef, undef, 'PurchaseOrder_Notifications', ['po_id', $$self{'id'}, 'user_id', $_ ] );
			} # end foreach
		} # end if
	} # end if
	if ( $$self{'id'} and ! exists $$self{'notifications'} ) {
		@{$$self{'notifications'}} = sql::execute( undef, undef, 'SELECT user_id FROM PurchaseOrder_Notifications WHERE po_id=?', $$self{'id'} );
	} # end if
	return $$self{'notifications'} ? @{$$self{'notifications'}} : ();
} # end sub notifications

sub Logs {
	my ( $self ) = @_;

	return openprint::PurchaseOrder_Log::find( 'po_id'=>$$self{'id'}, 'order'=>'created_on DESC' );
} # end sub Logs

sub is_FSC {
	my ( $self ) = @_;
	foreach my $C ( $self->Contents() ) {
		return 1 if $C->description() =~ /FSC/i;
	} # end foreach C
} # end sub is_FSC

sub is_PEFC {
	my ( $self ) = @_;
	foreach my $C ( $self->Contents() ) {
		return 1 if $C->description() =~ /PEFC/i;
	} # end foreach C
} # end sub is_PEFC
sub copy {
	my $self = shift;
	my $New = new openprint::PurchaseOrder();
	@$New{keys %fields} = @$self{keys %fields};
	foreach ( 'id', 'authorized', 'authorized_by', 'authorized_on', 'delivered_on' ) {
		delete $$New{$_};
	} # end foreach
	$$New{'created_by'} = $session{'user_id'};
	return $New;
} # end sub copy
sub Manifest {
	return new openprint::Manifest( $_[0]{'manifest_id'} );
} # end sub Manifest

sub Taxes {
    my ( $self ) = @_;
    if ( $$self{'id'} and ! $$self{'Taxes'} ) {
        @{$$self{'Taxes'}} = openprint::PurchaseOrder_Tax->find('purchaseorder_id'=>$$self{'id'});
    } # end if
    if ( $$self{'vendor_country'} and $$self{'vendor_state'} and ! ( $$self{'Taxes'} and @{$$self{'Taxes'}} ) ) {
        foreach my $Tax ( openprint::Tax->find(
                    #'period_start_null_or_<='   =>  $$self{'created_on'},
                    #'period_end_null_or_>='     =>  $$self{'created_on'},
                    'country'   =>  $self->Supplier()->country(),
                    'state'     =>  $self->Supplier()->state(),
                ) ) {
            my $T = new openprint::PurchaseOrder_Tax();
            $T->set({
				'PurchaseOrder'		=>	$self,
                'tax_id'    		=>  $$Tax{'id'},
                'rate'      		=>  $$Tax{'rate'},
            });
			if ( $$self{'id'} ) {
				$T->save({'purchaseorder_id'	=>  $$self{'id'}});
			} # end if
            push @{$$self{'Taxes'}}, $T;
        } # end foreach Tax
    } # end if
	if ( @_ > 1 and $$self{'id'} ) {
		my @new_taxes = openprint::Tax->find(
				#'period_start_null_or_<='   =>  $$self{'created_on'},
				#'period_end_null_or_>='     =>  $$self{'created_on'},
				'country'   =>  $self->Supplier()->country(),
				'state'     =>  $self->Supplier()->state(),
		   );

		# Clear out any no longer valid taxes
		foreach my $Tax ( @{$$self{'Taxes'}} ) {
			if ( ! sets::isin( $Tax->tax_id(), [ map { $_->id() } @new_taxes ] ) ) {
				$Tax->delete();
			} # end if
		} # end foreach old Tax
        @{$$self{'Taxes'}} = openprint::PurchaseOrder_Tax->find('purchaseorder_id'=>$$self{'id'});
		if ( @new_taxes != @{$$self{'Taxes'}} ) {
			foreach my $Tax ( @new_taxes ) {
				if ( ! sets::isin( $Tax->id(), [ map { $_->tax_id() } @{$$self{'Taxes'}} ] ) ) {
					my $T = new openprint::PurchaseOrder_Tax();
					$T->save({
							'purchaseorder_id'  =>  $$self{'id'},
							'tax_id'            =>  $$Tax{'id'},
							'rate'              =>  $$Tax{'rate'},
							});
					push @{$$self{'Taxes'}}, $T;
				} # end if
			} # end foreach Tax	
		} # end if have new taxes
	} # end if recalculate
    return $$self{'Taxes'} ? @{$$self{'Taxes'}} : ();
} # end sub Taxes

sub Tax {
    my $result = openprint::PurchaseOrder_Tax->find_one('purchaseorder_id'=>$_[0]{'id'}, 'tax_id'=>$_[1]->id() );
    if ( ! $result ) {
        return new openprint::PurchaseOrder_Tax();
    } # end if
    return $result;
} # end sub Tax

sub can_edit {
	return 1 if ! $_[0]{'id'};
	if ( 
			( $openprint::session{'user_type'} eq 'A' )
			or ( $openprint::session{'user_id'} eq $_[0]{'created_by'} )
			or ( openprint::usergroup::is_user_in( ['Accounting'], $openprint::session{'user_id'} ) ) 
	   ) {
		return 1;
	} # end if
	return 0;
} # end sub can_edit
sub can_view {
	return 1 if ! $_[0]{'id'};
	if ( 
			( $openprint::session{'user_type'} eq 'A' )
			or ( sets::isin( $_[0]{'created_by'}, [ $openprint::session{'user_id'}, new openprint::User($openprint::session{'user_id'})->assistant_ids(), new openprint::User($openprint::session{'user_id'})->csr_ids() ] ) )
			or ( openprint::usergroup::is_user_in( ['Accounting','Shipping','Inventory'], $openprint::session{'user_id'} ) ) 
			
			or ( sets::isin( $openprint::session{'user_id'}, [ map { $_->Order()->salesrep_id() } $_[0]->Contents() ] ) )
	   ) {
$openprint::log->debug("Can view");
		return 1;
	} # end if
$openprint::log->debug("Cannot view");
	return 0;
} # end sub can_view

1;
__END__
