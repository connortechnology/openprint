package openprint::order;

use MIME::QuotedPrint;
use Mail::Sendmail;
use Email::Valid;
use Date::Calc qw(Add_Delta_Days check_date);

use strict;
use openprint ();
use vars qw( %config );
*config = \%openprint::config;


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
	$Project->save();
	#$error .= add_project_to_order( $openprint::log, $openprint::dbh, $openprint::cookie, $openprint::variable, $Product->project_id(), $order_id );
$openprint::log->debug("E: $error");

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
		my $specs = openprint::service::get_specs_ref( $project_index, $$services{'Turnaround'}[0] );
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

	my @quote = sql::execute( $log, $dbh, q{SELECT ProjectIndex FROM tbl_Quote_Details WHERE quoteindex=?}, $quote_id );

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
	my $qty;
	if ( $openprint::param{"rdbQuantity$project_index"} ) {
		$sql{'intQuantityIndex'}=$openprint::param{"rdbQuantity$project_index"};
		$qty = $openprint::param{"rdbQuantity$project_index"};
		$Project->ordered_quantity_index( $qty );
	} elsif ( ! $Project->ordered_quantity_index() ) {
		my @qtys = $Project->quantity_indexes();
		if ( 1 == scalar @qtys ) {
			$Project->ordered_quantity_index( $qtys[0] );
			$qty = $qtys[0];
		} # end if
	} else {
		$qty = $Project->ordered_quantity_index();
	} # end if

	if ( $openprint::param{'ddmDueDateYear'.$project_index} and $openprint::param{'ddmDueDateMonth'.$project_index} and $openprint::param{'ddmDueDateDay'.$project_index} ) {

		if ( ! check_date(1*$openprint::param{'ddmDueDateYear'.$project_index},1*$openprint::param{'ddmDueDateMonth'.$project_index},1*$openprint::param{'ddmDueDateDay'.$project_index})) {
			return q{Date is not valid. Please select a correct date.};
		} # end if
		$sql{'dateRequired'}=sprintf('%.4d-%.2d-%.2d', @openprint::param{'ddmDueDateYear'.$project_index,'ddmDueDateMonth'.$project_index,'ddmDueDateDay'.$project_index} );
		$Project->requested_date( sprintf('%.4d-%.2d-%.2d', @openprint::param{'ddmDueDateYear'.$project_index,'ddmDueDateMonth'.$project_index,'ddmDueDateDay'.$project_index} ) );
	} # end if

	my $services = $Project->services();
	my @ServiceTypes = openprint::ServiceType::find('category'=>'Shipping');

	# If we are specifying the Shipping Type
	if ( $openprint::param{'ShippingType'.$project_index} ) {
		foreach my $ShippingType ( @ServiceTypes ) {
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

			if ( $$services{$ShippingType->name()} ) {
				my %shipping_fields = (
						'txtQuantity'.$Project->ordered_quantity_index()	=> 'txtQuantity'.$Project->ordered_quantity_index(),
						'ToCompanyName'		=>	'ToCompanyName',
						'ToSalutation'		=>	'ToSalutation',
						'ToFirstName'		=>	'ToFirstName',
						'ToLastName'		=>	'ToLastName',
						'ToAddress1'		=>	'ToAddress1',
						'ToAddress2'		=>	'ToAddress2',
						'ToCity'			=>	'ToCity',
						'ToStateProvince'	=>	'ToStateProvince',
						'ToCountry'			=>	'ToCountry',
						'ToPostalCode'		=>	'ToPostalCode',
						'ToPhone'			=>	'ToPhone',
						'ToExtension'		=>	'ToExtension',
						'ToFax'				=>	'ToFax',
						'ToEmail'			=>	'ToEmail',
						);
				foreach my $service_id ( @{$$services{$ShippingType->name()}} ) {
					foreach my $spec ( keys %shipping_fields ) {
						openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_id, $shipping_fields{$spec}, $openprint::param{"$spec-$project_index-$service_id"} ) if exists $openprint::param{"$spec-$project_index-$service_id"};
					} # end foreach field
					my $specs = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $service_id, $ShippingType->name() );
$openprint::log->warn($$specs{'alert'}) if $$specs{'alert'};
				} # end foreach service_id
			} # end if exists service
		} # end foreach ShippingType
	} # end if

	sql::update( $log, $dbh, 'Order_Contents', ['OrderIndex=? AND lngProjectIndex=?', $order_id, $project_index], \%sql ) if %sql;

	$Project->reference( $openprint::param{"Reference$project_index"} );
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

	if ( ! $$variable{'error'} ) {
		# Only check for errors if we don't have any yet
		my @errors;
		# If there are any unspecified quantities, keep looping on the selection page.
		my @data = sql::execute( $log, $dbh, q{SELECT intQuantityIndex, ShippingType, lngProjectIndex, (SELECT strProjectReference FROM Projects WHERE Index=lngProjectIndex) FROM Order_Contents WHERE OrderIndex=?}, $order_id );
		while ( my ( $qty, $shipping, $project_index, $ref ) = splice @data, 0, 4 ) {
			if ( ! $qty ) {
				push @errors, "Please select the quantity to order for project $project_index<br/>";
			} # end if
			if ( ! $ref ) {
				push @errors, "Please give project $project_index a reference<br/>";
			} # end if
			if ( ! $shipping ) {
				push @errors, "Please select a shipping type for project $project_index<br/>";
			} # end if

		} # end while
		if ( @errors ) {
			$$variable{'error'} = join('<br/>', @errors );
			#$openprint::log->error( "Order Error: $$variable{'error'}" );
		} # end if
	} # end if

