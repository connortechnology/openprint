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

%fields = (
	'id'						=> 'index',
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
	'first_name'				=> 'strfirstname',
	'last_name'					=> 'strlastname',
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
	if ( $params{'salesrep_id'} ) {
		$sql .= ' AND employeeindex=?';
		push @values, $params{'salesrep_id'};
	} # end if
	if ( $params{'currency_id'} ) {
		$sql .= ' AND currencyindex=?';
		push @values, $params{'currency_id'};
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
$openprint::log->debug("Loaded order: " . $$self{'id'} . ', company_id: ' . $$self{'company_id'} );
} # end sub load

sub save {
	my ( $self, $params ) = @_;

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
		sql::update( $log, $dbh, 'Orders', ['Index=?', $$self{'id'}], 'strStatus', $new_status );
		$$self{'status'} = $new_status;
		$self->add_log( "Changed Status to $new_status" );
	} # end if
	return $$self{'status'};
} # end sub status

# Adding Waiting For Pickup, Shipped, Picked Up
sub update_status {
	my $self = shift;

	# selects are very lightweight, so let's only update when we have to!
	$_ = q{SELECT DISTINCT(strStatus) FROM Projects WHERE Index IN (SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?)};
	my @statuses = sql::execute( $log, $dbh, $_, $$self{id} );

	if ( sets::isin( 'Pending Deposit', \@statuses ) and $self->status() ne 'Pending Deposit' ) {
		return $self->status( 'Pending Deposit' );
	} elsif (	sets::isin( 'Waiting For Customer Approval', \@statuses ) ) {
		return $self->status( 'Waiting For Customer Approval' );
	} elsif ( sets::intersection( @statuses, 'In Prepress','Proofs Out','Approved','Printed') ) {
		$self->status( 'In Production' );
		return 'Incomplete';
	} else { # Projcets are complete
		# All projects have same shipping type, so if one is waiting, all must be waiting
		if ( sets::isin( 'Waiting For Pickup', \@statuses ) ) {
			return $self->status( 'Waiting For Pickup' );
		} elsif ( sets::isin( 'Picked Up', \@statuses ) ) {
			return $self->status( 'Picked Up' );
		} elsif ( sets::isin( 'Shipped', \@statuses ) ) {
			return $self->status( 'Shipped' );
		} # end if
		return $self->status('Complete');
	} # end if

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
	return () if ! $$self{'id'};
	return map {new openprint::Project( $_ );} sql::execute( undef, undef, q{SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?}, $$self{'id'} );
}

sub Products {
	my $self = shift;
	return () if ! $$self{'id'};
	return openprint::OrderedProduct::find( 'order_id'=>$$self{id} );
} # end sub Products

sub name {
	my $self = shift;
	return $$self{'first_name'} . ' ' . $$self{'last_name'};
} # end sub name

sub balance {
	my $self = shift;
	return 1*($$self{'total'} - $$self{'paid'});
} # end sub balance

sub sub_total {
	my $self = shift;
	my $subtotal = 0;
	foreach my $Project ($self->Projects() ) {
		# This is really neat actually.	When the project is ordered, this gives the price stored in order_contents, but if the order isn't finalized, then it gives the price stored in the project...
		if ( $Project->currency_id() != $$self{'currency_id'} ) {
$openprint::log->debug("sub_total: $$Project{'currency_id'} != $$self{'currency_id'}");
			my $rate = $Project->Currency()->conversions( $$self{'currency_id'} );
			$subtotal += ( $rate * $Project->ordered_price() );
		} else {
			$subtotal += $Project->ordered_price();
		} # end if
	} # end foreach
	foreach my $P ($self->Products() ) {
		$subtotal += $P->price();
	} # end foreach
	return $subtotal;
} # end sub sub_total

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

