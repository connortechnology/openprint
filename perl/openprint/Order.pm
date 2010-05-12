package openprint::Order;
@ISA=qw(openprint::Object);

use strict;
use openprint ();
use vars qw( %session %config %variable $log $dbh %fields);
*session = \%openprint::session;
*config = \%openprint::config;
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require openprint::logs;
require openprint::OrderedProduct;
require openprint::Payment;
require openprint::Tax;

my $debug = 1;

%fields = (
	'id'						=> 'index',
	'session_id'				=>	'strsessionid',
	'company_id'				=> 'companyindex',
	'user_id'					=> 'userindex',
	'docket'					=> 'lngdocketnumber',
	'status'					=> 'strstatus',
	'federal_tax'				=> 'curfedtax',
	'state_tax'					=> 'curprovtax',
	'harmonized_tax'			=> 'curharmtax',
	'total'						=> 'curtotalsale',
	'downpayment'				=> 'curdownpayment',
	'created_on'				=> 'dtmorderdate',
	'company_name'				=> 'strcompanyname',
	'salutation'				=> 'strsalutation',
	'firstname'				=> 'strfirstname',
	'lastname'					=> 'strlastname',
	'address1'					=> 'straddress1',
	'address2'					=> 'straddress2',
	'city'						=> 'strcity',
	'state'						=> 'strstate',
	'country'					=> 'strcountry',
	'postalcode'				=> 'strpostalcode',
	'phone'						=> 'strphone',
	'extension'					=> 'strext',
	'fax'						=> 'strfax',
	'email'						=> 'stremail',
	'alsonotify'				=> 'stralsonotify',	
	'paid'						=> 'paid',
	'currency_id'				=> 'currencyindex',
	'po'						=> 'strponumber',
	'administrator_name'		=> 'stradministratorname',
	'administrator_comments'	=> 'stradministratorcomments',
	'salesrep_id'				=>	'employeeindex',
	'invoice_id'				=>	'invoice_id',
	'invoiced_on'				=>	'invoiced_on',
	'created_on'				=>	'dtmorderdate',
	);