# First thing to do is to try to load info directly from the order.
	$_ = q{SELECT strCompanyName, strSalutation, strFirstName, strLastName, strAddress1, strAddress2, strCity, strState, strPostalCode, strCountry, strPhone, strExt, strFax, strEmail, strAlsoNotify FROM Orders WHERE Index=?};
	(
	 $$variable{'txtCompanyName'},
	 $$variable{'rdbSalutation'},
	 $$variable{'txtFirstName'},
	 $$variable{'txtLastName'},
	 $$variable{'txtAddress1'},
	 $$variable{'txtAddress2'},
	 $$variable{'txtCity'},
	 $$variable{'ddmStateProvince'},
	 $$variable{'txtPostalCode'},
	 $$variable{'ddmCountry'},
	 $$variable{'txtPhone'},
	 $$variable{'txtExtension'},
	 $$variable{'txtFax'},
	 $$variable{'txtEmail'},
	 $$variable{'txtAlsoNotify'},
	) = sql::execute( $log, $dbh, $_, $order_id );

	if ( $$variable{'txtCompanyName'} eq '' ) {
		$_ = q{SELECT strLegalBusName, strAddress1, strAddress2, strCity, strProvState, strPostalCode, strCountry, strPhone, strExt, strFax FROM Company WHERE Index=?};
		 @$variable{'txtCompanyName',
		 'txtAddress1',
		 'txtAddress2',
		 'txtCity',
		 'ddmStateProvince',
		 'txtPostalCode',
		 'ddmCountry',
		 'txtPhone',
		 'txtExtension',
		 'txtFax'} = sql::execute( $log, $dbh, $_, $openprint::session{'company_id'} );
	} # end if

	if ( $$variable{'txtEmail'} eq '' ) {
		my $User = new openprint::User( $openprint::session{user_id} );
		# Assume that we are acting on someone else's behalf
		if ( sets::isin( $openprint::session{'user_type'}, [ 'A','E'] ) ) {
		
			# WE ARE logged in as someone else
			if ( $User->company_id() != $openprint::session{'company_id'} ) {
				my @Users = openprint::User::find( 
						'company_id'=>$openprint::param{'company_id'} ? $openprint::param{'company_id'} : $openprint::session{'company_id'}, 
						'order'=>'lower(strLastName),lower(strFirstName)'
						);
				$User = $Users[0] if @Users;
			} # end if
		} # end if
		openprint::user::load( $log, $dbh, $User->id(), $variable );
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
	$error .= 'Company Name is a required field.<br/>' if $openprint::param{'txtCompanyName'} eq '';
	$error .= 'Address is a required field.<br/>' if $openprint::param{'txtAddress1'} eq '';
	$error .= 'City is a required field.<br/>' if $openprint::param{'txtCity'} eq '';
	$error .= 'State/Province is a required field.<br/>' if $openprint::param{'ddmStateProvince'} eq '';
	$error .= 'PostalCode is a required field.<br/>' if $openprint::param{'txtPostalCode'} eq '';
	$error .= 'Country is a required field.<br/>' if $openprint::param{'ddmCountry'} eq '';
	$error .= 'Email is a required field.<br/>' if	$openprint::param{'txtEmail'} eq '';
	$error .= 'Please select a company.<br/>' if exists $openprint::param{'company_id'} and ! $openprint::param{'company_id'};

	if ( ! Email::Valid->address($openprint::param{'txtEmail'}) ) {
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
	$Order->company_name( $openprint::param{'txtCompanyName'} );
	$Order->first_name( $openprint::param{'txtFirstName'} );
	$Order->last_name( $openprint::param{'txtLastName'} );
	$Order->salutation( $openprint::param{'rdbSalutation'} );
	$Order->address1( $openprint::param{'txtAddress1'} );
	$Order->address2( $openprint::param{'txtAddress2'} );
	$Order->city( $openprint::param{'txtCity'} );
	$Order->state( $openprint::param{'ddmStateProvince'} );
	$Order->postalcode( $openprint::param{'txtPostalCode'} );
	$Order->country( $openprint::param{'ddmCountry'} );
	$Order->phone( $openprint::param{'txtPhone'} );
	$Order->extension( $openprint::param{'txtExtension'} );
	$Order->fax( $openprint::param{'txtFax'} );
	$Order->email( $openprint::param{'txtEmail'} );
	$Order->alsonotify( $openprint::param{'txtAlsoNotify'} );
	$Order->po( $openprint::param{'txtPurchaseOrder'} );
	return $Order->save();
} # end sub store_order_info

sub get_invoice_to {
	my ( $log, $dbh, $variable, $order_id ) = @_;

	$_ = "SELECT strCompanyName, strSalutation, strFirstName, strLastName, strAddress1, strAddress2, strCity, strState, strCountry, strPostalCode, strPhone, strExt, strFax, strEmail\n".
		"FROM Orders ".
		"WHERE Index = ?";
	@$variable{
		'txtCompanyName',
		'txtSalutation',
		'txtFirstName',
		'txtLastName',
		'txtAddress1',
		'txtAddress2',
		'txtCity',
		'txtStateProvince',
		'txtCountry',
		'txtPostalCode',
		'txtPhone',
		'txtExtension',
		'txtFax',
		'txtEmail'
	} = sql::execute( $log, $dbh, $_, $order_id );

} # end sub get_invoice_to
sub get_ship_to {
	my ( $log, $dbh, $variable, $order_id ) = @_;

	$_ = "SELECT strShippingCompanyName, strShippingSalutation,strShippingFirstName, strShippingLastName, strShippingAddress1, strShippingAddress2, strShippingCity, strShippingState, strShippingCountry, strShippingPostalCode, strShippingPhone, strShippingExt, strShippingFax, strShippingEmail\n".
		"FROM Orders ".
		"WHERE Index =?";
	@$variable{
		'txtShippingCompanyName',
		'txtShippingSalutation',
		'txtShippingFirstName',
		'txtShippingLastName',
		'txtShippingAddress1',
		'txtShippingAddress2',
		'txtShippingCity',
		'txtShippingStateProvince',
		'txtShippingCountry',
		'txtShippingPostalCode',
		'txtShippingPhone',
		'txtShippingExtension',
		'txtShippingFax',
		'txtShippingEmail'
	} = sql::execute( $log, $dbh, $_, $order_id );

} # end sub get_ship_to


sub verify_order {
	my ($r, $log, $dbh, $cookie, $variable) = @_;
		
	my $order_id = $openprint::param{'OrderID'};
	$order_id = get_unfinished_order( $log, $dbh, $cookie, $variable ) if ! $order_id;
	my $Order = new openprint::Order( $order_id );

	if ( $openprint::param{'btnFunction'} eq 'Continue') { # saving project information
		foreach my $project_index ( sql::execute( $log, $dbh, q{SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?}, $order_id ) ) {
			$$variable{'Error'} .= save_project_information( $r, $log, $dbh, $variable, $order_id, $project_index );
		} # end foreach
		foreach my $Product ( $Order->Products() ) {
			if ( exists $openprint::param{'ProductQuantity'.$Product->id()} ) {
				$openprint::param{'ProductQuantity'.$Product->id()} =~ s/\D//g;
				$Product->quantity( $openprint::param{'ProductQuantity'.$Product->id()} );
			} # end if
			#my %price = $Product->Product()->get_price( $Product->quantity() );
			#$Product->price( $price{Price} );
			$$variable{'Error'} .= save_project_information( $r, $log, $dbh, $variable, $order_id, $Product->Project()->id() );
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

		$$variable{'Error'} .= store_order_info( $r, $log, $dbh, $cookie, $variable );
		if ( $$variable{'Error'} ) {
			$$variable{'Redirect'} = '/main/order/information.html';
			return;
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Save Service' ) {
		my $Project = new openprint::Project( $openprint::param{'ProjectIndex'} );
		openprint::print::save_service( $r, $log, $dbh, $variable, $Project, $openprint::param{'ServiceIndex'} );
	} # end if

	my @errors;
	my @data = sql::execute( $log, $dbh, q{SELECT intQuantityIndex, ShippingType, lngProjectIndex FROM Order_Contents WHERE OrderIndex=?}, $order_id );
	while ( my ( $qty, $shipping, $project_index ) = splice @data, 0, 3 ) {
		my $Project = new openprint::Project( $project_index );
		if ( ! $qty ) {
			push @errors, "Please select the quantity to order for project $project_index";
		} # end if
		if ( ! $shipping ) {
			push @errors, "Please select a shipping type for project $project_index";
		} # end if
		if ( ! $Project->reference() ) {
			push @errors, "Please give project $project_index a reference";
		} # end if
		my $services = $Project->services();
		my @ServiceTypes = openprint::ServiceType::find('category'=>'Shipping');
		foreach my $ServiceType ( @ServiceTypes ) {
			next if ! $$services{$ServiceType->name()};
			next if $ServiceType->name() eq 'CustomerPickUp';
		
			foreach my $service_id ( @{$$services{$ServiceType->name()}} ) {
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
	
				if ( openprint::service::status( $project_index, $service_id ) eq 'uncalculated' ) {
					push @errors, 'Unable to calculate shipping:' . $$specs{'alert'}.'.';
				} # end if
			} # end foreach service_id
		} # end foreach ServiceType
	} # end while Project
	if ( @errors ) {
		$$variable{'error'} .= join('<br/>', @errors );
		$$variable{'Redirect'} = '/main/order/information.html';
		return;
	} # end if
	
	my $Currency = openprint::Currency::get_current();
	@$variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
	$$variable{'Currency'} = $Currency;
	if ( $Order->currency_id() != $Currency->id() ) {
		$Order->currency_id( $Currency->id() );
		$Order->save();
	} # end if
	@$variable{'Order','ORDERED_BY', 'CreationDate', 'ORDER_STATUS', 'CurrencyIndex', 'PONUM','AdministratorComments'} = 
( $Order, $Order->first_name() .' '.$Order->last_name(), $Order->created_on(), $Order->status(), $Order->currency_id(), $Order->po(), $Order->administrator_comments() );

	my @Taxes = openprint::Tax::find('state'=>$Order->state(),'country'=>$Order->country() );
	my ( $pst_rate, $hst_rate, $gst_rate ) = $Taxes[0]->get('statetax_rate','harmonisedtax_rate','federaltax_rate') if @Taxes;
	
	my $Company = new openprint::Company( $openprint::session{'company_id'} );
	my ( $pst_exempt, $gst_exempt ) = ( $Company->pst_exempt(), $Company->gst_exempt() );

	my $gst_total;
	my $pst_total;
	my $hst_total;
	my $total = 0;

	foreach my $Project ( $Order->projects() ) {
		if ( $Project->order_id() != $order_id ) {
			$Project->order_id( $order_id );
			$Project->save();
		} # end if

		my $price = $Project->ordered_price();

		if ( $Project->currency_id() != $openprint::session{'Currency_id'} ) {
			my $rate = $Project->Currency()->conversions( $openprint::session{'Currency_id'} );
			$price *= $rate;
		} # end if

		my $pst_amount = $price * ($pst_rate/100) if ( $pst_rate and $pst_exempt ne 'Y' ); 
		my $gst_amount = $price * ($gst_rate/100) if ( $gst_rate and $gst_exempt ne 'Y' );
		my $hst_amount = $price * ($hst_rate/100) if ( $hst_rate and $gst_exempt ne 'Y' );

		$pst_total += $pst_amount if defined $pst_amount;
		$gst_total += $gst_amount if defined $gst_amount;
		$hst_total += $hst_amount if defined $hst_amount;
		$total += $price + $gst_amount + $pst_amount + $hst_amount;
	} # end while project data

	foreach my $Product ( $Order->Products() ) {
		my $price = $Product->price();
		my $pst_amount = $price * ($pst_rate/100) if ( $pst_rate and $pst_exempt ne 'Y' ); 
		my $gst_amount = $price * ($gst_rate/100) if ( $gst_rate and $gst_exempt ne 'Y' );
		my $hst_amount = $price * ($hst_rate/100) if ( $hst_rate and $gst_exempt ne 'Y' );
		$gst_total += $gst_amount if defined $gst_amount;
		$pst_total += $pst_amount if defined $pst_amount;
		$hst_total += $hst_amount if defined $hst_amount;
		$total += $price + $gst_amount + $pst_amount + $hst_amount;
	} # end foreach Product

	$gst_total = sprintf('%.2f',$gst_total) if defined $gst_total;
	$pst_total = sprintf('%.2f',$pst_total) if defined $pst_total;
	$hst_total = sprintf('%.2f',$hst_total) if defined $hst_total;

	@$variable{'GST','PST','HST', 'TOTAL'} = ( $gst_total, $pst_total, $hst_total, sprintf('%.2f',$total) );

	$$variable{'OrderID'} = $order_id;

	@{$$variable{'Projects'}} = $Order->projects();
	$$variable{'Order'} = $Order;

	get_invoice_to( $log, $dbh, $variable, $order_id );
	$$variable{'CCITYPROVCOUNTRY'} = misc::build_city_prov_country(@$variable{'txtCity','txtStateProvince','txtCountry'} );

	if ( sets::isin( $openprint::session{'user_type'}, ['A','E'] ) ) {
		$$variable{'AdministratorName'} = new openprint::User( $openprint::session{'user_id'} )->name();
	} # end if

} # end sub verify

sub finalise_order {
	my ( $r, $log, $dbh, $cookie, $variable ) = @_;

	my $order_id = $openprint::param{'OrderID'};
	$order_id = $openprint::session{'OrderID'} if ! $order_id;
	$order_id = get_unfinished_order( $log, $dbh, $cookie, $variable ) if ! $order_id;
	if ( $order_id eq '' ) {
		$log->error( "Still no Order ID" );
		return;
	} # end if

	my $Order = new openprint::Order( $order_id );

	if ( $Order->id() and ( sets::isin( $Order->status(), ['Incomplete','Re-Opened'] ) ) ) {

		# Commit Project Information
		# get taxes
		my @Taxes = openprint::Tax::find('state'=>$Order->state(),'country'=>$Order->country() );
		my ( $pst_rate, $hst_rate, $gst_rate ) = $Taxes[0]->get('statetax_rate','harmonisedtax_rate','federaltax_rate') if @Taxes;

		$_ = q{SELECT ysnPSTExempt, ysnGSTExempt FROM Company WHERE Index=?};
		my ( $pst_exempt, $gst_exempt ) = sql::execute( $log, $dbh, $_, $openprint::session{'company_id'} );

		my @Projects = $Order->projects();
		my $sub_total = 0;
		my $gst_total;
		my $pst_total;
		my $hst_total;
		my $total = 0;

		foreach my $Project ( @Projects ) {
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
		} # end while projct data
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

		my $status = 'In Production';
		if ( ( $downpayment - $Order->paid() ) > 0 ) {
			$status = 'Pending Deposit';
		} # end if
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

		foreach my $Project ( @Projects ) {
			sql::update( $log, $dbh, 'tbl_Project_Contents', ["lngProjectIndex=? AND strStatus NOT IN ( 'Complete', 'Approved', 'Proofs Out', 'Waiting For Client Approval','Waiting For QA Approval','')", $Project->id()], 'strStatus', 'Ordered' );
			$Project->docket( $docket_number );
			$Project->order_id( $Order->id() );
			$Project->status( $status eq 'Pending Deposit' ? $status : 'In Prepress' );
			$Project->save();	
			$Project->update_status();

			openprint::press_schedule::add_project_to_press_schedule( $Project );
		} # end foreach
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

	get_invoice_to( $log, $dbh, \%order, $order_id );
	#get_ship_to( $log, $dbh, \%order, $order_id );
	get_misc( $log, $dbh, \%order, $order_id );
	get_projects( $log, $dbh, \%order, $order_id );

	$order{'CCITYPROVCOUNTRY'} = misc::build_city_prov_country(@order{'txtCity','txtStateProvince','txtCountry'} );
	$order{'OrderID'} = $order_id;

	$order{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
	$order{'siteURL'} = $r->dir_config('ExternalSiteURL');
	$order{'SiteTitle'} = $r->dir_config('SiteTitle');

	my @attachments = ();

	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_completion_notice.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$_ = encode_qp( ssi::variable_substitution( \$email_template, \%order ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');

	$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_invoice.html' );
	if ( $_ ) {
		$_ = encode_qp( ssi::variable_substitution( \$_, \%order ) );
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

sub send_invoice {
	my ( $r, $log, $dbh, $order_id ) = @_;
	my %order;

	get_invoice_to( $log, $dbh, \%order, $order_id );
	get_misc( $log, $dbh, \%order, $order_id );
	get_projects( $log, $dbh, \%order, $order_id );

	my $credit = new openprint::customer_credit( $order{'CompanyIndex'} );
	@order{$credit->fields()} = $credit->get($credit->fields());

	$order{'CCITYPROVCOUNTRY'} = misc::build_city_prov_country(@order{'txtCity','txtStateProvince','txtCountry'} );
	$order{'OrderID'} = $order_id;

	$order{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
	$order{'siteURL'} = $r->dir_config('ExternalSiteURL');
	$order{'SiteTitle'} = $r->dir_config('SiteTitle');

	my @attachments = ();

	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_invoice_body.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );

	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$_ = encode_qp( ssi::variable_substitution( \$email_template, \%order ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');

	$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_invoice.html' );
	if ( $_ ) {
		$_ = encode_qp( ssi::variable_substitution( \$_, \%order ) );
		push @attachments, "Order$order_id.html", $_, 'text/html', 'quoted-printable';
	} # end if
	my %mail = (
		SMTP	=> $config{'Mail Server'},
		FROM	=> $config{'AccountingEmail'},
		TO		=> $order{'txtEmail'},
		SUBJECT => "Invoice for Order $order_id",
);
	misc::send_email_with_attachment( $log, \%mail, @body, @attachments );

	get_projects( $log, $dbh, \%order, $order_id );

	my @attachments = ();
	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_invoice_body.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$_ = encode_qp( ssi::variable_substitution( \$email_template, \%order ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');
	$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_invoice_for_admin.html' );
	if ( $_ ) {
		$_ = encode_qp( ssi::variable_substitution( \$_, \%order ) );
		push @attachments, "Order$order_id.html", $_, 'text/html', 'quoted-printable';
	} # end if
	my %mail = (
		SMTP	=> $config{'Mail Server'},
		FROM	=> $config{'AccountingEmail'},
		TO		=> $config{'AccountingEmail'},
		SUBJECT => "Invoice for Order $order_id",
	);
	misc::send_email_with_attachment( $log, \%mail, @body, @attachments );

} # end sub send_invoice

# This is a self-contained function that sends the email messages for a specified order to the apropriate people.
sub send_sales_order {
	my ( $r, $log, $dbh, $order_id ) = @_;
	my %order;

	my $Order = new openprint::Order( $order_id );

	get_invoice_to( $log, $dbh, \%order, $order_id );
	#get_ship_to( $log, $dbh, \%order, $order_id );
	get_misc( $log, $dbh, \%order, $order_id );
	$order{'CCITYPROVCOUNTRY'} = misc::build_city_prov_country(@order{'txtCity','txtStateProvince','txtCountry'} );
	#$order{'FCITYPROVCOUNTRY'} = misc::build_city_prov_country(@order{'txtShippingCity','txtShippingStateProvince','txtShippingCountry'} );
	$order{'OrderID'} = $order_id;
	$order{'Order'} = $Order;
	$order{'Docket'} = $Order->docket();

	$order{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
	$order{'siteURL'} = $r->dir_config('ExternalSiteURL');
	$order{'SiteTitle'} = $r->dir_config('SiteTitle');

	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order_body.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$_ = encode_qp( ssi::variable_substitution( \$email_template, \%order ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');

	my @sales_order;
	get_projects( $log, $dbh, \%order, $order_id );
	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	@sales_order = ( "Order$order_id.html", encode_qp( ssi::variable_substitution( \$email_template, \%order ) ), 'text/html', 'quoted-printable' );

	# Add a project summary for each project in the order
	my @project_summaries = ();

	my @projects = sql::execute( $log, $dbh, q{SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?}, $order_id );
	foreach my $project (@projects) {
		my %variable;
		$variable{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
		$variable{'siteURL'} = $r->dir_config('ExternalSiteURL');
		$variable{'SiteTitle'} = $r->dir_config('SiteTitle');
		openprint::print_project::summary( $r, $log, $dbh, \%variable, $project );
		$variable{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/project_summary.html' );
		$variable{'ReplacementText'} = ssi::variable_substitution( \$variable{'ReplacementText'}, \%variable );
		push @project_summaries, "ProjectSummary$project.html", encode_qp( ssi::variable_substitution( \$email_template, \%variable )), 'text/html', 'quoted-printable';
	} # for each

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
		TO		=> $order{'txtEmail'},
		SUBJECT => "Order $order_id",
);
	misc::send_email_with_attachment( $log, \%mail, @body, @sales_order, @project_summaries );

	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_admin_body.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$_ = encode_qp( ssi::variable_substitution( \$email_template, \%order ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');
	my @sales_order;
	get_projects( $log, $dbh, \%order, $order_id );
	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order_for_admin.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	$_ = encode_qp( ssi::variable_substitution( \$email_template, \%order ) );
	@sales_order = ( "Order$order_id.html", $_, 'text/html', 'quoted-printable' );
	my @project_dockets = ();

	$log->debug("***************** ADDING PROJECT DOCKET *************************");
	foreach my $project (@projects) {
		my %variable;
		$variable{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
		$variable{'siteURL'} = $r->dir_config('ExternalSiteURL');
		$variable{'SiteTitle'} = $r->dir_config('SiteTitle');
		openprint::print_project::summary( $r, $log, $dbh, \%variable, $project );
		$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_docket_sheet.html' );
		if ( $_ ) {
			$_ = ssi::variable_substitution( \$_, \%variable );
			$_ = encode_qp( $_ );
			push @project_dockets, "ProjectDocket$project.html", $_, 'text/html', 'quoted-printable';
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
				FROM	=> $order{'txtEmail'},
				#FROM	=> $config{'OrderingEmail'},
				TO		=> join(',',@admin_emails),
				SUBJECT => "Order $order_id",
				);
		misc::send_email_with_attachment( $log, \%mail, @body, @sales_order, @project_summaries, @project_dockets );
	} # end if
	
} # end sub order_send_email

sub history {
	my ( $r, $log, $dbh, $variable ) = @_;

} # end sub history

sub get_misc {
	my ( $log, $dbh, $variable, $order_id ) = @_;

	$$variable{'Order'} = new openprint::Order( $order_id );

	$log->debug("********* START OF Get Misc **************");

	$_ = q{SELECT curDownpayment, curTotalSale, curFedTax, curHarmTax, curProvTax, strFirstName || ' ' || strLastName,to_char(dtmOrderDate, 'MM/DD/YYYY'), strStatus, CurrencyIndex, strPoNumber, strAdministratorComments, strAdministratorName FROM Orders WHERE Index=?};
	@$variable{'Downpayment','TOTAL', 'GST', 'HST', 'PST', 'ORDERED_BY', 'CreationDate', 'ORDER_STATUS', 'CurrencyIndex', 'PONUM','AdministratorComments','AdministratorName'} = sql::execute( $log, $dbh, $_, $order_id );

	my $Currency = new openprint::Currency( $$variable{'CurrencyIndex'} );
	@$variable{'CurrencyName','CurrencySymbol'} = ($Currency->name(), $Currency->symbol() );
	$$variable{'Currency'} = $Currency;

	$$variable{'AmountPaid'} = $$variable{'Order'}->paid();
	if ( $$variable{'ORDER_STATUS'} ne 'Cancelled' ) {
		$$variable{'AmountOutstanding'} = sprintf( "%.2f", $$variable{'TOTAL'} - $$variable{'AmountPaid'} );
		$$variable{'DepositDue'} = sprintf( "%.2f", $$variable{'Downpayment'} - $$variable{'AmountPaid'} ) if $$variable{'AmountPaid'} < $$variable{'Downpayment'};
	} # end if

	$$variable{'AmountPaid'} = sprintf( '%.2f', $$variable{'AmountPaid'} );
} # end sub get_misc

sub get_projects {
	my ( $log, $dbh, $variable, $order_id ) = @_;

	my $Order = new openprint::Order( $order_id );
	@{$$variable{'Projects'}} = $Order->Projects();
} # end sub get_projects

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

        openprint::order::get_misc( $log, $dbh, $variable, $order_id );

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
		get_invoice_to( $log, $dbh, $variable, $order_id );
		get_misc( $log, $dbh, $variable, $order_id );
		get_projects( $log, $dbh, $variable, $order_id );
		$$variable{'CCITYPROVCOUNTRY'} = misc::build_city_prov_country(@$variable{'txtCity','txtStateProvince','txtCountry'} );
		$$variable{'OrderID'} = $order_id;
	} # end if
} # end sub display_order

# duplicates the given order.	returns the id of the newly created order
sub make_order_from_order {
	my ( $log, $dbh, $cookie, $src_order_id, $variable ) = @_;

	my $SRC_Order = new openprint::Order( $src_order_id );
	return if check_credit( $log, $dbh, $variable, $SRC_Order->total() );

	if ( $SRC_Order->status() eq '' ) {
		return misc::error( 'Can\'t re-order.', 'Order does not exist.' );
	} elsif ( ! sets::isin( $SRC_Order->status(), 'Complete', 'Paid',	'Shipped', 'Waiting For Pickup', 'Picked Up' ) ) {
		return misc::error( 'Can\'t re-order.', 'The given order is not complete.' );
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
	@{$$variable{'Projects'}} = $Order->projects();

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
		@info{'txtEmail','txtTitle','txtFirstName','txtLastName','rdbSalutation','txtPhone','txtExt', 'txtFax'} = $User->get('email','title','firstname','lastname','salutation','phone','extension','fax');
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
