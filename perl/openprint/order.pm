package openprint::order;

use MIME::QuotedPrint;
use Mail::Sendmail;
use Email::Valid;
use Date::Calc qw(Add_Delta_Days check_date);

use strict;
use openprint ();
use vars qw( %config );
*config = \%openprint::config;

my $debug = 1;

require sql;
require configuration;
require openprint::customer;
require openprint::Currency;
require openprint::project;
require openprint::print_project;
require openprint::service;
require openprint::Order;
require openprint::OrderedProduct;
require openprint::usergroup;
require openprint::press_schedule;
require openprint::Payment;
require openprint::Tax;
require openprint::PaperAllocation;
require openprint::PaymentType;

sub delete_order {
	my ( $log, $dbh, $order_id ) = @_;
	my $Order = new openprint::Order( $order_id );
	$Order->delete();
} # end sub delete

sub delete_unfinished_orders {
	my ( $log, $dbh, $cookie ) = @_;
	# clean out old orders
	my $ac = sql::start_transaction( $dbh );
	foreach my $order ( sql::execute( $log, $dbh, q{SELECT Index FROM Orders WHERE strSessionID=? AND strStatus='Incomplete'}, $cookie ) ) {
		delete_order( $log, $dbh, $order );
	} # end foreach
	sql::update( $log, $dbh, 'Orders', ['strSessionID=?', $cookie], 'strSessionID', undef );
	sql::end_transaction( $dbh, $ac );
} # end sub delete_unfinished_orders

sub get_unfinished_order {
	my ( $log, $dbh, $cookie, $variable ) = @_;

	# This also tests for existence of the order
	if ( $openprint::session{'OrderID'} ) {
		my $Order = new openprint::Order( $openprint::session{'OrderID'} );
		return $Order->id() if $Order->id();
	} # end if

	my ( $order_id ) = sql::execute( $log, $dbh, q{SELECT MAX(Index) FROM Orders WHERE strSessionID=? AND strStatus='Re-Opened'}, $cookie );
	if ( ! $order_id ) {

		$_ = q{SELECT Index, CompanyIndex, UserIndex FROM Orders WHERE strSessionID=? AND strStatus='Incomplete'};
		( $order_id, my $cust_id, my $user_id ) = sql::execute( $log, $dbh, $_, $cookie );

		if ( $order_id ) {
			if ( $cust_id != $openprint::session{'company_id'} ) {
				my ( $emp_id ) = sql::execute( $log, $dbh, q{SELECT lngSalesPerson FROM Company WHERE Index=?}, $openprint::session{'company_id'} );
				sql::update( $log, $dbh, 'Orders', ['Index=?',$order_id], 'CompanyIndex', $openprint::session{'company_id'}, 'EmployeeIndex', $emp_id );
			} # end if
			if ( $user_id != $openprint::session{'user_id'} ) {
				sql::update( $log, $dbh, 'Orders', ['Index=?',$order_id], 'UserIndex', $openprint::session{'user_id'} );
			} # end if
		} # end if
	} # end if

	return $order_id;
} # end sub get_unfinished_order

sub get_order_id {
	my ( $log, $dbh ) = @_;
	my ( $order ) = sql::execute( $log, $dbh, 'SELECT MAX(Index) FROM Orders' );

	$order =~ /(\d\d\d\d)/;
	if ( $1 != ( 1900 + (localtime(time))[5] ) or $order eq '' ) {
		return 1900 + (localtime(time))[5] . '0001';
	} # end if
	return $order + 1;
} # end sub get_order_id

sub add_product {
	my ( $order_id, $product_id, $quantity ) = @_;

	my $error = '';

	return if check_credit( $openprint::log, $openprint::dbh, $openprint::variable );

	$order_id = get_unfinished_order( $openprint::log, $openprint::dbh, $openprint::session{_session_id}, $openprint::variable ) if ! $order_id;
	$order_id = create_order( $openprint::log, $openprint::dbh, $openprint::session{_session_id}, $openprint::variable ) if ! $order_id;

	my $Product;
	if ( my @Products = openprint::OrderedProduct::find( 'order_id'=>$order_id, 'product_id'=>$product_id ) ) {
		$Product = shift @Products;
		$Product->quantity( $Product->quantity() + $quantity );
		$error .= $Product->save();
	} else {
		$Product = new openprint::OrderedProduct();
		$Product->product_id( $product_id );
		$Product->order_id( $order_id );
		$Product->quantity( $quantity );
		$error .= $Product->save();
	} # end if	
	my $Project = $Product->Project();
	$Project->order_id( $order_id );
	$Project->quantity1( $Product->quantity() );
	foreach my $service_index ( sql::execute( undef, undef, q{SELECT lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $Project->id() ) ) {
		openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $Project->id(), $service_index, 'txtQuantity1', $Project->quantity1() );
	} # end foreach
	foreach my $signature_service_index ( sort $Project->signatures() ) {
		openprint::service::internal_calc( $openprint::log, $openprint::dbh, $openprint::variable, $Project->id(), $signature_service_index, 'Printing' );
	} # end foreach
	openprint::service::auto_calculate( $openprint::r, $openprint::log, $openprint::dbh, $openprint::variable, $Project->id(), undef );
	#$Project->price1( $Product->price() );
	$error .= $Project->save();
$openprint::log->debug("E: $error") if $error;

	return ( $order_id, $error );
} # end sub add_product

