package openprint::project;

use strict;

require sql;
require openprint::Project;
require openprint::Estimating::Printing;
#require XML::DOM;

sub get_project_type {
	my ( $log, $dbh, $project_index ) = @_;
	my $Project = new openprint::Project( $project_index );
	my $ProjectType = $Project->Type();
	return $ProjectType->strid();
} # end sub

sub get_project_type_service_index {
	my ( $log, $dbh, $project_index ) = @_;
	$_ = 'SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?';
	( $_ ) = sql::execute( $log, $dbh, $_, $project_index, 'ProjectType' );
	return $_;
} # end sub

sub get_quantities {
	my ( $log, $dbh, $project_index) = @_;
	my $Project = new openprint::Project( $project_index );
	return ( $Project->quantity1(), $Project->quantity2(), $Project->quantity3() );
} # end sub get_quantities

sub get_header {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	$$variable{'Project'} = new openprint::Project( $project_index );
	$_ = q{SELECT order_id, lngDocketNumber, strProjectReference, strComments, to_char(dtmCreationDate, 'MM/DD/YYYY'), strStatus, intQuantity1, intQuantity2, intQuantity3,Currency_id, strDesign, CompanyIndex, UserIndex, to_char(due_date,'MM/DD/YYYY'), to_char(due_date, 'Day Mon DD/YYYY')  FROM tbl_Projects WHERE Index=?};
	@$variable{'order_id','DocketNumber','ProjectReference', 'Comments', 'CreationDate','ProjectStatus','Quantity1','Quantity2','Quantity3','currency_id','ddmDesign','company_id','user_id','DueDate','RequiredDateAlternate'} = sql::execute( $log, $dbh, $_, $project_index );

	my $Company = new openprint::Company( $$variable{'company_id'} );
	$$variable{'Company'} = $Company;
	$$variable{'CompanyName'} = $Company->name();

	my $User = new openprint::User( $$variable{'user_id'} );

	@$variable{'CreatedByName','CreatedByPhone','CreatedByEmail'} = ( $User->name(), $User->phone(), $User->email() );
	my $CSR = new openprint::User( $Company->salesrep_id() );

   @$variable{'CSRName','CSREmail','CustomerServiceRep'} = ( $CSR->name(), $CSR->email(), $CSR->name() );

	if ( $$variable{'order_id'} ) {
		$_ = q{SELECT intQuantity, intQuantityIndex, to_char(dateRequired, 'MM/DD/YYYY'), ShippingType FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?};
		@$variable{'OrderedQuantity','OrderedQuantityIndex','RequiredDate','ShippingType'} = sql::execute( $log, $dbh, $_, $$variable{'order_id'}, $project_index );
		$_ = q{SELECT strPONumber, to_char(dtmOrderDate, 'MM/DD/YYYY') FROM Orders WHERE Index=?};
		@$variable{'PONum','OrderedDate'} = sql::execute( $log, $dbh, $_, $$variable{'order_id'} );
	my $Order = new openprint::Order( $$variable{'order_id'} );
	@$variable{'OrderSalutation','OrderFirstName','OrderLastName','OrderPhone','OrderExtension'} = ( $Order->salutation(), $Order->first_name(), $Order->last_name(), $Order->phone(), $Order->extension() );
	} # end fi

} # end sub get_header

sub view {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	if ( exists $openprint::param{'ShowAllSignatures'} ) {
		$openprint::session{'ShowAllSignatures'} = $openprint::param{'ShowAllSignatures'};
	} # end if
$openprint::log->debug("Viewing Project $project_index");
	get_header( $log, $dbh, $variable, $project_index );

	my %project;
	foreach my $service_index ( sql::execute( $log, $dbh, q{SELECT lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $project_index ) ) {
		my %s = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $service_index );
		$project{$service_index} = \%s;
	} # end foreach $serviceindex
	my %statuses = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $project_index );

# THis is the currency that prices are displayed in
	my $Currency = openprint::Currency::get_current();
	my $ProjectCurrency = $$variable{'Project'}->Currency();
	my $conversion_rate = $ProjectCurrency->conversions( $Currency->id() );

	my $ProjectType = $$variable{'Project'}->Type();

# now do printing service
	$$variable{'ProjectTypeName'} = $ProjectType->name();
	my @services = ();

	my %services = $$variable{'Project'}->get_services();
# Put Printing service first is list of things to display
	foreach my $s_id ( @{$services{''}} ) {
		push @services, 'Printing', $ProjectType->url(), $s_id;
	} # end foreach

	$_ = q{SELECT name,description,strDetailedUrl FROM Service_Types WHERE view_visible=true ORDER BY Sorting};
	my @service_info = sql::execute( $log, $dbh, $_ );
