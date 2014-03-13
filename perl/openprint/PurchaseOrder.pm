use strict;
use Math::Round qw(nearest);
package openprint::PurchaseOrder;
our @ISA = qw(openprint::Object);
require openprint::Object;

use openprint ();
use vars qw( $debug $log $dbh %config %session $table $serial %fields %find_fields %transforms %defaults );
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
require openprint::Object_Payment;
require File::Slurp;
require MIME::QuotedPrint;
require MIME::Base64;
require openprint::Object_Asset;
require openprint::Asset;

$debug = 0;

$table = 'purchaseorders';
$serial = 'purchaseorders_id_seq';

%fields = (
	'id'				=>	'id',
	num					=>	'num',
	'company_id'		=>	'company_id',
	contact_id			=>	'contact_id',
	'currency_id'		=>	'currency_id',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'created_by'		=>	'created_by',
	'authorized'		=>	'authorized',
	'authorized_by'		=>	'authorized_by',
	'authorized_on'		=>	'authorized_on',
	'delivered_on'		=>	'delivered_on',
	delivered_on_switch	=>	'delivered_on_switch',
	'total'				=>	'total',
	'subtotal'			=>	'subtotal',
	'deleted'			=>	'deleted',
	'supplier_id'		=>	'supplier_id',
	'shipping_method'	=>	'shipping_method',
	'shipping_terms'	=>	'shipping_terms',
	'vendor_contact'	=>	'vendor_contact',
	contact_id			=>	'contact_id',
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
	docket	=>	'(SELECT docket FROM PurchaseOrder_Contents WHERE PurchaseOrder_Contents.po_id=PurchaseOrders.id)',
	item_id	=>	'(SELECT item_id FROM PurchaseOrder_Contents WHERE PurchaseOrder_Contents.po_id=PurchaseOrders.id)',
);

%transforms = (
);

%defaults = (
	created_on	=> q`'NOW()'`,
	updated_on	=> q`'NOW()'`,
	deleted		=>	0,
	currency_id	=> q`$session{'Currency_id'}`,
	total			=>	0,
	subtotal		=>	0,
	manifest_id	=>	undef,
	cancelled		=>	0,
	supplier_id		=>	undef,
	contact_id		=>	undef,
);

sub save {
	my ( $self, $param, $force_insert ) = @_;

	$self->set( $param );

	my $ac = sql::start_transaction( $openprint::dbh );
	$dbh->do( "LOCK TABLE $openprint::PurchaseOrder_Tax::table IN EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
	# force recalculation
	$self->subtotal(undef);
	foreach my $Tax ( $self->Taxes(1) ) {
		$Tax->PurchaseOrder( $self );
		$Tax->amount(undef);
	} # end foreach Tax
	$self->total(undef);
	if ( ! $$self{'currency_id'} ) {
		my $Currency = openprint::Currency::get_current();
		$$self{'currency_id'} = $Currency->id() if $Currency;
	} # end if
	my $error = $self->SUPER::save({}, $force_insert );

	# Taxes
	foreach my $T ( $self->Taxes() ) {
		$error .= $T->save({'purchaseorder_id'=>$$self{'id'}, 'PurchaseOrder'=>$self});
	} # end foreach
	sql::end_transaction( $openprint::dbh, $ac );

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
	$info{'From'} = $Me;
	$info{'PurchaseOrder'} = $self;
	$info{'ReplacementText'} = ssi::include( '/email_content/purchase_order_notification.html', \%info );

	my @notification_types = map { 'PO ' . (new openprint::PurchaseOrder_ContentType( $_ )->name()) . ' Approvals' } sets::union( map { $_->type_id() } $self->Contents() );
	$_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%info ) ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');
	my $mail = new openprint::Email();

	my $results;
	foreach my $U ( map { $_->User() } openprint::User_Notification->find(type=>\@notification_types,'value'=>'Yes' ) ) {
		if ( $U->id() == $Me->id() ) {
			$openprint::log->debug( $U->email() . ' Not mailing me.' );
			next;
		} # end if
		$_ = Email::Valid->address($U->email());
		if ( ( ! $_ ) or ( $_ ne $U->email() ) ) {
			$openprint::log->debug( $U->email() . ' is not a valid address.' );
			next;
		} # end if
		if ( ! $self->can_view( $U ) ) {
			$openprint::log->debug( $U->name() . ' cannot view this PO.' );
			next;
		} # end if
		if ( ! $self->can_authorize( $U ) ) {
			$openprint::log->debug( $U->name() . ' cannot authorize this PO.' );
			next;
		} # end if

		$results .= $mail->send(
				FROM		=>	$Me,
				TO			=>	$U,
				SUBJECT		=>	'Purchase Order requiring approval: ' . $self->id(),
				ATTACHMENTS	=>	\@body,
				);
	} # end foreach U
	return $results;
} # end sub send_approval_required_notification