sub add_project_to_order {
	my ( $log, $dbh, $cookie, $variable, $project_index, $order_id ) = @_;
	my $error = '';

	if ( ! $project_index ) {
		return ( undef, 'No project given.' );
	} # end if

	return if check_credit( $log, $dbh, $variable );

	$order_id = get_unfinished_order( $log, $dbh, $cookie, $variable ) if ! $order_id;
	$order_id = create_order( $log, $dbh, $cookie, $variable ) if ! $order_id;

	# make sure project isn't already in the order.
	my %sql = (
		'OrderIndex'		=>	$order_id,
		'lngProjectIndex'	=>	$project_index,
		);

	my $qty_index;
	my $num_qtys;
	my $Project = new openprint::Project( $project_index );
	my @qtys = $Project->quantities();
	foreach ( 0 .. 2 ) {
		if ( $qtys[$_] ) {
			$qty_index = $_ + 1;
			$num_qtys += 1;
		} # end if
	} # end foreach
	if ( $num_qtys == 1 ) {
		$sql{'intQuantityIndex'}=$qty_index;
	} # end if
	my $services = $Project->services();
	if ( $$services{'Turnaround'} ) {
		my $specs = openprint::service::get_specs_ref( $Project, $$services{'Turnaround'}[0] );
		my ( $year, $month, $day ) = Date::Calc::Today();
		( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, $$specs{'TurnaroundDays'} );
		if ( Date::Calc::Day_of_Week( $year, $month, $day ) == 6 ) {
			( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, 2 );
		} elsif ( Date::Calc::Day_of_Week( $year, $month, $day ) == 7 ) {
			( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, 1 );
		} # end if
		$sql{'dateRequired'} = join('-', $year, $month, $day );
	} # end if
	my @ShippingServices = openprint::ServiceType::find('category'=>'Shipping');
	if ( @ShippingServices ) {
		foreach my $ShippingType ( @ShippingServices ) {
			next if sets::isin( $ShippingType->name(), ['Turnaround'] );
			if ( $$services{$ShippingType->name()} ) {
				$sql{'ShippingType'}=$ShippingType->name();
				last;
			} # end if
		} # end foreach
		if ( ! $sql{'ShippingType'} ) {
			$sql{'ShippingType'} = 'CustomerPickUp';
		} # end if
	} else {
		$sql{'ShippingType'}='CustomerPickUp';
	} # end if

	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE Order_Contents IN SHARE ROW EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
				
	# make sure project isn't already in the order.
	sql::execute( $log, $dbh, q{DELETE FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, $order_id, $project_index );
	sql::insert( $log, $dbh, 'Order_Contents', \%sql );
	sql::end_transaction( $dbh, $ac );
	
	$Project->order_id( $order_id );
	$Project->save();

	add_to_log( $log, $dbh, $order_id, @openprint::session{'company_id','user_id'}, "Add Project $project_index" );
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Add to Order $order_id" );

	return ( $order_id, $error );
} # end sub add_project_to_order


# creates a new order
# attempts to copy data from the specified quote into the order.
# does NOT verify that the quote exists.
# does NOT delete the quote
sub make_order_from_quote {
	my ( $r, $log, $dbh, $cookie, $quote_id, $variable ) = @_;
	my $error = '';
	my $order_id;

	my @quote = sql::execute( $log, $dbh, q{SELECT ProjectIndex FROM tbl_Quote_Details WHERE quote_id=?}, $quote_id );

	if ( @quote > 0 ) {
		foreach my $project_index ( @quote ) {
			( $order_id, $_ ) =	add_project_to_order( $log, $dbh, $cookie, $variable, $project_index, $order_id );
			$error .= $_;
		} # end foreach
		return ( $order_id, $error );
	} else {
		$error .= "make_order_from_quote: Empty quote specified: $quote_id";
		$log->debug( "make_order_from_quote: Empty quote specified: $quote_id" );
	} # end if
	return ( 0, $error );
} # end sub make_order_from_quote

sub check_credit {
	my ( $log, $dbh, $variable, $amount ) = @_;
	my $credit = new openprint::customer_credit( $openprint::session{'company_id'} );

	if ( $credit->value('Hold') eq 'Y' ) {
		return misc::error( $log, $dbh, $variable, 'Credit on hold', 'Your credit account is on hold, you will not be able to place orders.' );
	} # end if

	if ( $config{'EnforceCredit'} eq 'Y' ) {
		if ( ! $credit->value('DenyDays') ) {
			if ( $credit->debt() > 0 ) {
				my $error = 'Because you do not have a credit account, your previous order must be paid in full before another order is placed.	Click <a href="/main/account/credit_application.html">here</a> to apply for a credit account now.';
				$error .= list_orders( $log, $dbh, $credit->denied_orders() );
				return misc::error( $log, $dbh, $variable, 'No Credit', $error );
			} # end if
		} else {
			if ( my @orders = $credit->denied_orders() ) {
				my $error = 'You have orders that are more than ' . $credit->value('DenyDays') . ' days overdue.	Please arrange payment before purchasing further.<br/><br/>The following orders are currently overdue:</br><br/>';
				$error .=	list_orders( $log, $dbh, @orders );
				return misc::error( $log, $dbh, $variable, 'Overdue Orders', $error );
			} # end if

# check if the price fits in their credit limit
			if ( $credit->debt() + $amount > $credit->value('Limit') ) {
				my $error = 'This order would exceed your remaining credit balance.	Please make a payment before placing another order.	To apply for additional credit click <a href="/main/account/credit_application.html">here</a>.<br/><br/>The following orders are still outstanding:<br/><br/>';
				$error .= list_orders( $log, $dbh, $credit->outstanding_orders() );
				return misc::error( $log, $dbh, $variable, 'Credit Exceeded', $error );
			} # end if
		} # end if
	} # end if EnforceCredit eq 'Y'
} # end sub check_credit

sub add_to_order {
	my ( $log, $dbh, $order_id, $variable, @data ) = @_;

# add items
	for (my $index = 0; $index < @data; $index += 2) {
		sql::insert( $log, $dbh, 'Order_Contents', (
					'OrderIndex', 		$order_id,
					'lngProjectIndex',	($data[$index] or undef),
					'intQuantityIndex', ($data[$index + 1] ne '' ? $data[$index + 1] : undef), # actually quantity can't be NULL.
					) );
		my $Project = new openprint::Project( $data[$index] );
		$Project->order_id( $order_id );
		$Project->save();
	} # end for
	return $order_id;
} # end sub add_to_order

sub create_order {
	my ( $log, $dbh, $cookie, $variable ) = @_;

	my ( $emp_id ) = sql::execute( $log, $dbh, q{SELECT lngSalesPerson FROM Company WHERE Index=?}, $openprint::session{'company_id'} );

# allocates an order, and ponuutocommit off so our locks stay active
	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE Orders IN SHARE ROW EXCLUSIVE MODE' ) or $log->error( DBI->errstr );

	my $order_id = get_order_id( $log, $dbh );

	sql::insert( $log, $dbh, 'Orders',
			'Index',			$order_id,
			'UserIndex',		( $openprint::session{'user_id'} eq '' ? undef: $openprint::session{'user_id'} ),
			'CompanyIndex',		( $openprint::session{'company_id'} eq '' ? undef: $openprint::session{'company_id'} ),
			'strSessionID',	 	$cookie,
			'curTotalSale',	 	undef,
			'curFedTax',		undef,
			'curHarmTax',		undef,
			'curProvTax',		undef,
			'dtmOrderDate',	 	'NOW()',
			'strStatus',		'Incomplete',
			'EmployeeIndex',	( $emp_id ? $emp_id : undef ),
			'CurrencyIndex',	openprint::Currency::get_current()->id(),
			);
	add_to_log( $log, $dbh, $order_id, @openprint::session{'company_id','user_id'}, 'Created' );

# unlock database
	sql::end_transaction( $dbh, $ac );

	return $order_id;
} # end sub create_order 
# the data array has the following row form: productindex, quantity, price
sub make_order {
	my ( $log, $dbh, $cookie, $variable, @data ) = @_;

# this goes before get_order_id so we re-use order_id's
	delete_unfinished_orders( $log, $dbh, $cookie );

	my $order_id = create_order( $log, $dbh, $cookie, $variable );
# add items
	add_to_order( $log, $dbh, $order_id, $variable, @data );
	return $order_id;
} # end sub make_order

sub save_project_information {
	my ( $r, $log, $dbh, $variable, $order_id, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );

	my %sql;
	if ( $openprint::param{"rdbQuantity$project_index"} ) {
		$Project->ordered_quantity_index( $openprint::param{"rdbQuantity$project_index"} );
	} elsif ( ! $Project->ordered_quantity_index() ) {
		my @qtys = $Project->quantity_indexes();
		if ( 1 == scalar @qtys ) {
			$Project->ordered_quantity_index( $qtys[0] );
		} # end if
	} # end if

	if ( $openprint::param{'ddmDueDateYear'.$project_index} and $openprint::param{'ddmDueDateMonth'.$project_index} and $openprint::param{'ddmDueDateDay'.$project_index} ) {

		if ( ! check_date(1*$openprint::param{'ddmDueDateYear'.$project_index},1*$openprint::param{'ddmDueDateMonth'.$project_index},1*$openprint::param{'ddmDueDateDay'.$project_index})) {
			return q{Date is not valid. Please select a correct date.};
		} # end if
		$sql{'dateRequired'}=sprintf('%.4d-%.2d-%.2d', @openprint::param{'ddmDueDateYear'.$project_index,'ddmDueDateMonth'.$project_index,'ddmDueDateDay'.$project_index} );
		$Project->requested_date( sprintf('%.4d-%.2d-%.2d', @openprint::param{'ddmDueDateYear'.$project_index,'ddmDueDateMonth'.$project_index,'ddmDueDateDay'.$project_index} ) );
	} # end if

	my $services = $Project->services();

	# If we are specifying the Shipping Type
	if ( $openprint::param{'ShippingType'.$project_index} ) {
		my @ServiceTypes = openprint::ServiceType::find('category'=>'Shipping');
		$log->debug("ServiceTypes: " . join(',',map { $_->name() } @ServiceTypes )) if $debug;
		foreach my $ShippingType ( @ServiceTypes ) {

			# Add or delete services as relevant
			if ( sets::isin( $ShippingType->name(), $openprint::param{'ShippingType'.$project_index} ) ) {
				if ( ! $$services{$ShippingType->name()} ) {
					my $new_service_index = openprint::print_project::insert_service( $log, $dbh, $project_index, $ShippingType->name() );
					push @{$$services{$ShippingType->name()}}, $new_service_index;
				} # end if
			} elsif ( $$services{$ShippingType->name()} ) {
				foreach ( @{$$services{$ShippingType->name()}} ) {
					openprint::print_project::delete_service( $log, $dbh, $project_index, $_ );
				} # end foreach
				delete $$services{$ShippingType->name()};
			} # end if

			if ( $$services{$ShippingType->name()} and ! sets::isin( $ShippingType->name(), ['CustomerPickUp'] ) ) {
				my @shipping_fields = (
						'txtQuantity'.$Project->ordered_quantity_index(),
						'ToCompanyName',
						'ToSalutation',
						'ToFirstName',
						'ToLastName',
						'ToAddress1',
						'ToAddress2',
						'ToCity',
						'ToStateProvince',
						'ToCountry',
						'ToPostalCode',
						'ToPhone',
						'ToFax',
						'ToEmail',
						);
				foreach my $service_id ( @{$$services{$ShippingType->name()}} ) {
					foreach my $spec ( @shipping_fields ) {
$log->debug("Sacing: $$ShippingType{name} $spec-$project_index-$service_id => " . $openprint::param{"$spec-$project_index-$service_id"} );
						openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_id, $spec, $openprint::param{"$spec-$project_index-$service_id"} ) if exists $openprint::param{"$spec-$project_index-$service_id"};
					} # end foreach field
					my $specs = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $service_id, $ShippingType->name() );
$openprint::log->warn($$specs{'alert'}) if $$specs{'alert'};
				} # end foreach service_id
			} # end if exists service
		} # end foreach ShippingType
		$Project->shippingtype( join(',', sets::intersection( keys %{$services}, map { $_->name() } @ServiceTypes ) ) );
	} # end if

	$Project->reference( $openprint::param{"Reference$project_index"} ) if $openprint::param{"Reference$project_index"};
	$Project->save();

} # end foreach save_project_information

