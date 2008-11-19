package openprint::PurchaseOrder;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %session %fields %transforms %defaults );
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
require openprint::PurchaseOrder_Content;

my $debug = 0;

%fields = (
	'id'				=>	'id',
	'currency_id'		=>	'currency_id',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'created_by'		=>	'created_by',
	'authorized_by'		=>	'authorized_by',
	'authorized_on'		=>	'authorized_on',
	'delivered_on'		=>	'delivered_on',
	'total'				=>	'total',
	'subtotal'			=>	'subtotal',
	'tax'				=>	'tax',
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
	'shipto_email'		=>	'shipto_email',
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
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading PurchaseOrders SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No PurchaseOrders loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded PurchaseOrders ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::PurchaseOrder( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT * FROM PurchaseOrders WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

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
$log->debug("Adding " . $C->total() );
		$sql{'subtotal'} += $C->total();
	} # end foreach
	$sql{'total'} = $sql{'subtotal'};

	my $ac = sql::start_transaction( $dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('PurchaseOrders_id_seq')} );
		$sql{'id'} = $$self{'id'};

		if ( my $error = sql::insert( undef, undef, 'PurchaseOrders', \%sql ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if

    } else {
		if ( my $error = sql::update( undef, undef, 'PurchaseOrders', ['id=?', $$self{id}], \%sql ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
    } # end if

	sql::end_transaction( $dbh, $ac );
	$self->load();
	return;
} # end sub save

sub delete {
	my $self = shift;
	return sql::update( undef, undef, 'PurchaseOrders', ['id=?', $$self{id}], 'deleted',1 );
} # end sub delete

sub destroy {
    my $self = shift;
    my $ac = sql::start_transaction( );
    #sql::execute( undef, undef, q{DELETE FROM PurchaseOrder_data WHERE label_id=?}, $$self{'id'} );
    sql::execute( undef, undef, q{DELETE FROM PurchaseOrders WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

sub copy {
	my $self = shift;
	my $new = new openprint::PurchaseOrder();
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{'id'};
	#foreach my $k ( keys %{$$self{'data'}} ) {
		#$$new{'data'}{$k} = $$self{'data'}{$k};
	#} # end foreach
	return $new;
} # end sub copy

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
	return openprint::PurchaseOrder_Content::find('po_id'=>$_[0]{'id'});
} # end sub Contents

sub delivered_on {
	my ( $self ) = @_;
	if ( ! $$self{'delivered_on'} ) {
	$$self{'delivered_on'} = join('-', Date::Calc::Today() ) .' 00:00:00';
	} # end if
	return $$self{'delivered_on'};
} # end sub delivered_on

sub send_to_vendor {
	my ( $self ) = @_;

	my $From = new openprint::User( $session{'user_id'} );
	
	my %info = (
			'PurchaseOrder'	=>	$self,
			'From'			=>	$From,
			);
	my @attachments = ();

	my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
	$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/purchase_order_body.html\"-->";
	$_ = encode_qp( ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%info ) );
	push @attachments, ('', $_, 'text/html', 'quoted-printable');

	my $purchase_order = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/purchase_order.html' );
	push @attachments, $From->Company()->name().'-PO'.$$self{'id'}, encode_qp( ssi::variable_substitution( undef, $log, $dbh, \$purchase_order, \%info ) ), 'text/html', 'quoted-printable';

	my %mail = (
			SMTP    => $config{'Mail Server'},
			FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
			TO      => sprintf( '"%s" <%s>', $self->vendor_contact(), $self->vendor_email() ),
			SUBJECT => 'Purchase Order ' . $self->id() . ' from ' . $self->vendor_name(),
			);
	misc::send_email_with_attachment( $log, \%mail, @attachments );

	return 'PO Emailed to ' . $From->email() . '<br/>';

} # end sub send_to_vendor

1;
__END__