sub send_to_vendor {
	my ( $self ) = @_;

	my $From = $self->Creator();
	
	my %info = (
			PurchaseOrder	=>	$self,
			From			=>	$From,
			);
	my @attachments = ();
	my $results;

	my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
	$info{ReplacementText} = ssi::include("/email_content/purchase_order_body.html", \%info );
	$_ = MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%info ) ) );
	push @attachments, ('', $_, 'text/html', 'quoted-printable');

	my $purchase_order = Encode::encode( 'utf-8', ssi::include('/email_content/purchase_order.html', \%info ) );

	my $file_base = $From->Company()->name().'-PO'.$$self{id};
	if ( File::Slurp::write_file('/tmp/'.$file_base.'.html', { atomic => 1, err_mode=>'carp' }, \$purchase_order ) ) {
		`wkhtmltopdf "/tmp/$file_base.html" "/tmp/$file_base.pdf"`;
		my $pdf_purchase_order = File::Slurp::read_file( "/tmp/$file_base.pdf", err_mode => 'carp' );
		unlink "/tmp/$file_base.html";
		unlink "/tmp/$file_base.pdf";
		if ( $pdf_purchase_order ) {
			push @attachments, ($file_base.'.pdf', MIME::Base64::encode_base64($pdf_purchase_order), 'application/octet-stream', 'base64');
		} else {
			$openprint::log->debug("Error making pdf");
		} # end if has pdf contents
	} # end if successfully wrote html content
	if ( scalar @attachments == 4 ) {
		$results .= 'Unable to make a pdf of this PO.  Using HTML version.<br/>';
		push @attachments, ($file_base.'.html', MIME::QuotedPrint::encode_qp($purchase_order), 'text/html', 'quoted-printable');
	} # end if
	foreach my $OA ( $self->Assets() ) {
		my $Asset = $OA->Asset();
		$_ = File::Slurp::read_file( $Asset->on_disk_path(), err_mode => 'carp' );
		if ( $_ ) {
			push @attachments, ( $Asset->filename(), MIME::Base64::encode_base64( $_ ), 'application/octet-stream', 'base64');
		} else { 
			$results .= 'Unable to attach ' . $Asset->filename() . ' to email.<br/>';
		} # end if
	} # end foreach Asset

	my $Email = new openprint::Email();

	$results .= 'PO ' . $$self{'id'} . ' emailed to the following recipients:<br/>';
	$results .= $Email->send(
			FROM	=> $From,
			SUBJECT => 'Purchase Order ' . $self->id() . ' from ' . $From->Company()->name(),
			TO		=> $self->vendor_email(), # Email will split by ,
			BODY	=>	'',
			ATTACHMENTS	=>	\@attachments,
			);
	if ( $self->shipto_email() and ( $self->vendor_email() ne $self->shipto_email() ) ) {
		$results .= $Email->send( 
				TO		=>	$self->shipto_email(),
				SUBJECT	=>	'Purchase Order '. $self->id() . ' for ' . $self->vendor_name(),
				BODY	=>	'',
				ATTACHMENTS =>	\@attachments,
				);
	} # end if
	if ( $self->notifications() ) {
		$info{'ReplacementText'} = ssi::include('/email_content/purchase_order_notification.html', \%info );
		$_ = MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%info ) ) );
		@attachments = ('', $_, 'text/html', 'quoted-printable');
		$results .= 'Notifications: <br/>' . $Email->send( 
				TO	=>	[ map { new openprint::User( $_ ) } $self->notifications() ],
				SUBJECT	=>	'Purchase Order '. $self->id() . ' for ' . $self->vendor_name(),
				BODY	=>	'',
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

sub send_to_me {
	my $From = new openprint::User( $session{'user_id'} );
	my %info = (
			PurchaseOrder	=>	$_[0],
			From			=>	$From,
			);
	my @attachments = ();

	$info{ReplacementText} = ssi::include('/email_content/purchase_order_body.html', \%info );
	$_ = MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::include( '/email_template.html', \%info ) ) );
	push @attachments, ('', $_, 'text/html', 'quoted-printable');

	my $purchase_order = Encode::encode( 'utf-8', ssi::include('/email_content/purchase_order.html', \%info ) );

	my $file_base = $From->Company()->name().'-PO'.$_[0]{id};
	if ( File::Slurp::write_file('/tmp/'.$file_base.'.html', { atomic => 1, err_mode=>'carp' }, \$purchase_order ) ) {
		`wkhtmltopdf "/tmp/$file_base.html" "/tmp/$file_base.pdf"`;
		my $pdf_purchase_order = File::Slurp::read_file( "/tmp/$file_base.pdf", err_mode => 'carp' );
		#unlink "/tmp/$file_base.html";
		unlink "/tmp/$file_base.pdf";
		push @attachments, ($file_base.'.pdf', MIME::Base64::encode_base64($pdf_purchase_order), 'application/octet-stream', 'base64') if $pdf_purchase_order;
	} # end if
	my $results;
	if ( @attachments == 4 ) {
		$results .= 'Unable to make a pdf of this PO.  Using HTML version.<br/>';
		push @attachments, ($file_base.'.html', MIME::QuotedPrint::encode_qp($purchase_order), 'text/html', 'quoted-printable');
	} # end if
    foreach my $OA ( $_[0]->Assets() ) {
        my $Asset = $OA->Asset();
        $_ = File::Slurp::read_file( $Asset->on_disk_path(), err_mode => 'carp' );
        if ( $_ ) {
            push @attachments, ( $Asset->filename(), MIME::Base64::encode_base64( $_ ), 'application/octet-stream', 'base64');
        } else {
            $results .= 'Unable to attach ' . $Asset->filename() . ' to email.<br/>';
        } # end if
    } # end foreach Asset

	my $receipt = (new openprint::Email())->send(
			FROM	=> sprintf( '"%s" <%s>', $From->name(), $From->email() ),
			SUBJECT => 'Purchase Order ' . $_[0]->id() . ' from ' . $_[0]->vendor_name(),
			TO		=> $From,
			ATTACHMENTS	=>	\@attachments,
			);

	$results = 'PO ' . $_[0]{'id'} . ' emailed to the following recipients:<br/>' . $receipt;
	return $results;
} # end sub send_to_me