# displays the order_info page
sub information {
	my ( $r, $log, $dbh, $cookie, $variable ) = @_;

	my $error;
	my $order_id = $openprint::param{'OrderID'};
	# Order creation can happen here as well, because we are doing away with quantity_select

	if ( $order_id and $openprint::param{'remove'} ) {
		my $project_index = $openprint::param{'remove'};
		$project_index =~ s/\D//g;
		my $ac = sql::start_transaction( $dbh );
		my $Project = new openprint::Project( $project_index );
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Remove from order $order_id" );
		$Project->docket( '' );
		$Project->order_id( '' );
		$Project->save();
		$Project->update_status();
		sql::execute( $log, $dbh, q{DELETE FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, $order_id, $openprint::param{'remove'});
		sql::end_transaction( $dbh, $ac );
	} elsif ( $openprint::param{'btnFunction'} eq 'New Order' ) {
		# Re order situation
		$order_id = make_order_from_order( $log, $dbh, $cookie, $order_id, $variable );
		return if ! $order_id;
	} elsif ( $openprint::param{'btnFunction'} eq 'ReOpen' ) {
		delete_unfinished_orders( $log, $dbh, $cookie );
		if ( $order_id = $openprint::param{'OrderID'} ) {
			sql::update( $log, $dbh, 'Orders', ['Index=?', $order_id], 'strStatus', 'Re-Opened', 'strSessionID', $cookie );
			foreach my $project_index ( sql::execute( $log, $dbh, q{SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?}, $order_id ) ) {
				sql::update( $log, $dbh, 'Order_Contents', ['OrderIndex=? AND lngProjectIndex=?', $order_id, $project_index], 'cursalesprice', undef );
				#sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND strStatus NOT IN ('Complete','Proofs Out','Approved')", 'strStatus', 'calculated' );
			} # end foreach
			add_to_log( $log, $dbh, $order_id, @openprint::session{'company_id','user_id'}, 'Re-Opened' );
		} else {
			$error = 'No OrderID given to Re-Open.';
		} # end if OrderID
	} elsif ( $openprint::param{'btnFunction'} eq 'Process Order' ) {
		if ( $openprint::param{'quote_id'} ) {
$openprint::log->debug("Making order from quote");
			( $order_id, $error ) = make_order_from_quote( $r, $log, $dbh, $cookie, $openprint::param{'quote_id'}, $variable );
		} else {
			my $project_index = $openprint::param{'ProjectIndex'};
			$_ = q{SELECT strStatus FROM Orders WHERE Index IN (SELECT OrderIndex FROM Order_Contents WHERE lngProjectIndex=?)}.
				q{AND strStatus IN ( 'Pending Deposit', 'In Production', 'Complete', 'Shipped', 'Waiting For Pickup', 'Picked Up' )};
			if ( sql::execute( $log, $dbh, $_, $project_index ) ) {
				return misc::error($log, $dbh, $variable, q{Can't order project.}, "Project $project_index has already been ordered." );
			} # end if

			# Normal Order Creation
			( $order_id, $error ) = add_project_to_order( $log, $dbh, $cookie, $variable, $openprint::param{'ProjectIndex'} );
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Continue') { # saving projcet information
		$order_id = get_unfinished_order( $log, $dbh, $cookie, $variable ) if ! $order_id;
		foreach my $project_index ( sql::execute( $log, $dbh, q{SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?}, $order_id ) ) {
			$$variable{'error'} .= save_project_information( $r, $log, $dbh, $variable, $order_id, $project_index );
		} # end foreach
	} elsif ( $openprint::param{'Product'} and $openprint::param{'Quantity'} ) {
		( $order_id, $error ) = add_product( $order_id, @openprint::param{'Product','Quantity'} );
	} # end if

	if ( $error ) {
		return misc::error( $log, $dbh, $variable, 'Error', $error );
	} # end if
	$order_id = get_unfinished_order( $log, $dbh, $cookie, $variable ) if ! $order_id;
	my $Order = new openprint::Order( $order_id );

	if ( ! $$variable{'error'} ) {
		# Only check for errors if we don't have any yet
		my @errors;
		# If there are any unspecified quantities, keep looping on the selection page.
		foreach my $Project ( $Order->Projects() ) {
			if ( ! $Project->ordered_quantity_index() ) {
				push @errors, "Please select the quantity to order for project $$Project{id}<br/>";
			} # end if
			if ( ! $Project->reference() ) {
				push @errors, "Please give project $$Project{id} a reference<br/>";
			} # end if
			if ( ! $Project->shippingtype() ) {
				push @errors, "Please select a shipping type for project $$Project{id}<br/>";
			} # end if
		} # end foreach Project
		if ( @errors ) {
			$$variable{'error'} = join('<br/>', @errors );
			#$openprint::log->error( "Order Error: $$variable{'error'}" );
		} # end if
	} # end if

# First thing to do is to try to load info directly from the order.
	 @$variable{'companyname',
	 'salutation',
	 'firstname',
	 'lastname',
	 'address1',
	 'address2',
	 'city',
	 'state',
	 'postalcode',
	 'country',
	 'phone',
	 'fax',
	 'email',
	 'alsonotify',
	} = $Order->get('company_name','salutation','first_name','last_name','address1','address2','city','state','postalcode','country','phone','fax','email','alsonotify');

	if ( $$variable{'companyname'} eq '' ) {
		my $Company = new openprint::Company($openprint::session{'company_id'});
		@$variable{'companyname',
			'address1',
			'address2',
			'city',
			'state',
			'postalcode',
			'country',
			'phone',
			'fax'} = $Company->get('name','address1','address2','city','state','postalcode','country','phone','fax');
	} # end if

	if ( $$variable{'email'} eq '' ) {
		my $User = new openprint::User( $openprint::session{user_id} );
		# Assume that we are acting on someone else's behalf
		if ( sets::isin( $openprint::session{'user_type'}, [ 'A','E'] ) ) {
		
			# WE ARE logged in as someone else
			if ( $User->company_id() != $openprint::session{'company_id'} ) {
				my @Users = openprint::User::find( 
						'company_id'=>$openprint::param{'company_id'} ? $openprint::param{'company_id'} : $openprint::session{'company_id'}, 
						'order'=>'lower(LastName),lower(FirstName)'
						);
				$User = $Users[0] if @Users;
			} # end if
		} # end if
		@$variable{'email',
			'title',
			'firstname',
			'lastname',
			'salutation',
			'phone',
			'fax',
		} = $User->get('email','title','firstname','lastname','salutation','phone','fax');

	} # end if

	$$variable{'OrderID'} = $order_id;
	$$variable{'Order'} = new openprint::Order( $order_id );

} # end sub information


# comes here on the transition from orde_info to orde_info_cred_card or order_info_digi_cheq
# stores the order information into the database
sub store_order_info {
	my ( $r, $log, $dbh, $cookie, $variable ) = @_;

	my $order_id = $openprint::param{'OrderID'};
	$order_id = get_unfinished_order( $log, $dbh, $cookie, $variable ) if ! $order_id;

	my $error = '';
	$error .= 'Company Name is a required field.<br/>' if $openprint::param{'companyname'} eq '';
	$error .= 'Address is a required field.<br/>' if $openprint::param{'address1'} eq '';
	$error .= 'City is a required field.<br/>' if $openprint::param{'city'} eq '';
	$error .= 'State/Province is a required field.<br/>' if $openprint::param{'state'} eq '';
	$error .= 'PostalCode is a required field.<br/>' if $openprint::param{'postalcode'} eq '';
	$error .= 'Country is a required field.<br/>' if $openprint::param{'country'} eq '';
	$error .= 'Email is a required field.<br/>' if	$openprint::param{'email'} eq '';
	$error .= 'Please select a company.<br/>' if exists $openprint::param{'company_id'} and ! $openprint::param{'company_id'};

	if ( ! Email::Valid->address($openprint::param{'email'}) ) {
		$error .= "Email is not a valid email address.<br>";
	} # end if

	if ( $error ) {
		return $error;
	} # end if

	my $Order = new openprint::Order( $order_id );
	if ( $openprint::param{'company_id'} ) {
		$Order->company_id( $openprint::param{'company_id'} );
		$openprint::session{'company_id'} = $openprint::param{'company_id'};
	} # end if
	$Order->po( $openprint::param{'txtPurchaseOrder'} );
	$Order->currency_id( openprint::Currency::get_current()->id() );
	return $Order->save(\%openprint::param);
} # end sub store_order_info

sub get_invoice_to {
	my ( $variable, $Order ) = @_;

	@$variable{
		'companyname',
		'salutation',
		'firstname',
		'lastname',
		'address1',
		'address2',
		'city',
		'state',
		'country',
		'postalcode',
		'phone',
		'fax',
		'email'
	} = $Order->get('company_name','salutation','first_name','last_name','address1','address2','city','state','country','postalcode','phone','fax','email');

} # end sub get_invoice_to

sub submit {
	my ($r, $log, $dbh, $cookie, $variable) = @_;
		
	my $order_id = $openprint::param{'OrderID'};
	$order_id = get_unfinished_order( $log, $dbh, $cookie, $variable ) if ! $order_id;
	my $Order = new openprint::Order( $order_id );

	if ( $openprint::param{'btnFunction'} eq 'Continue') { # saving project information
		
		foreach my $Project ( $Order->Projects() ) {
			$$variable{'error'} .= save_project_information( $r, $log, $dbh, $variable, $order_id, $Project->id() );
		} # end foreach
		foreach my $Product ( $Order->Products() ) {
			if ( exists $openprint::param{'ProductQuantity'.$Product->id()} ) {
				$openprint::param{'ProductQuantity'.$Product->id()} =~ s/\D//g;
				$Product->quantity( $openprint::param{'ProductQuantity'.$Product->id()} );
			} # end if
			#my %price = $Product->Product()->get_price( $Product->quantity() );
			#$Product->price( $price{Price} );
			$$variable{'error'} .= save_project_information( $r, $log, $dbh, $variable, $order_id, $Product->Project()->id() );
			# Need to update price to include shipping costs
			my %Price = $Product->Product()->get_price( $Product->quantity() );
$openprint::log->debug("Initial price for " . $Product->quantity() . ' is : ' . $Price{'Price'} );
			my $Project = $Product->Project();
			my $services = $Project->services();
			foreach my $ShippingType ( openprint::ServiceType::find('category'=>'Shipping') ) {
				next if ! $$services{$ShippingType->name()};
				foreach my $service_id ( @{$$services{$ShippingType->name()}} ) {
					my $specs =  openprint::service::get_specs_ref( $Project, $service_id );
					$Price{'Price'} += $$specs{'txtPrice1'};
				} # end foreach service_id
			} # end foreach
			$Product->price( $Price{'Price'} );
			$Product->requested_for( sprintf('%.4d-%.2d-%.2d', @openprint::param{'ddmDueDateYear'.$$Project{'id'},'ddmDueDateMonth'.$$Project{'id'},'ddmDueDateDay'.$$Project{'id'}} ) ) if exists $openprint::param{'ddmDueDateYear'.$$Project{'id'}};
			$Product->save();
		} # end foreach Product

		$$variable{'error'} .= store_order_info( $r, $log, $dbh, $cookie, $variable );
		if ( $$variable{'error'} ) {
			$$variable{'Redirect'} = '/main/order/information.html';
			return;
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Save Service' ) {
		my $Project = new openprint::Project( $openprint::param{'ProjectIndex'} );
		openprint::print::save_service( $r, $log, $dbh, $variable, $Project, $openprint::param{'ServiceIndex'} );
	} # end if

	my @errors;
	foreach my $Project ( $Order->Projects() ) {
		if ( ! $Project->ordered_quantity() ) {
			push @errors, "Please select the quantity to order for project $$Project{id}";
		} # end if
		if ( ! $Project->shippingtype() ) {
			push @errors, "Please select a shipping type for project $$Project{id}";
		} # end if
		if ( ! $Project->reference() ) {
			push @errors, "Please give project $$Project{id} a reference";
		} # end if
		my $services = $Project->services();
		my @ServiceTypes = openprint::ServiceType::find('category'=>'Shipping');
		foreach my $ServiceType ( @ServiceTypes ) {
			next if ! $$services{$ServiceType->name()};
			next if sets::isin( $ServiceType->name(), [ 'CustomerPickUp','Turnaround'] );
		
			foreach my $service_id ( @{$$services{$ServiceType->name()}} ) {
$log->debug("CHecking Shipping service $service_id " . $ServiceType->name() );
				my $specs = openprint::service::get_specs_ref( $Project, $service_id );
# do error checks
				push @errors, 'Please enter the Shipping Company Name.' if ! $$specs{'ToCompanyName'};
				push @errors, 'Please enter the Shipping Address.' if ! $$specs{'ToAddress1'};
				push @errors, 'Please enter the Shipping City.' if ! $$specs{'ToCity'};
				push @errors, 'Please enter the Shipping State/Province.' if ! $$specs{'ToStateProvince'};
				push @errors, 'Please enter the Shipping PostalCode.' if ! $$specs{'ToPostalCode'};
				push @errors, 'Please enter the Shipping Country.' if ! $$specs{'ToCountry'};
				push @errors, 'Please enter the Shipping Phone.' if ! $$specs{'ToPhone'};
				push @errors, 'Please enter the Shipping Email.' if	! $$specs{'ToEmail'};

				if ( ! Email::Valid->address($$specs{'ToEmail'} ) ) {
					push @errors, 'Shipping Email is not a valid email address.';
				} # end if
	
				if ( openprint::service::status( $Project->id(), $service_id ) eq 'uncalculated' ) {
					push @errors, 'Unable to calculate shipping:' . $$specs{'alert'}.'.';
				} # end if
			} # end foreach service_id
		} # end foreach ServiceType
	} # end foreach  Project
	if ( @errors ) {
		%openprint::param = ();
		$$variable{'error'} .= join('<br/>', @errors );
		$$variable{'Redirect'} = '/main/order/information.html';
		return;
	} # end if
	
	my $Currency = openprint::Currency::get_current();
	@$variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
	$$variable{'Currency'} = $Currency;
	$$variable{'Order'} = $Order;

	foreach my $Project ( $Order->Projects() ) {
		if ( $Project->order_id() != $order_id ) {
			$Project->order_id( $order_id );
			$Project->save();
		} # end if
	} # end foreach Project

	$$variable{'OrderID'} = $order_id;

	@{$$variable{'Projects'}} = $Order->Projects();
	$$variable{'Order'} = $Order;

	if ( sets::isin( $openprint::session{'user_type'}, ['A','E'] ) ) {
		$$variable{'AdministratorName'} = new openprint::User( $openprint::session{'user_id'} )->name();
	} # end if

} # end sub submit

sub finalise_order {
	my ( $r, $log, $dbh, $cookie, $variable ) = @_;

	my $order_id = $openprint::param{'OrderID'};
	$order_id = get_unfinished_order( $log, $dbh, $cookie, $variable ) if ! $order_id;
	if ( $order_id eq '' ) {
		$log->error( "Still no Order ID" );
		return;
	} # end if

	my $Order = new openprint::Order( $order_id );

	if ( $Order->id() and ( sets::isin( $Order->status(), ['Incomplete','Re-Opened'] ) ) ) {
		# Commit Project Information
		my @Taxes = openprint::Tax::find('state'=>$Order->state(),'country'=>$Order->country() );
		my ( $pst_rate, $hst_rate, $gst_rate ) = $Taxes[0]->get('statetax_rate','harmonisedtax_rate','federaltax_rate') if @Taxes;

		my $Company = $Order->Company();
		my ( $pst_exempt, $gst_exempt ) = ( $Company->pst_exempt(), $Company->gst_exempt() );

		my $sub_total = 0;
		my $gst_total;
		my $pst_total;
		my $hst_total;
		my $total = 0;

		foreach my $Project ( $Order->Projects() ) {
			my ( $pst_amount, $gst_amount, $hst_amount );

			my $price = $Project->ordered_price();
			my $qty = $Project->ordered_quantity();

			if ( $Project->currency_id() != $openprint::session{'Currency_id'} ) {
				my $rate = $Project->Currency()->conversions( $openprint::session{'Currency_id'} );
				$price *= $rate;
			} # end if

# get product tax exemption

			if ( $pst_rate ne '' ) {
				if ( $pst_exempt ne 'Y' ) {
					$pst_amount = $price * ($pst_rate/100);
				} else {
					$pst_amount = 0;
				} # end if
			} # end if
			if ( $gst_rate ne '' ) {
				if ( $gst_exempt ne 'Y' ) {
					$gst_amount = $price * ($gst_rate/100);
				} else {
					$gst_amount = 0;
				} # end if
			} # end if

			if ( $hst_rate ne '' ) {
				if ( $gst_exempt ne 'Y' ) {
					$hst_amount = $price * ($hst_rate/100);
				} else {
					$hst_amount = 0;
				} # end if
			} # end if

			sql::update( $log, $dbh, 'Order_Contents', ['OrderIndex=? AND lngProjectIndex=?', $order_id, $Project->id()],
					'strDescription',	$Project->reference(),
					'curSalesPrice',	$price,
					'intQuantity',		$qty,
					'dblTax1', ( $gst_amount ne '' ? $gst_amount : undef ),
					'dblTax2', ( $pst_amount ne '' ? $pst_amount : undef ),
					'dblTax3', ( $hst_amount ne '' ? $hst_amount : undef ),
					);

			$sub_total += $price;
			$gst_total += $gst_amount if $gst_amount ne '';
			$pst_total += $pst_amount if $pst_amount ne '';
			$hst_total += $hst_amount if $hst_amount ne '';
			$total += $price + $gst_amount + $pst_amount + $hst_amount;
		} # end foreach Project

		foreach my $Product ( $Order->Products() ) {
			my $price = $Product->price();
			my $pst_amount = $price * ($pst_rate/100) if ( $pst_rate and $pst_exempt ne 'Y' ); 
			my $gst_amount = $price * ($gst_rate/100) if ( $gst_rate and $gst_exempt ne 'Y' );
			my $hst_amount = $price * ($hst_rate/100) if ( $hst_rate and $gst_exempt ne 'Y' );
			$sub_total += $price;
			$gst_total += $gst_amount if $gst_amount ne '';
			$pst_total += $pst_amount if $pst_amount ne '';
			$hst_total += $hst_amount if $hst_amount ne '';
			$total += $price + $gst_amount + $pst_amount + $hst_amount;
			$Product->gst($gst_amount);
			$Product->hst($hst_amount);
			$Product->pst($pst_amount);
			$Product->save();
		} # end foreach Product

		my $customer_credit = new openprint::customer_credit( $openprint::session{'company_id'} );
		my ( $downpayment ) = $customer_credit->get( 'Downpayment' );
		if ( $downpayment eq '' ) {
			$downpayment = $config{'DefaultDownpayment'};
		} # end if
		$downpayment = $total * ( $downpayment / 100 );
		$downpayment = sprintf( '%.2f', $downpayment );

		my $status = ( ( $downpayment - $Order->paid() ) > 0 ) ? 'Pending Deposit': 'In Production';
		# Get Docket #
		my ( $docket_number ) = $Order->docket();
		if ( ! $docket_number ) {
			( $docket_number ) = sql::execute( $log, $dbh, q{SELECT nextval('DocketNumber_seq')} );
		} # end if

		# This is messed up.  I think an order should never switch companies unless it doesn't have a company assigned.  I don't see how it could work any other way.
		$Order->company_id( $openprint::session{'company_id'} ) if ! $Order->company_id();
		$Order->salesrep_id( new openprint::Company( $openprint::session{'company_id'} )->salesrep_id() );
		$Order->federal_tax( $gst_total );
		$Order->state_tax( $pst_total );
		$Order->harmonized_tax( $hst_total );
		$Order->total( $total );
		$Order->downpayment( $downpayment );
		$Order->status( $status );
		$Order->administrator_name( $openprint::param{'AdministratorName'} );
		$Order->administrator_comments( $openprint::param{'AdministratorComments'} );
		$Order->docket( $docket_number );
		$Order->currency_id( $openprint::session{'Currency_id'} );
		$Order->save();

		add_to_log( $log, $dbh, $order_id, @openprint::session{'company_id','user_id'}, 'Submit Order' );
		
		$$variable{'Downpayment'} = $downpayment - $Order->paid();
		$$variable{'Downpayment'} = 0 if $$variable{'Downpayment'} < 0;
		$$variable{'Downpayment'} = sprintf( '%.2f', $$variable{'Downpayment'} );

		foreach my $Project ( $Order->Projects() ) {
			sql::update( $log, $dbh, 'tbl_Project_Contents', ["lngProjectIndex=? AND strStatus NOT IN ( 'Complete', 'Approved', 'Proofs Out', 'Waiting For Customer Approval','Waiting For QA Approval','')", $Project->id()], 'strStatus', 'Ordered' );
			$Project->docket( $docket_number );
			$Project->order_id( $Order->id() );
			$Project->status( $status eq 'Pending Deposit' ? $status : 'In Prepress' );
			$Project->save();	
			$Project->update_status();

			openprint::press_schedule::add_project_to_press_schedule( $Project );
		} # end foreach Project
		foreach my $Product ( $Order->Products() ) {
			my $Project = $Product->Project();
			sql::update( $log, $dbh, 'tbl_Project_Contents', ["lngProjectIndex=? AND strStatus NOT IN ( 'Complete', 'Approved', 'Proofs Out', 'Waiting For Client Approval','Waiting For QA Approval','')", $Project->id()], 'strStatus', 'Ordered' );
			$Project->docket( $docket_number );
			$Project->order_id( $Order->id() );
			$Project->status( $status eq 'Pending Deposit' ? $status : 'In Prepress' );
			$Project->save();	
			$Project->update_status();

			openprint::press_schedule::add_project_to_press_schedule( $Project );
		} # end foreach Product
		update_order_status( $r, $log, $dbh, $order_id );
# send out email notifications
		send_sales_order( $r, $log, $dbh, $order_id );

# *************************** WE are going to manually invoice for now *******************
		if ( $$variable{'Downpayment'} > 0 ) {
		#	send_invoice( $r, $log, $dbh, $order_id );
		} # end if
	} # end if

	$$variable{'OrderID'} = $order_id;
	$$variable{'Order'} = $Order;
	delete $openprint::session{'OrderID'}
} # end sub finalise_order

sub send_completion_notice {
	my ( $r, $log, $dbh, $order_id ) = @_;
	my %order;

	my $Order = new openprint::Order( $order_id );
	$order{'OrderID'} = $order_id;
	$order{'Order'} = $Order;

	my @attachments = ();

	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_completion_notice.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$_ = encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');

	$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order.html' );
	if ( $_ ) {
		$_ = encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$_, \%order ) ) );
		push @attachments, "Order$order_id.html", $_, 'text/html', 'quoted-printable';
	} # end if
	#my %mail = (
		#SMTP	=> $config{'Mail Server'},
		#FROM	=> $config{'AccountingEmail'},
		##TO		=> $order{'txtEmail'},
		#TO		=> 'keith@point-one.com, iconnor@point-one.com',
		#SUBJECT => "Order $order_id Is Complete",
#);
	#misc::send_email_with_attachment( $log, \%mail, @body, @attachments );
} # end sub send_completion_notice

# This is a self-contained function that sends the email messages for a specified order to the apropriate people.
sub send_sales_order {
	my ( $r, $log, $dbh, $order_id ) = @_;
	my %order;

	my $Order = new openprint::Order( $order_id );
	$order{'OrderID'} = $order_id;
	$order{'Order'} = $Order;

	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order_body.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$_ = encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');

	my @sales_order;
	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	@sales_order = ( "Order$order_id.html", encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%order ) ), 'text/html', 'quoted-printable' ) );

	# Add a project summary for each project in the order
	my @project_summaries = ();

	my $content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/project_summary.html' );
	foreach my $Project ($Order->Projects()) {
		my %variable;
		openprint::print_project::summary( $r, $log, $dbh, \%variable, $Project->id() );
		$variable{'ReplacementText'} = ssi::variable_substitution( \$content, \%variable );
		push @project_summaries, "ProjectSummary$$Project{id}.html", encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%variable ))), 'text/html', 'quoted-printable';
	} # for each Project

	my $sales_person_email;
	if ( $Order->salesrep_id() ) {
		my $CSR = new openprint::User( $Order->salesrep_id() );
		$sales_person_email = sprintf( '"%s" <%s>', $CSR->name(), $CSR->email() );
	} else {
		$sales_person_email = $config{'OrderingEmail'};
	} # end if

	my %mail = (
		SMTP	=> $config{'Mail Server'},
		FROM	=> $sales_person_email,
		TO		=> $order{'email'},
		BCC		=>	'iconnor@penultima.org',
		SUBJECT => "Order $order_id",
);
	misc::send_email_with_attachment( $log, \%mail, @body, @sales_order, @project_summaries );

	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_admin_body.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$_ = encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');
	my @sales_order;
	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order_for_admin.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
	@sales_order = ( "Order$order_id.html", $_, 'text/html', 'quoted-printable' );
	my @project_dockets = ();

	$log->debug("***************** ADDING PROJECT DOCKET *************************");
	my $content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_docket_sheet.html' );
	foreach my $Project ($Order->Projects()) {
		my %variable;
		openprint::print_project::summary( $r, $log, $dbh, \%variable, $Project->id() );
		if ( $_ ) {
			$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$content, \%variable ) ) );
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
				SMTP	=> $config{'Mail Server'},