sub federal_tax {
	my ( $self, $new ) = @_;
	if ( $new ) {
		$$self{'federal_tax'} = $new;
	} elsif ( ! $$self{'federal_tax'} ) {
		my @Taxes = openprint::Tax::find('country'=>$self->country() );
		if ( @Taxes == 1 ) {
			my $tax_rate = $Taxes[0]->federaltax_rate();
			my $tax_amount = 0;
			my $Company = $self->Company();
			my $gst_exempt = $Company->gst_exempt();

			foreach my $Project ( $Order->Projects() ) {
				my $price = $Project->ordered_price();
				if ( $Project->currency_id() != $$self{'currency_id'} ) {
					my $rate = $Project->Currency()->conversions( $$self{'currency_id'} );
					$price *= $rate;
				} # end if
				$tax_amount += $price * ($tax_rate/100) if ( $tax_rate and $gst_exempt ne 'Y' );
			} # end foreach Project
			foreach my $Product ( $Order->Products() ) {
				if ( $Product->currency_id() != $$self{'currency_id'} ) {
					my $rate = $Product->Currency()->conversions( $$self{'currency_id'} );
					$price *= $rate;
				} # end if
				$tax_amount += $price * ($tax_rate/100) if ( $tax_rate and $gst_exempt ne 'Y' );
			} # end foreach Project
			$$self{'federal_tax'} = $tax_amount;
		} # no tax for this state/country
	} # end if ! $$self{'federal_tax'};
	return $$self{'federal_tax'};
} # end sub federal_tax

sub state_tax {
	my ( $self, $new ) = @_;
	if ( $new ) {
		$$self{'state_tax'} = $new;
	} elsif ( ! $$self{'state_tax'} ) {
		my @Taxes = openprint::Tax::find('state'=>$self->state() );
		if ( @Taxes == 1 ) {
			my $tax_rate = $Taxes[0]->statetax_rate();
			my $tax_amount = 0;
			my $Company = $self->Company();
			my $pst_exempt = $Company->pst_exempt();

			foreach my $Project ( $Order->Projects() ) {
				my $price = $Project->ordered_price();
				if ( $Project->currency_id() != $$self{'currency_id'} ) {
					my $rate = $Project->Currency()->conversions( $$self{'currency_id'} );
					$price *= $rate;
				} # end if
				$tax_amount += $price * ($tax_rate/100) if ( $tax_rate and $pst_exempt ne 'Y' );
			} # end foreach Project
			foreach my $Product ( $Order->Products() ) {
				if ( $Product->currency_id() != $$self{'currency_id'} ) {
					my $rate = $Product->Currency()->conversions( $$self{'currency_id'} );
					$price *= $rate;
				} # end if
				$tax_amount += $price * ($tax_rate/100) if ( $tax_rate and $pst_exempt ne 'Y' );
			} # end foreach Project
			$$self{'state_tax'} = $tax_amount;
		} # no tax for this state/country
	} # end if ! $$self{'state_tax'};
	return $$self{'state_tax'};
} # end sub state_tax

sub harmonized_tax {
	my ( $self, $new ) = @_;
	if ( $new ) {
		$$self{'harmonized_tax'} = $new;
	} elsif ( ! $$self{'harmonized_tax'} ) {
		my @Taxes = openprint::Tax::find('state'=>$self->state(),'country'=>$self->country() );
		if ( @Taxes == 1 ) {
			my $tax_rate = $Taxes[0]->harmonisedtax_rate();
			my $tax_amount = 0;
			my $Company = $self->Company();
			my ( $pst_exempt, $gst_exempt ) = ( $Company->pst_exempt(), $Company->gst_exempt() );

			foreach my $Project ( $Order->Projects() ) {
				my $price = $Project->ordered_price();
				if ( $Project->currency_id() != $$self{'currency_id'} ) {
					my $rate = $Project->Currency()->conversions( $$self{'currency_id'} );
					$price *= $rate;
				} # end if
				$tax_amount += $price * ($tax_rate/100) if ( $tax_rate and $pst_exempt ne 'Y' );
			} # end foreach Project
			foreach my $Product ( $Order->Products() ) {
				if ( $Product->currency_id() != $$self{'currency_id'} ) {
					my $rate = $Product->Currency()->conversions( $$self{'currency_id'} );
					$price *= $rate;
				} # end if
				$tax_amount += $price * ($tax_rate/100) if ( $tax_rate and $pst_exempt ne 'Y' );
			} # end foreach Project
			$$self{'harmonized_tax'} = $tax_amount;
		} # no tax for this state/country
	} # end if ! $$self{'harmonized_tax'};
	return $$self{'harmonized_tax'};
} # end sub harmonized_tax

1;
__END__