sub subtotal {
	if ( @_ > 1 ) {
		$_[0]{subtotal} = $_[1];
	} # end if
	if ( ! defined $_[0]{subtotal} ) {
		$_[0]{subtotal} = 0;
		foreach my $C ( $_[0]->Contents() ) {
			$_[0]{subtotal} += $C->total();
		} # end foreach
		$_[0]{subtotal} = Math::Round::nearest( 0.01, $_[0]{subtotal} );
	} # end if
	return $_[0]{subtotal};
} # end sub subtotal

sub total {
	if ( @_ == 2 ) {
		$_[0]{total} = $_[1];
	} # end if
	if ( ! $_[0]{total} ) {
		$_[0]{total} = $_[0]->subtotal();
		foreach my $Tax ( $_[0]->Taxes() ) {
			$_[0]{total} += $Tax->amount();
		} # end foreach Tax
		$_[0]{total} -= $_[0]->payments_total();
		$_[0]{total} = Math::Round::nearest( 0.01, $_[0]{total} );
	} # end if
	return $_[0]{total};
} # end sub total

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
			my $ac = sql::start_transaction( $openprint::dbh );
			$dbh->do( 'LOCK TABLE PurchaseOrder_Notifications IN ACCESS EXCLUSIVE MODE' ) or $openprint::log->error( DBI->errstr );
			sql::execute( undef, undef, 'DELETE FROM PurchaseOrder_Notifications WHERE po_id=?', $$self{'id'} );
			foreach ( @{$$self{'notifications'}} ) {
				sql::insert( undef, undef, 'PurchaseOrder_Notifications', ['po_id', $$self{'id'}, 'user_id', $_ ] );
			} # end foreach
			sql::end_transaction( $openprint::dbh, $ac );
		} # end if
	} # end if
	if ( $$self{'id'} and ! exists $$self{'notifications'} ) {
		@{$$self{'notifications'}} = sql::execute( undef, undef, 'SELECT user_id FROM PurchaseOrder_Notifications WHERE po_id=?', $$self{'id'} );
	} # end if
	return $$self{'notifications'} ? @{$$self{'notifications'}} : ();
} # end sub notifications