# Only for Amin
				FROM	=> $order{'email'},
				#FROM	=> $config{'OrderingEmail'},
				TO		=> join(',',@admin_emails),
				BCC		=>	'iconnor@penultima.org',
				SUBJECT => "Order $order_id",
				);
		misc::send_email_with_attachment( $log, \%mail, @body, @sales_order, @project_summaries, @project_dockets );
	} # end if
	
} # end sub send_sales_order

sub history {
	my ( $r, $log, $dbh, $variable ) = @_;

} # end sub history

sub get_misc {
	my ( $variable, $Order ) = @_;

	$openprint::log->debug("********* START OF Get Misc **************");
	$$variable{'Order'} = $Order;

	@$variable{'Downpayment','TOTAL', 'GST', 'HST', 'PST', 'ORDERED_BY', 'CreationDate', 'ORDER_STATUS', 'CurrencyIndex', 'PONUM','AdministratorComments','AdministratorName'} = $Order->get('downpayment','total','gst','hst','pst','ordered_by','created_on','status','currency_id','po','administrator_comments','administrator_name');

	my $Currency = new openprint::Currency( $$variable{'CurrencyIndex'} );
	@$variable{'CurrencyName','CurrencySymbol'} = ($Currency->name(), $Currency->symbol() );
	$$variable{'Currency'} = $Currency;

	if ( $Order->status() ne 'Cancelled' ) {
		$$variable{'AmountOutstanding'} = sprintf( '%.2f', $Order->total() - $Order->paid() );
		$$variable{'DepositDue'} = sprintf( '%.2f', $Order->downpayment() - $Order->paid() ) if $Order->paid() < $Order->downpayment();
	} # end if

	$$variable{'AmountPaid'} = sprintf( '%.2f', $Order->paid() );
} # end sub get_misc

