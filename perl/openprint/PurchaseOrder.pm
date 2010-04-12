package openprint::PurchaseOrder;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %session $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;
require openprint::Company;
require openprint::Currency;
require openprint::User;
require openprint::Tax;
require openprint::PurchaseOrder_Content;
require openprint::PurchaseOrder_Log;
require openprint::Email;
require openprint::Manifest;

my $debug = 0;

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
	'federaltax'		=>	'federaltax',
	'federaltax_rate'	=>	'federaltax_rate',
	'federaltax_charge'	=>	'federaltax_charge',
	'statetax'			=>	'statetax',
	'statetax_rate'		=>	'statetax_rate',
	'statetax_charge'	=>	'statetax_charge',
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
	'shipto_fax'		=>	'shipto_fax',
	'shipto_sms'		=>	'shipto_sms',
	'shipto_email'		=>	'shipto_email',
	'manifest_id'		=>	'manifest_id',
	'cancelled'			=>	'cancelled',
);

%transforms = (
);

%defaults = (
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'deleted'		=>	0,
	'currency_id'	=> $session{'Currency_id'},
	'tax'			=>	0,
	'total'			=>	0,
	'subtotal'		=>	0,
	'federaltax'	=>	undef,
	'federaltax_rate'	=>	undef,
	'statetax'		=>	undef,
	'statetax_rate'	=>	undef,
	'manifest_id'	=>	undef,
	'cancelled'		=>	0,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM PurchaseOrders WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'id_start'} and $params{'id_end'} ) {
		$sql .= ' AND ( id BETWEEN ? AND ? )';
		push @values, @params{'id_start','id_end'}
	} elsif ( $params{'id_start'} ) {
		$sql .= ' AND ( id >= ?)';
		push @values, $params{'id_start'};
	} elsif ( $params{'id_end'} ) {
		$sql .= ' AND ( id <= ?)';
		push @values, $params{'id_end'};
	} # end if
	if ( exists $params{'company_id'} ) {
		if ( ref $params{'company_id'} eq 'ARRAY' ) {
			$sql .= ' AND company_id IN ('. join(',', map {'?'} @{$params{'company_id'}} ) . ')';
			push @values, @{$params{'company_id'}};
		} else {
			$sql .= ' AND company_id=?';
			push @values, $params{'company_id'};
		} # end if
	} # end if
	if ( exists $params{'supplier_id'} ) {
		if ( ref $params{'supplier_id'} eq 'ARRAY' ) {
			$sql .= ' AND supplier_id IN ('. join(',', map {'?'} @{$params{'supplier_id'}} ) . ')';
			push @values, @{$params{'supplier_id'}};
		} elsif ( $params{'supplier_id'} ) {
			$sql .= ' AND supplier_id=?';
			push @values, $params{'supplier_id'};
		} # end if
	} # end if
	if ( exists $params{'created_by'} ) {
		if ( ref $params{'created_by'} eq 'ARRAY' ) {
			$sql .= ' AND created_by IN ('. join(',', map {'?'} @{$params{'created_by'}} ) . ')';
			push @values, @{$params{'created_by'}};
		} elsif ( $params{'created_by'} ) {
			$sql .= ' AND created_by=?';
			push @values, $params{'created_by'};
		} # end if
	} # end if
	if ( exists $params{'manifest_id'} ) {
		if ( ref $params{'manifest_id'} eq 'ARRAY' ) {
			if ( @{$params{'manifest_id'}} ) {
				$sql .= ' AND manifest_id IN ('. join(',', map {'?'} @{$params{'manifest_id'}} ) . ')';
				push @values, @{$params{'manifest_id'}};
			} else {
				return ();
			} # end if
		} elsif ( $params{'manifest_id'} ) {
			$sql .= ' AND manifest_id=?';
			push @values, $params{'manifest_id'};
		} else {
			$sql .= ' AND manifest_id IS NULL';
		} # end if
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'}
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND ( created_on >= ?)';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on <= ?)';
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'authorized'} eq 'Y' ) {
		$sql .= ' AND authorized_by IS NOT NULL';
	} elsif ( $params{'authorized'} eq 'N' ) {
		$sql .= ' AND authorized_by IS NULL';
	} # end if
	if ( exists $params{'cancelled'} ) {
		if ( ref $params{'cancelled'} eq 'ARRAY' ) {
			if ( @{$params{'cancelled'}} ) {
				$sql .= ' AND cancelled IN ('. join(',', map {'?'} @{$params{'cancelled'}} ) . ')';
				push @values, @{$params{'cancelled'}};
			} else {
				return ();
			} # end if
		} elsif ( $params{'cancelled'} ne '' ) {
			$sql .= ' AND cancelled=?';
			push @values, $params{'cancelled'};
		} # end if
	} # end if
	if ( exists $params{'deleted'} ) {
		if ( ref $params{'deleted'} eq 'ARRAY' ) {
			if ( @{$params{'deleted'}} ) {
				$sql .= ' AND deleted IN ('. join(',', map {'?'} @{$params{'deleted'}} ) . ')';
				push @values, @{$params{'deleted'}};
			} else {
				return ();
			} # end if
		} else {
			$sql .= ' AND deleted=?';
			push @values, $params{'deleted'};
		} # end if
	} else {
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if
	if ( $params{'docket'} ) {
		$sql .= ' AND id IN (SELECT po_id FROM PurchaseOrder_Contents WHERE docket=?)';
		push @values, $params{'docket'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading PurchaseOrders SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No PurchaseOrders loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded PurchaseOrders ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::PurchaseOrder( $_->{id}, $_ ) } @$data;
} # end sub find

sub save {
	my ( $self, $hash ) = @_;

	if ( $hash ) {
		$self->set( $hash );
	} # end if

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$k} = $$self{$k};
	} # end foreach
	delete $sql{'created_on'};
	$sql{'subtotal'} = 0;
	foreach my $C ( $self->Contents() ) {
		$sql{'subtotal'} += $C->total();
	} # end foreach
	delete $$self{'federaltax'};
	delete $$self{'statetax'};
	$sql{'federaltax'} = $self->federaltax();
	$sql{'statetax'} = $self->statetax();
	$sql{'total'} = $sql{'subtotal'};
	if ( ! $sql{'currency_id'} ) {
		my $Currency = openprint::Currency::get_current();
		$sql{'currency_id'} = $Currency->id();
	} # end if

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('PurchaseOrders_id_seq')} );
		$sql{'id'} = $$self{'id'};

		if ( my $error = sql::insert( undef, undef, 'PurchaseOrders', \%sql ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if

    } else {
		if ( my $error = sql::update( undef, undef, 'PurchaseOrders', ['id=?', $$self{id}], [map { $_, $$self{$_} } keys %fields ] ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
    } # end if


	sql::end_transaction( $dbh, $ac );
	$self->load();
	return;
} # end sub save

sub destroy {
    my $self = shift;
    my $ac = sql::start_transaction( );
    sql::execute( undef, undef, q{DELETE FROM PurchaseOrders WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

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
	return openprint::PurchaseOrder_Content::find('po_id'=>$_[0]{'id'},'order'=>'id');
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

sub federaltax {
	my ( $self, $new ) = @_;

	if ( defined $new ) {
		$$self{'federaltax'} = $new;
	} # end if
	if ( ( ! $$self{'federaltax'} ) and $self->federaltax_charge() ) {
		$$self{'federaltax'} = $self->subtotal() * ( $self->federaltax_rate()/100 );
	} # end if
	return $$self{'federaltax'};
} # end sub federaltax

sub federaltax_rate {
	my ( $self, $new ) = @_;
	if ( defined $new ) {
		$$self{'federaltax_rate'} = $new;
	} # end if
	if ( ! $$self{'federaltax_rate'} ) {
		if ( my ( $Tax ) = openprint::Tax::find( 'state'=>$self->Company()->state(), 'country'=>$self->Company()->country() ) ) {
			$$self{'federaltax_rate'} = $Tax->federaltax_rate();
		} # end if
	} # end if
	return $$self{'federaltax_rate'};
} # end sub federaltax_rate

sub federaltax_charge {
	my $self = shift;
	if ( @_ ) {
		$$self{'federaltax_charge'} = $_[0];
	} # end if
	if ( ! defined $$self{'federaltax_charge'} ) {
		if ( $self->Company()->taxexempt1() eq 'Y' ) {
			$$self{'federaltax_charge'} = 0;
		} # end if
# This is true, but can't expect people to type it in
#if ( ! $self->Vendor()->gst_number() ) {
#   return 0;
#} # end if
		$$self{'federaltax_charge'} = 1;
	} # end if
	return $$self{'federaltax_charge'};
} # end sub federaltax_charge

sub statetax {
	my ( $self, $new ) = @_;

	if ( defined $new ) {
		$$self{'statetax'} = $new;
	} # end if
	if ( ( ! $$self{'statetax'} ) and $self->statetax_charge() ) {
		$$self{'statetax'} = $self->subtotal() * ( $self->statetax_rate()/100 );
	} # end if
	return $$self{'statetax'};
} # end sub statetax

sub statetax_rate {
	my ( $self, $new ) = @_;
	if ( defined $new ) {
		$$self{'statetax_rate'} = $new;
	} # end if
	if ( ! $$self{'statetax_rate'} ) {
		if ( my ( $Tax ) = openprint::Tax::find( 'state'=>$self->Company()->state(), 'country'=>$self->Company()->country() ) ) {
			$$self{'statetax_rate'} = $Tax->statetax_rate();
		} # end if
	} # end if
	return $$self{'statetax_rate'};
} # end sub statetax_rate

sub statetax_charge {
	my $self = shift;
	if ( @_ ) {
		$$self{'statetax_charge'} = $_[0];
	} # end if
	if ( ! defined $$self{'statetax_charge'} ) {
		if ( $self->Company()->taxexempt2() eq 'Y' ) {
			return 0;
		} # end if
# This is true, but can't expect people to type it in
#if ( ! $self->Vendor()->pst_number() ) {
#   return 0;
#} # end if
		$$self{'statetax_charge'} = 1;
	} # end if
	return $$self{'statetax_charge'};
} # end sub statetax_charge

sub total {
	my ( $self ) = @_;
	return $$self{'subtotal'} + $self->federaltax() + $self->statetax();
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
	foreach ( 'id', 'authorized', 'authorized_by'	, 'authorized_on', 'delivered_on' ) {
		delete $$New{$_};
	} # end foreach
	$$New{'created_by'} = $session{'user_id'};
	return $New;
} # end sub copy
sub Manifest {
	return new openprint::Manifest( $_[0]{'manifest_id'} );
} # end sub Manifest
1;
__END__