sub find {
	my %params = @_;
	my @values;
	my $sql = 'SELECT *,(SELECT SUM(amount) FROM Payments WHERE (deleted=false or deleted IS NULL) AND order_id=Index) AS paid FROM Orders WHERE 1>0';
	if ( $params{'id'} ) {
		$sql .= ' AND index=?';
		push @values, $params{'id'};
	} # end if
	if ( $params{'docket'} ) {
		$sql .= ' AND lngdocketnumber=?';
		push @values, $params{'docket'};
	} # end if
	if ( $params{'invoice_id'} ) {
		$sql .= ' AND invoice_id=?';
		push @values, $params{'invoice_id'};
	} # end if
	if ( $params{'company_id'} ) {
		if ( ref $params{'company_id'} eq 'ARRAY' ) {
			if ( @{$params{'company_id'}} ) {
				$sql .= q{ AND CompanyIndex IN (} . join(',', map {'?'} @{$params{'company_id'}}). ')';
				push @values, @{$params{'company_id'}};
			} else {
				$openprint::log->warn("EMpty company array passed to openprint::Project::find");
			} # end if
		} else {
			$sql .= q{ AND CompanyIndex=?};
			push @values, $params{'company_id'};
		} # end if
	} # end if
	if ( $params{'user_id'} ) {
		if ( $params{'user_id'} =~ /\D/ ) {
			$sql .= " AND (UserIndex $params{'user_id'})";
		} else {
			$sql .= q{ AND (UserIndex=?)};
			push @values, $params{'user_id'};
		} # end if
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= q{ AND (dtmorderdate BETWEEN ? AND ?)};
		push @values, @params{'created_on_start','created_on_end'};
	} elsif ( $params{'created_on_start'} ) {
		$sql .= q{ AND (dtmorderdate >= ?::timestamp with time zone)};
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= q{ AND (dtmorderdate <= ?::timestamp with time zone)};
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'value_start'} and $params{'value_end'} ) {
		$sql .= q{ AND (curtotalsale BETWEEN ? AND ? )};
		push @values, $params{'value_start','value_end'};
	} elsif ( $params{'value_start'} ) {
		$sql .= q{ AND (curtotalsale >= ?)};
		push @values, $params{'value_start'};
	} elsif ( $params{'value_end'} ) {
		$sql .= q{ AND (curtotalsale <= ?)};
		push @values, $params{'value_end'};
	} # end if
	if ( $params{'status'} ) {
		if ( ref $params{'status'} eq 'ARRAY' ) {
			$sql .= q{ AND strStatus IN (} . join(',', map {'?'} @{$params{'status'}}). ')';
			push @values, @{$params{'status'}};
		} else {
			$sql .= q{ AND (strStatus=?)};
			push @values, $params{'status'};
		} # end if
	} # end if
	if ( $params{'session_id'} ) {
		$sql .= ' AND strsessionid=?';
		push @values, $params{'session_id'};
	} # end if
	if ( $params{'salesrep_id'} ) {
		$sql .= ' AND employeeindex=?';
		push @values, $params{'salesrep_id'};
	} # end if
	if ( $params{'currency_id'} ) {
		$sql .= ' AND currencyindex=?';
		push @values, $params{'currency_id'};
	} # end if
	if ( exists $params{'owing_>'} ) {
		$sql .= ' AND ( ((SELECT SUM(curamount) FROM Payments WHERE order_id=Index) IS NULL AND curtotalsale>?) OR (curtotalsale - (SELECT SUM(curamount) FROM Payments WHERE order_id=Index) ) > ?) ';
		push @values, @params{'owing_>','owing_>'};
	} # end if
	if ( exists $params{'order'} ) {
		if ( $params{'order'} eq 'created_on' ) {
			$sql .= ' ORDER BY dtmorderdate';
		} elsif( $params{'order'} eq 'total' ) {
			$sql .= ' ORDER BY curtotalsale';
		} elsif ( $params{'order'} eq 'company' ) {
			$sql .= ' ORDER BY lower(strCompanyName)';
		} elsif ( $params{'order'} ) {
			$sql .= " ORDER BY $params{'order'}" if $params{'order'};
		} # end if
	} # end if
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug('Error (' . $openprint::dbh->errstr . ") Loading Orders: $sql @values");
		return;
	} else {
		$openprint::log->debug("Loading Orders: $sql @values #results:" . @$data);
		return map { new openprint::Order( $_->{index}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT *,(SELECT SUM(amount) FROM Payments WHERE (deleted=false or deleted IS NULL) AND order_id=Index) AS paid FROM Orders WHERE Index=?', {}, $$self{'id'} );
$openprint::log->debug("Loaded order: " . $$self{'id'} );
		if ( ( ! $data ) and $openprint::dbh->errstr() ) {
			$openprint::log->error('Error loading Order: ' . $openprint::dbh->errstr() );
			return;
		} # end if
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load

sub save {
	my ( $self, $params ) = @_;

	$self->set( $params );

	my $ac = sql::start_transaction( $dbh );

	my %sql;
	foreach my $key ( keys %fields ) {
		next if $key eq 'paid';
		$$self{$key} = undef if $$self{$key} eq '';
		$sql{$fields{$key}} = $$self{$key};
	} # end foreach
		
	if ( ! $$self{'id'} ) {
		if ( $openprint::config{'OrderIDStyle'} eq 'Year' ) {
			$sql{'index'} = $$self{'id'} = openprint::order::get_order_id( $openprint::log, $openprint::dbh );
		} else {
			@$self{'id'} = sql::execute( $log, $dbh, q{SELECT nextval('order_id_seq')} );
			$sql{'index'} = $$self{'id'};
		} # end if
		$sql{$fields{'created_on'}} = 'NOW()';
		if ( ( my $error = sql::insert( $log, $dbh, 'Orders', \%sql ) ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if	
	} elsif ( $$params{'force_insert'} ) {
		if ( ( my $error = sql::insert( $log, $dbh, 'Orders', \%sql ) ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if	
	} else {
		if ( ( my $error = sql::update( $log, $dbh, 'Orders', ['index=?', $$self{'id'}], \%sql ) ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if	
	} # end if

	$self->load();
	sql::end_transaction( $dbh, $ac );
	return;
} # end sub save

sub delete {
	my $self = shift;

	if ( ! $$self{'id'} ) {
		$log->error("Order::delete called with no id");
		return;
	}

	my $ac = sql::start_transaction( $dbh );
	sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ProjectIndex IN ( SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?)}, $$self{'id'} );
	sql::execute( $log, $dbh, q{DELETE FROM Order_Log WHERE order_id=?}, $$self{'id'} );
	sql::execute( $log, $dbh, q{DELETE FROM Order_Contents WHERE OrderIndex=?}, $$self{'id'} );
	sql::execute( $log, $dbh, q{DELETE FROM Ordered_Products WHERE order_id=?}, $$self{'id'} );
	sql::update( undef, undef, 'Projects', [ 'order_id=?', $$self{'id'}], [ 'order_id', undef ] );
	sql::update( undef, undef, 'payments', [ 'order_id=?', $$self{'id'}], [ 'order_id', undef ] );
	sql::execute( $log, $dbh, q{DELETE FROM Orders WHERE Index=?}, $$self{'id'} );
	sql::end_transaction( $dbh, $ac );
	
	openprint::logs::insertLogRecord('4', "Order ID: " . $$self{'id'},);
	
} # end sub delete

sub to_string {
	my $self = shift;
	return '';
} # end sub

# Approve is acknowledging the prices, etc and giving the go ahead. So this function updates all the prices, taxes, statuses, etc.
sub approve {
	my $self = shift;
# get taxes
	my @Taxes = openprint::Tax::find('state'=>$self->state() );
	my ( $pst_rate, $hst_rate, $gst_rate ) = $Taxes[0]->get('statetax_rate','harmonisedtax_rate','federaltax_rate') if @Taxes;

	$_ = q{SELECT ysnPSTExempt, ysnGSTExempt FROM Company WHERE Index=?};
	my ( $pst_exempt, $gst_exempt ) = sql::execute( $log, $dbh, $_, $openprint::session{'company_id'} );

	my $sub_total = 0;
	my $gst_total;
	my $pst_total;
	my $hst_total;
	my $total = 0;

	$_ = q{SELECT lngProjectIndex, intQuantityIndex FROM Order_Contents WHERE OrderIndex=?};
	my @data = sql::execute( $log, $dbh, $_, $$self{'id'} );
	while ( my ( $project_id, $qty ) = splice @data, 0, 2 ) {
		my ( $pst_amount, $gst_amount, $hst_amount );
		my $Project = new openprint::Project( $project_id );
		my @prices = $Project->prices();
		my $price = $prices[$qty-1];

# get product tax exemption
		my ( $prod_tax1_exempt, $prod_tax2_exempt );

		if ( $pst_rate ne '' ) {
			if ( $pst_exempt ne 'Y' and $prod_tax2_exempt ne 'Y' ) {
				$pst_amount = $price * ($pst_rate/100);
			} else {
				$pst_amount = 0;
			} # end if
		} # end if
		if ( $gst_rate ne '' ) {
			if ( $gst_exempt ne 'Y' and $prod_tax1_exempt ne 'Y' ) {
				$gst_amount = $price * ($gst_rate/100);
			} else {
				$gst_amount = 0;
			} # end if
		} # end if

		if ( $hst_rate ne '' ) {
			if ( $gst_exempt ne 'Y' and $prod_tax1_exempt ne 'Y' ) {
				$hst_amount = $price * ($hst_rate/100);
			} else {
				$hst_amount = 0;
			} # end if
		} # end if

		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $project_id, 'Waiting For Customer Approval'], 'strstatus', 'Ordered' );
		$Project->add_to_log( @openprint::session{'company_id', 'user_id'}, 'Additional Charges Approved' );
		sql::update( $log, $dbh, 'Order_Contents', ['OrderIndex=? AND lngProjectIndex=?', $$self{'id'}, $project_id ],
				'curSalesPrice',	$price,
				'dblTax1', ( $gst_amount ne '' ? $gst_amount : undef ),
				'dblTax2', ( $pst_amount ne '' ? $pst_amount : undef ),
				'dblTax3', ( $hst_amount ne '' ? $hst_amount : undef ),
				);

		$sub_total += $price;
		$gst_total += $gst_amount if $gst_amount ne '';
		$pst_total += $pst_amount if $pst_amount ne '';
		$hst_total += $hst_amount if $hst_amount ne '';
		$total += $price + $gst_amount + $pst_amount + $hst_amount;
	} # end while

	sql::update( $log, $dbh, 'Orders', ['Index=?',$$self{id}],
			'curFedTax',	( $gst_total ne '' ? $gst_total : undef ),
			'curProvTax',	( $pst_total ne '' ? $pst_total : undef ),
			'curHarmTax',	( $hst_total ne '' ? $hst_total : undef ),
			'curTotalSale', ( $total ne '' ? $total : undef ),
			'strStatus',	'In Production',
			);

	$self->add_log( 'Customer Approved' );

} # end sub approve

sub status {
	my ( $self, $new_status ) = @_;
	if ( defined $new_status and $$self{'status'} ne $new_status ) {
		sql::update( $log, $dbh, 'Orders', ['index=?', $$self{'id'}], 'strStatus', $new_status );
		$$self{'status'} = $new_status;
		$self->add_log( "Changed Status to $new_status" );
	} # end if
	return $$self{'status'};
} # end sub status

# Adding Waiting For Pickup, Shipped, Picked Up
sub update_status {
	my $self = shift;

	$_ = q{SELECT DISTINCT(strStatus) FROM Projects WHERE id IN (SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?)};
	my @statuses = sql::execute( $log, $dbh, $_, $$self{id} );

	if ( sets::isin( 'Pending Deposit', \@statuses ) and $self->status() ne 'Pending Deposit' ) {
		$self->status( 'Pending Deposit' );
	} elsif (	sets::isin( 'Waiting For Customer Approval', \@statuses ) ) {
		$self->status( 'Waiting For Customer Approval' );
	} elsif ( sets::intersection( @statuses, 'In Prepress','Proofs Out','Approved','Printed') ) {
		$self->status( 'In Production' );
	} else { # Projcets are complete
		# All projects have same shipping type, so if one is waiting, all must be waiting
		if ( sets::isin( 'Waiting For Pickup', \@statuses ) ) {
			$self->status( 'Waiting For Pickup' );
		} elsif ( sets::isin( 'Picked Up', \@statuses ) ) {
			$self->status( 'Picked Up' );
		} elsif ( sets::isin( 'Shipped', \@statuses ) ) {
			$self->status( 'Shipped' );
		} # end if
		$self->status('Complete');
	} # end if
   if ( 'Complete' eq $$self{'status'} ) {
        $self->send_completion_notice( );

        if ( $config{'SendInvoiceOnProjectCompletion'} ne 'N' ) {
            #send_invoice( $r, $log, $dbh, $order_id );
        } # end if
    } # end if
	return $$self{'status'};
} # end sub update_status

sub add_log {
	my ( $self, $comment ) = @_;
	sql::insert( undef, undef, 'Order_Log',[
			'order_id',		$$self{'id'},
			'company_id',	$openprint::session{'company_id'} ? $openprint::session{'company_id'} : undef,
			'user_id',		$openprint::session{'user_id'},
			'description',	$comment,
			] );
} # end sub add_log

sub company {
	my $self = shift;
	return new openprint::Company( $$self{'company_id'} );
} # end sub company
sub Company {
	my $self = shift;
	return new openprint::Company( $$self{'company_id'} );
} # end sub company

sub Projects {
	my $self = shift;
	return @{$$self{'Projects'}} if $$self{'Projects'};
	return () if ! $$self{'id'};
	@{$$self{'Projects'}} = map {new openprint::Project( $_ );} sql::execute( undef, undef, q{SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?}, $$self{'id'} );
	return @{$$self{'Projects'}};
} # end sub Projects

sub Products {
	my $self = shift;
	return () if ! $$self{'id'};
	@{$$self{'Products'}} = openprint::OrderedProduct::find( 'order_id'=>$$self{id} );
	return @{$$self{'Products'}};
} # end sub Products

sub User {
	return new openprint::User( $_[0]{'user_id'} );
}

sub name {
	my $self = shift;
	if ( ! ( $$self{'firstname'} or $$self{'lastname'} ) ) {
		return $self->User()->name();
	} # end if
	return $$self{'firstname'} . ' ' . $$self{'lastname'};
} # end sub name

sub balance {
	my $self = shift;
	return 1*($self->total() - $$self{'paid'});
} # end sub balance

sub Currency {
	my $self = shift;
	return new openprint::Currency( $$self{'currency_id'} );
} # end sub

sub pay {
    my $self = shift;
    $_ = 'SELECT CompanyIndex, currencyindex, curTotalSale, (SELECT SUM(amount) FROM Payments WHERE (deleted=false or deleted IS NULL) AND completed=true AND order_id=Orders.Index) FROM Orders WHERE Index=?';
    my ( $company_index, $currency_id, $amount, $paid ) = sql::execute( $openprint::log, $openprint::dbh, $_, $$self{id} );
    if ( $amount - $paid <= 0 ) {
        $self->update_status();
        return "Order $$self{id} is already paid!<br/>";
    } # end if

	my $Payment = new openprint::Payment();
    my $error = $Payment->save( {
            'order_id'		=> $$self{id},
			'recipient_id'	=>	new openprint::User( $openrpint::session{'user_id'} )->company_id(),
            'payor_id'		=> $$self{company_id},
            'amount'		=> $amount - $paid,
            'method'		=> 'Manual',
            'currency_id',	=> $$self{currency_id},
            'memo'			=> 'Order marked paid',
			'completed'		=> 1,
            } );
    if ( ! $error ) {
        $self->update_status();
    } # end if
    return $error;
} # end sub pay

sub send_cancellation_notice {
	my $self = shift;

	my %order;
	$order{'Order'} = $self;
	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_cancellation_notice.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( undef, $log, $dbh, \$order{'ReplacementText'}, \%order );
	my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
	$_ = MIME::QuotedPrint::encode_qp( ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%order ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');

	my $Me = new openprint::User( $session{'user_id'} );

	# Send to inventory and scheduling people.
	foreach my $Recipient ( openprint::User::find('usergroups'=>['Inventory','Scheduling']) ) {
		next if $Recipient->id() == $session{'user_id'};
		my %mail = (
				SMTP	=> $config{'Mail Server'},
				FROM	=> sprintf('"%s" <%s>', $Me->get('name','email') ),
				TO		=> sprintf('"%s" <%s>', $Recipient->get('name','email') ),
				SUBJECT => "Docket $$self{'docket'} has been cancelled.",
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end foreach Recipient
	
} # end sub send_cancellation_notice

# These fields have 3 possible values, undef meaning not yet calculated. Empty string means calculated, but no tax applies.  Numeric = value;
sub federal_tax {
	my ( $self, $new ) = @_;
	if ( $new ) {
		$$self{'federal_tax'} = $new;
	} elsif ( ! defined $$self{'federal_tax'} ) {
		$$self{'federal_tax'} = '';
		if ( $self->Company()->gst_exempt() ne 'Y' ) {
			my @Taxes = openprint::Tax::find('country'=>$self->country(),'state'=>$self->state() );
			if ( @Taxes == 1 ) {
				my $tax_rate = $Taxes[0]->federaltax_rate();
				if ( $tax_rate ) {
					$$self{'federal_tax'} = $self->subtotal() * ( $tax_rate/100 );
				} # end if tax_rate 
			} # no tax for this state/country
		} # end if exempt
	} # end if ! $$self{'federal_tax'};
	return $$self{'federal_tax'};
} # end sub federal_tax

sub state_tax {
	my ( $self, $new ) = @_;
#$log->debug("state_tax");
	if ( $new ) {
		$$self{'state_tax'} = $new;
	} elsif ( ! defined $$self{'state_tax'} ) {
		$$self{'state_tax'} = '';
		if ( $self->Company()->pst_exempt() ne 'Y' ) {
#$log->debug("Not exempt");
			my @Taxes = openprint::Tax::find('country'=>$self->country(), 'state'=>$self->state() );
#$log->debug("Taxes: " . @Taxes );
			if ( @Taxes == 1 ) {
				my $tax_rate = $Taxes[0]->statetax_rate();
#$log->debug("State tax rate: $tax_rate");
				if ( $tax_rate ) {
					$$self{'state_tax'} = $self->subtotal() * ( $tax_rate/100 );
				} # end if tax_rate
			} # no tax for this state/country
#} else {
#$log->debug("exempt" . $self->Company()->pst_exempt());
		} # end if pst_exempt ne 'Y'
	} # end if ! $$self{'state_tax'};
	return $$self{'state_tax'};
} # end sub state_tax

sub harmonized_tax {
	my ( $self, $new ) = @_;
	if ( $new ) {
		$$self{'harmonized_tax'} = $new;
	} elsif ( ! defined $$self{'harmonized_tax'} ) {
		$$self{'harmonized_tax'} = '';
		if ( $self->Company()->pst_exempt() ne 'Y' ) {
			my @Taxes = openprint::Tax::find('country'=>$self->country(), 'state'=>$self->state() );
			if ( @Taxes == 1 ) {
				my $tax_rate = $Taxes[0]->harmonizedtax_rate();
				if ( $tax_rate ) {
					$$self{'harmonized_tax'} = $self->subtotal() * ( $tax_rate/100 );
				} # end if tax_rate
			} # no tax for this state/country
		} # end if exempt
	} # end if ! $$self{'harmonized_tax'};
	return $$self{'harmonized_tax'};
} # end sub harmonized_tax

sub subtotal {
	my $self = shift;
	if ( @_ ) {
		$$self{'subtotal'} = shift;
	} elsif ( sets::isin($$self{'status'}, ['Re-Opened','Incomplete'] ) or ! $$self{'subtotal'} ) {
		$$self{'subtotal'} = 0;
		foreach my $Project ( $self->Projects() ) {
			my $price = $Project->ordered_price();
#$log->debug("subtotal: ordered price: $price");
			if ( $Project->currency_id() != $$self{'currency_id'} ) {
				my $rate = $Project->Currency()->conversions( $$self{'currency_id'} );
				$price *= $rate;
#$log->debug("subtotal: ordered price converted to: $price");
			} # end if
			$$self{'subtotal'} += $price;
		} # end foreach Project
		foreach my $Product ( $self->Products() ) {
			my $price = $Product->price();
#$log->debug("subtotal: ordered price: $price");
			if ( $Product->currency_id() != $$self{'currency_id'} ) {
				my $rate = $Product->Currency()->conversions( $$self{'currency_id'} );
				$price *= $rate;
#$log->debug("subtotal: ordered price converted to: $price rate($rate) $$self{'currency_id'} != ".$Product->currency_id());
			} # end if
			$$self{'subtotal'} += $price;
		} # end foreach Project
	} # end if
	return $$self{'subtotal'};
} # end sub subtotal

sub total {
	my $self = shift;
	if ( @_ ) {
		$$self{'total'} = shift;
	} elsif ( sets::isin( $$self{'status'}, ['Re-Opened','Incomplete'] ) or ! $$self{'total'} ) {
		$$self{'total'} = $self->subtotal() + $self->state_tax() + $self->federal_tax() + $self->harmonized_tax();
$log->debug("Calcingtotal $$self{total}");
	} # end if
	return $$self{'total'};
} # end sub total

sub send_completion_notice {
    my ( $self ) = @_;

    my %order;
    $order{'OrderID'} = $self->id();
    $order{'Order'} = $self;

    my @attachments = ();

    $order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_completion_notice.html' );
    $order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
    my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
    $_ = MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
    my @body = ('', $_, 'text/html', 'quoted-printable');

    $_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order.html' );
    if ( $_ ) {
        $_ = MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$_, \%order ) ) );
        push @attachments, "Order$$self{id}.html", $_, 'text/html', 'quoted-printable';
    } # end if
    #my %mail = (
        #SMTP   => $config{'Mail Server'},
        #FROM   => $config{'AccountingEmail'},
        ##TO        => $order{'txtEmail'},
        #TO     => 'keith@point-one.com, iconnor@point-one.com',
        #SUBJECT => "Order $order_id Is Complete",
#);
    #misc::send_email_with_attachment( $log, \%mail, @body, @attachments );
} # end sub send_completion_notice

# This is a self-contained function that sends the email messages for a specified order to the apropriate people.
# >Something to note:  the order email is sent in the currency that the order is stored in, not neccessarily the current currency
sub send_sales_order {
    my ( $self ) = @_;
    my %order;

    $order{'OrderID'} = $$self{'id'};
    $order{'Order'} = $self;

	# When an order is made,the Order currency will be the current session Currency.  
	# All resends should stay in the currency that the order was created in.
    my $Currency = $self->Currency();
    @order{'CurrencyName','CurrencySymbol'} = ($Currency->name(), $Currency->symbol() );
    $order{'Currency'} = $Currency;
    my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );

    $order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order_body.html' );
    $order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
    my @body = ('', MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%order ) ) ), 'text/html', 'quoted-printable');

    my @sales_order;
    my $sales_order = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order.html' );
    $order{'ReplacementText'} = ssi::variable_substitution( \$sales_order, \%order );
    $_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
    @sales_order = ( "Order$$self{id}.html", $_, 'text/html', 'quoted-printable' );

    # Add a project summary for each project in the order
    my @project_summaries = ();
    my $content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/project_summary.html' );
    foreach my $Project ($self->Projects()) {
        my %data;
        openprint::print_project::summary( $openprint::r, $log, $dbh, \%data, $Project->id() );
        $variable{'ReplacementText'} = ssi::variable_substitution( \$content, \%data );
        push @project_summaries, "ProjectSummary$$Project{id}.html", MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%data ))), 'text/html', 'quoted-printable';
    } # for each Project

    my $sales_person_email;
    if ( $self->salesrep_id() ) {
        my $CSR = new openprint::User( $self->salesrep_id() );
        $sales_person_email = sprintf( '"%s" <%s>', $CSR->name(), $CSR->email() );
    }
    if ( ! $sales_person_email ) {
        $sales_person_email = $config{'OrderingEmail'};
    } # end if
    my %mail = (
        SMTP    => $config{'Mail Server'},
        FROM    => $sales_person_email,
        TO      => sprintf('"%s %s" <%s>', $self->get('firstname','lastname','email')),
        BCC     =>  'iconnor@penultima.org',
        SUBJECT => "Order $$self{id}",
);
    misc::send_email_with_attachment( $log, \%mail, @body, @sales_order, @project_summaries );

    $order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_admin_body.html' );
    $order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
    my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
    $_ = MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
    my @body = ('', $_, 'text/html', 'quoted-printable');
    my @sales_order;
    $order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order_for_admin.html' );
    $order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
    $_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
    @sales_order = ( "Order$$self{id}.html", $_, 'text/html', 'quoted-printable' );
    my @project_dockets = ();

    $log->debug("***************** ADDING PROJECT DOCKET *************************");
    my $content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_docket_sheet.html' );
    foreach my $Project ($self->Projects()) {
        my %data;
        openprint::print_project::summary( $openprint::r, $log, $dbh, \%data, $Project->id() );
        if ( $_ ) {
            $_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$content, \%data ) ) );
            push @project_dockets, "ProjectDocket$$Project{id}.html", $_, 'text/html', 'quoted-printable';
        } # end if
    } # for each

    my @admin_emails = split( ',', $config{'OrderingEmail'} );
    @admin_emails = map { lc; misc::trim($_) } @admin_emails;

    my @accounting_emails = split( ',', $config{'AccountingEmail'} );
    @accounting_emails = map { lc; misc::trim($_) } @accounting_emails;

    @admin_emails = sets::union( @admin_emails, @accounting_emails, $sales_person_email );

    if ( @admin_emails ) {
        my %mail = (
                SMTP    => $config{'Mail Server'},
# Only for Amin
                FROM    => $config{'OrderingEmail'},
                'Reply-to'    => $$self{'email'},
                #FROM   => $config{'OrderingEmail'},
                TO      => join(',',@admin_emails),
                BCC     =>  'iconnor@penultima.org',
                SUBJECT => "Order $$self{id}",
                );
        misc::send_email_with_attachment( $log, \%mail, @body, @sales_order, @project_summaries, @project_dockets );
    } # end if

} # end sub send_sales_order

sub owing {
	return $_[0]{'total'} - $_[0]{'paid'};
}

1;
__END__