# do a little sorting, adding services with a service type
	while ( my ($id, $n, $url ) = splice @service_info,0,3 ) {
		if ( $id eq 'AdditionalSignature' ) {
			while ( $services{$id} and @{$services{$id}} ) {
				my $service_index = shift @{$services{$id}};

				my $sig_qty = 1;

				if ( $openprint::session{'ShowAllSignatures'} ) {
					push @services, $n, $url, $service_index;
				} else {
					for ( my $i = 0; $i < @{$services{$id}}; $i += 1 ) {
						if ( openprint::Estimating::Printing::compare_signatures( $project{$service_index}, $project{$services{$id}[$i]} ) ) {
							$sig_qty += 1;
							$project{$service_index}{'txtPrice1'} += $project{$services{$id}[$i]}{'txtPrice1'};
							$project{$service_index}{'txtPrice2'} += $project{$services{$id}[$i]}{'txtPrice2'};
							$project{$service_index}{'txtPrice3'} += $project{$services{$id}[$i]}{'txtPrice3'};
							splice @{$services{$id}}, $i, 1;
							$i -= 1;
						} # end if
					} # end for
					if ( $sig_qty > 1 ) {
						push @services, $sig_qty . ' ' . $n.'s', $url, $service_index;
						$$variable{'HiddenSignatures'} = 1;
					} else {
						push @services, $sig_qty . ' ' . $n, $url, $service_index;
					} # end if
				} # end if
				
			} # end foreach
		} else {
		
		foreach my $service_index ( @{$services{$id}} ) {
			if ( $n eq 'Outside Service' ) {
				push @services, $project{$service_index}{'ServiceName'}, $url, $service_index;
			} else {
				push @services, $n, $url, $service_index;
			} # end if
		} # end foreach
		} # end if
	} # end while

	while ( @services ) {
		my ( $name, $url, $service_index ) = splice @services, 0, 3;


		push @{$$variable{'SERVICES'}}, $service_index, $name, $url;

		foreach my $qty_index ( 1 .. 3 ) {
			my $price = $project{$service_index}{"txtPrice$qty_index"};
			if ( $price eq '' and $$variable{"Quantity$qty_index"} ) {
				$price = $project{$service_index}{'txtPrice1'};
			} # end if
			$$variable{"Total$qty_index"} += $price;
			$$variable{"UnitPrice$qty_index"} += $price/$$variable{"Quantity$qty_index"} if $$variable{"Quantity$qty_index"};
			push @{$$variable{'SERVICES'}}, sprintf( $openprint::config{'ProjectMoneyFormat'}, $price * $conversion_rate );
		} # end foreach qty_index

		push @{$$variable{'SERVICES'}}, $statuses{$service_index};
	} # end foreach

	if ( 
			( $$variable{'Project'}->price1() != $$variable{'Total1'} ) or 
			( $$variable{'Project'}->price2() != $$variable{'Total2'} ) or 
			( $$variable{'Project'}->price3() != $$variable{'Total3'} ) 
	   ) {

		$$variable{'Project'}->price1( $$variable{'Total1'} );
		$$variable{'Project'}->price2( $$variable{'Total2'} );
		$$variable{'Project'}->price3( $$variable{'Total3'} );
		$$variable{'Project'}->save();
	} # end if
	foreach my $qty_index ( 1 .. 3 ) {
		$$variable{"Total$qty_index"} = sprintf($openprint::config{'ProjectMoneyFormat'}, $$variable{"Total$qty_index"}*$conversion_rate );
		$$variable{"UnitPrice$qty_index"} = sprintf( '%.2f', $$variable{"UnitPrice$qty_index"}*$conversion_rate );
	} # end foreach

	@$variable{'CurrencyName', 'CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
	$$variable{'ProjectIndex'} = $project_index;
	$$variable{'OrderID'} = $$variable{'order_id'};
} # end sub view

# This is sortof a state engine.	This function should update a project's status to whatever it should be.
sub update_status {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	return $Project->update_status( $variable );
} # end sub update_project_status

sub get_log {
	my ( $log, $dbh, $project_id ) = @_;

	$_ = q{SELECT Company_id, (SELECT strName FROM Company WHERE Index=Company_ID),
		User_Id, (SELECT strFirstName || ' ' || strLastName FROM Users
		WHERE Index=User_Id), to_char(dtmTimestamp,'HH12:MIpm MM/DD/YYYY'), Description FROM Project_Log WHERE Project_Id=? ORDER BY dtmTimestamp};
	return sql::execute( $log, $dbh, $_, $project_id );
} # end sub get_log

sub insert_into_log {
	my ( $log, $dbh, $cust_id, $user_id, $project_id, $text ) = @_;
	my $Project = new openprint::Project( $project_id );
	$Project->add_to_log( $cust_id, $user_id, $text );
} # end sub insert_into_log

sub get_prepress_operator {
    my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
    my %services = $Project->get_services();
    my $User = new openprint::User( sql::execute( $log, $dbh, q{SELECT operator_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, ( $services{'Proofs'} ? $services{'Proofs'}[0] : $services{'FilmStripping'}[0] ) ) );
    return $User->name();
} # end sub get_prepressoperator

1;

__END__
~		