sub Logs {
	my ( $self ) = @_;

	return openprint::PurchaseOrder_Log->find( 'po_id'=>$$self{'id'}, 'order'=>'created_on DESC' );
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
	return new openprint::Manifest( $_[0]{manifest_id} );
} # end sub Manifest

# We don't make any db changes here.  That only happens on PO saving
sub Taxes {
	my ( $self ) = @_;
	@{$$self{Taxes}} = openprint::PurchaseOrder_Tax->find(purchaseorder_id=>$$self{id}) if $$self{id} and ! $$self{Taxes};

	my $Supplier = $self->Supplier();
	my $country = $Supplier->country() ? $Supplier->country() : $$self{vendor_country};
	my $state = $Supplier->state() ? $Supplier->state() : $$self{vendor_state};
	my $created_on = $$self{'created_on'} ? $$self{'created_on'} : 'NOW()';

	if ( $country and $state and ! ( $$self{Taxes} and @{$$self{Taxes}} ) ) {
		foreach my $Tax ( openprint::Tax->find(
					'period_start null_or_<='	=>	$created_on,
					'period_end null_or_>='	 =>	$created_on,
					country	=>	$country,
					state	=>	$state,
				) ) {
			my $T = new openprint::PurchaseOrder_Tax();
			$T->set({
				'PurchaseOrder'		=>	$self,
				'tax_id'			=>	$$Tax{'id'},
				'rate'				=>	$$Tax{'rate'},
			});
			#if ( $$self{'id'} ) {
				#$T->save({'purchaseorder_id'	=>	$$self{'id'}});
			#} # end if
			push @{$$self{'Taxes'}}, $T;
		} # end foreach Tax
	} # end if
	if ( @_ > 1 and $$self{'id'} ) {
		my @new_taxes = openprint::Tax->find(
				'period_start null_or_<='	=>	$created_on,
				'period_end null_or_>='	 	=>	$created_on,
				country	=>	$country,
				state	=>	$state,
			);

		# Clear out any no longer valid taxes
		for ( my $i = 0; $i < @{$$self{Taxes}}; $i += 1 ) {
			my $Tax = $$self{Taxes}[$i];
			if ( ! sets::isin( $Tax->tax_id(), [ map { $_->id() } @new_taxes ] ) ) {
				#$Tax->delete();
				splice @{$$self{Taxes}}, $i, 1; $i -= 1;
			} # end if
		} # end foreach old Tax
		#@{$$self{'Taxes'}} = openprint::PurchaseOrder_Tax->find('purchaseorder_id'=>$$self{'id'});
		if ( @new_taxes != @{$$self{Taxes}} ) {
			my @tax_ids = map { $_->tax_id() } @{$$self{Taxes}};
			foreach my $Tax ( @new_taxes ) {
				if ( ! sets::isin( $Tax->id(), \@tax_ids ) ) {
					my $T = new openprint::PurchaseOrder_Tax();
					$T->set({
							PurchaseOrder	=>	$self,
							tax_id			=>	$$Tax{id},
							rate			=>	$$Tax{rate},
							});
					push @{$$self{Taxes}}, $T;
				} # end if
			} # end foreach Tax	
		} # end if have new taxes
	} # end if recalculate
	return $$self{'Taxes'} ? @{$$self{'Taxes'}} : ();
} # end sub Taxes