# called for orde_hisd
sub history_details {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $order_id = $openprint::param{'OrderID'};
	my $Order = new openprint::Order( $order_id );

	if ( $openprint::param{'btnFunction'} eq 'Cancel' ) {
		cancel_order( $log, $dbh, $order_id );
	} elsif ( $openprint::param{'btnFunction'} eq 'Pay' ) {
		$Order->pay();
	} elsif ( $openprint::param{'btnFunction'} eq 'Save Payment' ) {

        if ( ( ! $openprint::param{'Amount'} ) or $openprint::param{'Amount'} =~ /[^-\$\d\.]/ ) {
            return misc::error( $log, $dbh, $variable, 'Invalid Amount', 'Please enter a valid monetary amount.' );
        } # end if

		my $Payment = new openprint::Payment();
		my $error .= $Payment->save( {
				'order_id'		=> $order_id,
				'payor_id'		=> $Order->company_id(),
				'recipient_id'	=> new openprint::User( $openprint::session{'user_id'} )->company_id(),
				'amount'		=> $openprint::param{'Amount'},
				'method'		=> 'Manual',
				'currency_id'	=> $Order->currency_id(),
				'description'	=> $openprint::param{'Description'},
				'completed'		=> 1,
				} );
        if ( $error ) {
            return misc::error( $log, $dbh, $variable, 'Error Saving Payment', $error );
        } # end if

        openprint::order::get_misc( $variable, $Order );

        if ( $$variable{'DepositDue'} > 0 ) {
            foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
                sql::update( $log, $dbh, 'Projects', ['Index=? AND strStatus=?', $project_index, 'In Prepress'], 'strStatus', 'Pending Deposit' );
                sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?',$project_index, 'Ordered'], 'strStatus', 'Pending Deposit' );
            } # end foreach
        } else {
            $Order->status('In Production') if $Order->status() eq 'Pending Deposit';

            foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
                sql::update( $log, $dbh, 'Projects', ['Index=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'In Prepress' );
                sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'Ordered' );
            } # end foreach
            if ( $$variable{'AmountPaid'} >= $$variable{'TOTAL'} ) {
                $Order->status('Paid') if $Order->status() eq 'Complete';
            } # end if
            $Order->save();
        } # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete Payment' ) {
		my $Payment = new openprint::Payment( $openprint::param{'payment_id'} );
		if ( ! $Payment->id() ) {
			$$variable{'error'} .= 'Invalid payment id specified.<br/>';
		} else {
			if ( my $error = $Payment->delete() ) {
				$$variable{'error'} .= 'Payment not deleted: <br/>' . $error . '<br/>';
			} else {
				$$variable{'information'} .= 'Payment deleted successfully.<br/>';
				$Order->update_status();
			} # end if
		} # end if
   } elsif ( $openprint::param{'btnFunction'} eq 'Invoice' ) {
	   $Order->invoice_id( $openprint::param{'invoice_id'} );
	   $Order->invoiced_on( 'NOW()' );
	   $Order->save();
	} elsif ( $openprint::param{'btnFunction'} eq 'Resend') {
		send_sales_order( $r, $log, $dbh, $order_id );
	} # end if
	display_order( $log, $dbh, $variable, $order_id );
} # end sub history_details