sub Tax {
    my $result = openprint::PurchaseOrder_Tax->find_one('purchaseorder_id'=>$_[0]{'id'}, 'tax_id'=>$_[1]->id() ) if $_[0]{'id'};
    if ( ! $result ) {
        return new openprint::PurchaseOrder_Tax();
    } # end if
    return $result;
} # end sub Tax

sub can_edit {
	return 1 if ! $_[0]{'id'};
	my $User = $_[1] ? $_[1] : new openprint::User( $openprint::session{user_id} );

	if ( $$User{type} eq 'A' ) {
		$log->debug("$$User{firstname} Is administrator") if $debug;
		return 1;
	} # end if
	if ( sets::isin( $_[0]{'created_by'}, [ $$User{id}, $User->assistant_ids(), $User->csr_ids() ] ) ) {
		$log->debug("$$User{firstname} Either created it or is an assistant") if $debug;
		return 1;
	} # end if

	if ( openprint::usergroup::is_user_in( ['Accounting','Inventory'], $$User{id} ) )  {
		$log->debug("$$User{firstname} Is in Accounting','Inventory'") if $debug;
		return 1;
	} # end if

	foreach my $C ( $_[0]->Contents() ) {
		my @contains = sets::contains( [ $$User{id}, $User->assistant_ids(), $User->csr_ids() ], [ map { $_->salesrep_id() } $C->Orders() ] );
		if ( @contains ) {
			$log->debug("can see because @contains in order salesreps") if $debug;
			return 1;
		} # end if
	} # end foreach C
	return 0;
} # end sub can_edit

sub can_view {
	return 1 if ! $_[0]{'id'};
	my $User = $_[1] ? $_[1] : new openprint::User( $openprint::session{user_id} );

	if ( $$User{type} eq 'A' ) {
		$log->debug("$$User{firstname} Is administrator") if $debug;
		return 1;
	} # end if
	if ( sets::isin( $_[0]{'created_by'}, [ $$User{id}, $User->assistant_ids(), $User->csr_ids() ] ) ) {
		$log->debug("$$User{firstname} Either created it or is an assistant") if $debug;
		return 1;
	} # end if
	if ( openprint::usergroup::is_user_in( ['Accounting','Shipping','Inventory'], $$User{id} ) )  {
		$log->debug("$$User{firstname} Is in Accounting','Shipping','Inventory'") if $debug;
		return 1;
	} # end if
			
	foreach my $C ( $_[0]->Contents() ) {
		my @contains = sets::contains( [ $$User{id}, $User->assistant_ids(), $User->csr_ids() ], [ map { $_->salesrep_id() } $C->Orders() ] );
		if ( @contains ) {
			$log->debug("can see because @contains in order salesreps") if $debug;
			return 1;
		} # end if
	} # end foreach C

	if ( $_[0]->notifications() ) {
		if ( sets::isin( $$User{id}, $_[0]->notifications() ) ) {
			$log->debug($$User{firstname} . ' can see because in notifications.' ) if $debug;
			return 1;
		} # end if
	} # end if
	$log->debug("$$User{firstname} cannot view this PO") if $debug;
	return 0;
} # end sub can_view