sub display_order {
	my ( $log, $dbh, $variable, $order_id ) = @_;

	if ( $order_id ) {
		my $Order = new openprint::Order( $order_id );
		get_invoice_to( $variable, $Order );
		get_misc( $variable, $Order );
		$$variable{'CCITYPROVCOUNTRY'} = misc::build_city_prov_country(@$variable{'city','state','country'} );
		$$variable{'OrderID'} = $order_id;
	} # end if
} # end sub display_order

# duplicates the given order.	returns the id of the newly created order
sub make_order_from_order {
	my ( $log, $dbh, $cookie, $src_order_id, $variable ) = @_;

	my $SRC_Order = new openprint::Order( $src_order_id );
	return 0 if check_credit( $log, $dbh, $variable, $SRC_Order->total() );

	if ( $SRC_Order->status() eq '' ) {
		misc::error( $log, $dbh, $variable, 'Can\'t re-order.', 'Order does not exist.' );
		return 0;
	} elsif ( ! sets::isin( $SRC_Order->status(), 'Complete', 'Paid',	'Shipped', 'Waiting For Pickup', 'Picked Up' ) ) {
		misc::error( $log, $dbh, $variable, 'Can\'t re-order.', 'The given order is not complete.' );
		return 0;
	} else {
		# this goes before get_order_id so that we re-use orderids
		delete_unfinished_orders( $log, $dbh, $cookie );

		# get the contents
		my @contents = sql::execute( $log, $dbh, q{SELECT lngProjectIndex, intQuantityIndex FROM Order_Contents WHERE OrderIndex=?}, $src_order_id );

		my $order_id = make_order( $log, $dbh, $cookie, $variable, @contents );
		if ( $order_id ) {
			foreach my $Product ( $SRC_Order->Products() ) {
				my $NewProduct = $Product->copy();
				$NewProduct->order_id( $order_id );
				$NewProduct->save();
			} # end foreach
		} # end if
		return $order_id;
	} # end if
	return 0;
} # end sub make_order_from_order