sub num {
	if ( @_ > 1 ) {
		$_[0]{num} = $_[1];
	} 
	return $_[0]{id} if ! $_[0]{num};
	return $_[0]{num};
} # end sub num
sub can_authorize {
	my $User = @_ > 1 ? $_[1] : new openprint::User( $openprint::session{user_id} );

	return 1 if ! $_[0]->total();
	return 1 if $User->purchasing_limit() and ( $_[0]->total() < $User->purchasing_limit() );
	my %Totals;
	my %Types;
	foreach my $C ( $_[0]->Contents() ) {
		$Totals{$C->type_id()} += $C->price();
		$Types{$C->type_id()} = $C->Type();
	} # end foreach C
		
	my $authorized = 1;
	foreach my $T ( values %Types ) {
		$authorized = 0 if $Totals{$$T{id}} > $User->po_limit( $$T{id} );
	} # end foreach Content 
	if ( $authorized and $User->purchasing_total_limit() ) {
		# Need to check all unauthorized POs FIXME later
	} # end if
	return $authorized;
} # end sub can_authorize

# ( $PO, $Content )
# Can we assume that we can view it?
sub can_see_pricing {
	if ( ! $_[0]{id} ) {
		$log->debug("Ccan see because new PO") if $debug;
		return 1;
	} # end if

	my $User = new openprint::User( $openprint::session{user_id} );
	
	if ( ( $$User{id} == $_[0]->created_by() ) or ( $$User{type} eq 'A' ) or openprint::usergroup::is_user_in( ['Accounting','SalesAdmin','InventoryManager'], $$User{id} ) ) {
$log->debug('can see') if $debug;
		return 1;
	} # end if

	if ( $_[1] ) {
		my @contains = sets::contains( [ $$User{id}, $User->assistant_ids(), $User->csr_ids() ], [ map { $_->salesrep_id() } $_[1]->Orders() ] );
		if ( @contains ) {
			$log->debug("can see pricing because @contains in orders") if $debug;
			return 1;
		} # end if
	} else {
		foreach my $C ( $_[0]->Contents() ) {

			my @contains = sets::contains( [ $$User{id}, $User->assistant_ids(), $User->csr_ids() ], [ map { $_->salesrep_id() } $C->Orders() ] );
			if ( @contains ) {
				$log->debug("can see pricing because @contains in orders") if $debug;
				return 1;
			} # end if
		} # end foreach C
	} # end if
	if ( $_[0]->notifications() ) {
		if ( sets::isin( $$User{id}, $_[0]->notifications() ) ) {
			$log->debug($$User{firstname} . ' can see because in notifications.' ) if $debug;
			return 1;
		} # end if
	} # end if
	return 0;
} # end sub can_see_pricing

sub payments_total {
	if ( @_ > 1 ) {
		$_[0]{payments_total} = $_[1];
	} # end if
	if ( ! $_[0]{payments_total} ) {
		$_[0]{payments_total} = Math::Round::nearest( 0.01, misc::sum( map { $_->amount() } $_[0]->Payments() ) );
	} # end if
	return $_[0]{payments_total};
} # end sub payments_total

sub Payments {
	if ( @_ > 1 ) {
		$_[0]{Payments} = $_[1];
	} # end if
	if ( ! $_[0]{Payments} ) {
		if ( $_[0]{id} ) {
			$_[0]{Payments} = [ openprint::Object_Payment->find( object_id=>$_[0]{id}, object_type=>'openprint::PurchaseOrder', order=>'id' ) ];
		} else {
			return ();
		} # end if
	} # end if
	return @{$_[0]{Payments}};
} # end sub Payments

1;
__END__