sub quantity_select_display {
	my ( $r, $log, $dbh, $cookie, $variable ) = @_;

	my $error = '';
	my $order_id = $openprint::param{'OrderID'};

	if ( $openprint::param{'btnFunction'} eq 'New Order' ) {
		# Re order situation
		my $order_id = make_order_from_order( $log, $dbh, $cookie, $openprint::param{'hiddenOrderID'}, $variable );
		return if ! $order_id;
	} elsif ( $openprint::param{'btnFunction'} eq 'ReOpen' ) {
		delete_unfinished_orders( $log, $dbh, $cookie );
		if ( $order_id = $openprint::param{'OrderID'} ) {
			sql::update( $log, $dbh, 'Orders', "Index=$order_id", 'strStatus', 'Re-Opened', 'strSessionID', $cookie );
			foreach my $project_index ( sql::execute( $log, $dbh, q{SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?}, $order_id ) ) {
				sql::update( $log, $dbh, 'Projects', "Index=$project_index", 'strStatus', 'Unordered' );
				sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND strStatus NOT IN ('Complete','Proofs Out','Approved')", 'strStatus', 'calculated' );
			} # end foreach
			add_to_log( $log, $dbh, $order_id, @openprint::session{'company_id','user_id'}, 'Re-Opened' );
		} else {
			$error = 'No OrderID given to Re-Open.';
		} # end if OrderID
	} elsif ( $openprint::param{'quote_id'} ne '' ) {
		# Make order from quote
		( $order_id, $error ) = make_order_from_quote( $r, $log, $dbh, $cookie, $openprint::param{'quote_id'}, $variable );
	} elsif ( $openprint::param{'btnFunction'} eq 'Process Order') {
		# Normal Order Creation
		( $order_id, $error ) = add_project_to_order( $log, $dbh, $cookie, $variable, $openprint::param{'ProjectIndex'} );
	} elsif ( $openprint::param{'btnFunction'} eq 'Continue') {
		delete_unfinished_orders( $log, $dbh, $cookie );
	} # end if

	if ( $error ) {
		return misc::error( $log, $dbh, $variable, 'Error', $error );
	} # end if

	$order_id = get_unfinished_order( $log, $dbh, $cookie, $variable ) if ! $order_id;
	$openprint::session{'OrderID'} = $order_id;

	if ( $openprint::param{'remove'} ) {
		my $project_id = $openprint::param{'remove'};
		$project_id =~ s/\D//;
		my $Project = new openprint::Project( $project_id );
		$Project->docket( '' );
		$Project->order_id( '' );
		$Project->save();
		sql::execute( $log, $dbh, q{DELETE FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, $order_id, $project_id );
	} # end if

	# List quantities for all projects in the order, so we can select them.
	$$variable{'OrderID'} = $order_id;
	my $Order = new openprint::Order( $order_id );
	@{$$variable{'Projects'}} = $Order->Projects();

	my @time = localtime(time);
	my ( $selected_year, $selected_month, $selected_day ) = Add_Delta_Days( $time[5], $time[4]+1, $time[3], 14 );
	$$variable{'years'} = ssi::getyears((localtime(time))[5]+1900, (localtime(time))[5]-100, $selected_year+1900 );
	$$variable{'days'} = ssi::getdays($selected_day);
	$$variable{'months'} = ssi::getmonths($selected_month);

} # end sub quantity_select_display

sub cancel_order {
	my ( $log, $dbh, $order_id ) = @_;

	my $Order = new openprint::Order( $order_id );
	sql::update( $log, $dbh, 'Orders', ['Index=?',$order_id], 'strStatus', 'Cancelled' );
	$_ = 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?';
	foreach my $project_index ( sql::execute( $log, $dbh, $_, $order_id ) ) {
		my $Project = new openprint::Project( $project_index );
		$Project->status('Unordered');
		$Project->order_id( undef );
		$Project->docket( undef );
		$Project->save();
		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus!=?', $project_index, 'Complete'], 'strStatus', 'calculated' );
		openprint::press_schedule::remove( $Project->id() );

		# Free up any stock allocated to this project
		foreach my $PA ( openprint::PaperAllocation::find('project_id'=>$Project->id()) ) {
			$Project->add_to_log( @openprint::session{'company_id','user_id'}, qq`De-allocated $$PA{'quantity'}$$PA{'units'} of <a href="/employee/inventory/paper_details.html?paper_id=$$PA{'paper_id'}">` . $PA->Paper()->to_string() . ($PA->skid_id()?qq`</a> on skid <a href="/employee/inventory/skids.html?skid_id=$$PA{skid_id}">$$PA{skid_id}</a>` : '') );
			$PA->delete();
		} # end foreach PA
	} # end foreach
	add_to_log( $log, $dbh, $order_id, @openprint::session{'company_id','user_id'}, 'Cancelled' );
	$Order->send_cancellation_notice();
} # end sub cancel_order


sub fill_user_info {
	my ( $r, $log, $dbh, $variable, $user_index ) = @_;

	if ( $user_index ) {
		my %info;
		my $User = new openprint::User( $user_index );
		@info{'email','title','firstname','lastname','salutation','phone','fax'} = $User->get('email','title','firstname','lastname','salutation','phone','fax');
		my @results;
		foreach my $key ( keys %info ) {
			push @results, "$key~$info{$key}";
		} # end foreach
		return join( '|', @results );
	} # end if
	return;

} # end sub fill_user_info

sub update_order_status {
	my ( $r, $log, $dbh, $order_id ) = @_;

	my $Order = new openprint::Order( $order_id );
	if ( 'Complete' eq $Order->update_status() ) {

		send_completion_notice( $r, $log, $dbh, $order_id );

		if ( $config{'SendInvoiceOnProjectCompletion'} ne 'N' ) {
			send_invoice( $r, $log, $dbh, $order_id );
		} # end if
	} # end if

} # end sub update_order_status

sub add_to_log {
	my ( $log, $dbh, $order_id, $cust_id, $user_id, $message ) = @_;
	sql::insert( $log, $dbh, 'Order_Log', [
				'Order_Id',	$order_id,
				'Company_Id',	$cust_id ? $cust_id : undef,
				'User_Id',	$user_id,
				'Description',	$message,
				] 
			);
}

sub list_orders {
	my ( $log, $dbh, @orders ) = @_;
	my $html = qq{
<table class="List">
		<tr>
			<th align="left" width="75">Order ID</th>
			<th align="center" width="75">Date</th>
			<th align="center">Ordered By</th>
			<th align="center" width="125">Status</th>
			<th align="right" width="75">Total</th>
			<th align="right" width="100">Balance</th>
		</tr>
	};
	my ( $report_total, $report_balance );
	my $row_class = '';
	foreach my $order_id ( @orders ) {
		my ( $date, $name, $status, $total, $payment, $currency_id ) = sql::execute( $log, $dbh,
				q{SELECT	to_char(dtmOrderDate, 'MM/DD/YYYY'), strFirstName || ' ' || strLastName, strStatus, curTotalSale,(SELECT SUM(amount) FROM Payments WHERE order_id=? AND (deleted=false OR deleted IS NULL) AND completed=true), currency_id FROM Orders WHERE Index=?}, $order_id, $order_id );
		$report_total += $total;
		$report_balance += $total-$payment;
		$total = sprintf('%.2f', $total );
		my $balance = sprintf('%.2f', $total-$payment );
		my $Currency = new openprint::Currency( $currency_id );
		my $symbol = $Currency->symbol();

		$html .= qq{
<tr class="$row_class">
			<td><a href="/main/order/history_details.html?order_id=$order_id">&nbsp;$order_id</a></td>
			<td align="center">&nbsp;$date</td>
			<td align="center">&nbsp;$name</td>
			<td align="center">&nbsp;$status</td>
			<td align="right">&nbsp;$symbol $total</td>
			<td align="right">&nbsp;$symbol $balance</td>
		</tr>
		};
		$row_class = $row_class eq '' ? 'colRow' : '';
	} # end foreach $order_id
	$html .= qq{
		<tr class="totals">
			<td colspan="4" align="right"><b>Report Total:</b></td>
			<td align="right">&nbsp;\$ $report_total</td>
			<td align="right">&nbsp;\$ $report_balance</td>
		</tr>
	</table>
};
	return $html;
} # end sub list_orders

1;
__END__
