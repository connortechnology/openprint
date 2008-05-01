package openprint::print_project;

use openprint ();

use strict;

require sql;
require openprint::main_account;
require openprint::service;
require openprint::ServiceType;
require openprint::ProjectType;
require openprint::Project;
require openprint::Currency;
require openprint::User;
require openprint::ServiceType;
require openprint::logs;
require openprint::Estimating::Multipage;

# Projects are like Orders, in that you can have several in here, but only ONE of them may be unfinished.

sub delete_project {
	my ( $log, $dbh, $project_id ) = @_;
	sql::update( $log, $dbh, 'tbl_Projects', ['Index=?', $project_id], ['strStatus', 'Deleted'] );
	openprint::logs::insertLogRecord('20', "Project ID: " . $project_id,);
} # end sub delete_project

sub insert_project_type {
	my ( $r, $log, $dbh, $project_index, $project_type_id ) = @_;

	my ( $project_type_index ) = sql::execute( $log, $dbh, q{SELECT lngIndex FROM Project_Types WHERE strID=?}, $project_type_id );
	if ( $project_type_index ) {

		# Make this all one transaction...
		my $ac = sql::start_transaction( $dbh );

		sql::insert( $log, $dbh, 'tbl_Project_Contents', [
			'lngProjectIndex',	$project_index,
			'strStatus',	'uncalculated' ] );
		$_ = q{SELECT MAX(lngServiceIndex) FROM tbl_Project_Contents WHERE lngProjectIndex=?};
		my ( $service_index ) = sql::execute( $log, $dbh, $_, $project_index );
		sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
			'lngProjectIndex',	$project_index,
			'lngServiceIndex',	$service_index,
			'strName',			'ProjectType',
			'strValue',		 $project_type_id
			] );
		$_ = q{SELECT strFieldName, strDefaultValue FROM tbl_ProjectType_Defaults WHERE lngProjectTypeIndex IS NULL};
		my @defaults = sql::execute( $log, $dbh, $_ );
		$_ = q{SELECT strFieldName, strDefaultValue FROM tbl_ProjectType_Defaults WHERE lngProjectTypeIndex=?};
		push @defaults, sql::execute( $log, $dbh, $_, $project_type_index );
		
		if ( $r->param('txtConventionalPlates') == 1 ) {
			push @defaults, 'rdbPlates','Conventional';
		} else {
			push @defaults, 'rdbPlates','CTP';
		} # end if

		push @defaults, 'SignatureIndex', '0';
		my %defaults = @defaults;
		foreach my $key ( keys %defaults ) {
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, $key, $defaults{$key}, 1 );
		} # end while
		my @quantities = openprint::project::get_quantities( $log, $dbh, $project_index );
		foreach my $index ( 1 .. 3 ) {
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, "txtQuantity$index", $quantities[$index-1], 1 );
		} # end foreach
		sql::end_transaction( $dbh,  $ac );
		my $Project = new openprint::Project( $project_index );
		delete $$Project{'Services'};
		delete $$Project{'signatures'};
		return $service_index;
	} else {
		$log->error( "Couldn't get project index for $project_type_id" );
	} # end if
} # end sub insert_project_type

sub add_service {
# THis is an external wrapper for insert_service
	my ( $r, $log, $dbh, $variable, $project_index, @services ) = @_;
	foreach my $service_id ( @services ) {
		insert_service( $log, $dbh, $project_index, $service_id );
	} # end foreach
} # end sub add_service

sub insert_service {
	my ( $log, $dbh, $project_index, $service_id ) = @_;
	my $service_index = 0;
	
	my $ServiceType;
	if ( ref $service_id ne 'openprint::ServiceType' ) {
		if ( my @ServiceTypes = openprint::ServiceType::find('name'=>$service_id) ) {
			$ServiceType = $ServiceTypes[0];
		} else {
			$log->warn("Service $service_id IS NOT in the system.");
			return;
		} # end if
	} else {
		$ServiceType = $service_id;
	} # end if
		
	# Make this all one transaction...
	my $ac = sql::start_transaction( $dbh );

	sql::insert( $log, $dbh, 'tbl_Project_Contents', 'lngProjectIndex',	$project_index, 'strStatus', 'uncalculated', 'servicetype_id', $ServiceType->id() );
	( $service_index ) = sql::execute( $log, $dbh, q{SELECT MAX(lngServiceIndex) FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $project_index );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'ServiceType', $ServiceType->name(), 1 );
	$_ = q{SELECT strFieldName, strDefaultValue FROM tbl_Service_Defaults WHERE lngServiceTypeIndex=? OR lngServiceTypeIndex IS NULL ORDER BY lngServiceTypeIndex};
	my @defaults = sql::execute( $log, $dbh, $_, $ServiceType->id() );
	while ( @defaults ) {
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, shift @defaults, shift @defaults, 1 );
	} # end while
	my @quantities = openprint::project::get_quantities( $log, $dbh, $project_index );
	foreach my $index ( 1 .. 3 ) {
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, "txtQuantity$index", $quantities[$index-1], 1 );
	} # end foreach

	sql::end_transaction( $dbh, $ac );
	my $Project = new openprint::Project( $project_index );
	delete $$Project{'Services'};
	delete $$Project{'signatures'};
	return $service_index;
} # end sub insert_service

sub create_edit_display {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $project_index = $openprint::param{'ProjectIndex'};

	my $Project = new openprint::Project( $project_index );

	@{$$variable{'ProjectTypes'}} = map { $_->strid(), $_->name() } openprint::ProjectType::find( 'order'=>'lngsort, lower(strname)' );
	# Check the appropriate button for project type
	@$variable{'SelectedProjectType'} = $Project->Type()->strid();

	@$variable{'txtProjectReference','ddmDesign','txtComments','txtQuantity1','txtQuantity2','txtQuantity3','rdbMode','chkPrograms','txtOtherPrograms'} = (
		$Project->reference(), $Project->design(), $Project->comments(), $Project->quantity1(), $Project->quantity2(), $Project->quantity3(), $Project->mode(), $Project->programs(), $Project->other_programs() 
	);

	my %services = $Project->get_services();
	@{$$variable{'SelectedServices'}} = keys %services;

	my $sql = q{SELECT name,description FROM Service_Types WHERE category=? AND create_visible=true ORDER BY Sorting, lower(name)};
	@{$$variable{'PrepressServiceTypes'}} = sql::execute( $log, $dbh, $sql, 'Prepress' );
	push @{$$variable{'PrepressServiceTypes'}}, sql::execute( $log, $dbh, $sql, 'Proofs' );

	@{$$variable{'BinderyServiceTypes'}} = sql::execute( $log, $dbh, $sql, 'Bindery' );
	@{$$variable{'SpecialtyServiceTypes'}} = sql::execute( $log, $dbh, $sql, 'Specialty' );
	@{$$variable{'PackagingServiceTypes'}} = sql::execute( $log, $dbh, $sql, 'Packaging' );
	@{$$variable{'ShippingServiceTypes'}} = sql::execute( $log, $dbh, $sql, 'Shipping' );

	$$variable{'ProjectIndex'} = $project_index;
} # end sub edit_stage1_display

sub get_incomplete_services_in_category {
	my ( $log, $dbh, $project_index, $category ) = @_;

	if ( $category eq 'Printing' ) {
		my $Project = new openprint::Project( $project_index );
		my %services = $Project->get_services();

		foreach my $index ( @{$services{'AdditionalSignature'}} ) {
			if ( openprint::service::get_status( $log, $dbh, $index ) ne 'calculated' ) {
				return $index;
			} # end if
		} # end foreach
		return;
	} else {

		my @products = sql::execute( $log, $dbh, 'SELECT name FROM Service_Types WHERE Category=?',$category );

		$_ = "SELECT MIN(lngServiceIndex) FROM tbl_Project_Contents\n".
			"WHERE lngProjectIndex='$project_index'\n".
			"AND lngServiceIndex IN ( ".
			"						SELECT lngServiceIndex FROM tbl_Service_Specifications ".
			"						WHERE lngProjectIndex='$project_index' AND strName='ServiceType' ".
			"						AND strValue IN ( '".join("','", @products). "'	) ) ".
			"AND strStatus == 'uncalculated'";
		return sql::execute( $log, $dbh, $_ );
	} # end if
} # end sub get_incomplete_services_in_category

sub get_redirect_for_service {
	my ( $log, $dbh, $project_index, $service_index ) = @_;

	my $ServiceType = new openprint::ServiceType( sql::execute( undef, undef, q{SELECT servicetype_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index ) );
	return '/main/project/'.$ServiceType->url();

} # end sub get_redirect_for_service

sub choose_service {
	my ( $log, $dbh, $project_index ) = @_;
	$log->debug("***************** TIME TO CHOOSE SERVICE ***********************");

	my @incomplete_services = sql::execute( $log, $dbh, "SELECT lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=? AND (strStatus IS NULL or strStatus ='uncalculated')", $project_index );
	if ( ! @incomplete_services ) {
		# Quick shortcut.	If there aren't any, then stop looking.
		$log->debug("***************** NO IMCOMPLETE SERVICES FOUND ***********************");
		return ( '', '' );
	} # end if
	# get the printing service
	$_ = "SELECT strValue, lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='ProjectType'";
	my ( $project_type_id, $service_index ) = sql::execute( $log, $dbh, $_, $project_index );

	my $status = openprint::service::get_status( $log, $dbh, $service_index );
	
	# if the printing service is unfinished, return it.
	# the no url test will only occurr for the "no printing required" project type :)
	if ( $status eq 'uncalculated' ) {
		$_ = "SELECT strDetailedURL FROM Project_Types WHERE strID=?";
		my ( $url ) = sql::execute( $log, $dbh, $_, $project_type_id );
		return ( $service_index, '/main/project/'.$url ) if $url ne '';
	} # end if

	$log->debug("****** GETTING INCOMPLETE PRINTING SERVICES ********");
	foreach $service_index ( get_incomplete_services_in_category( $log, $dbh, $project_index, 'Printing' ) ) {
		$log->debug("****** SERVICE: $service_index is incomplete ********");
		my $url = get_redirect_for_service( $log, $dbh, $project_index, $service_index );
		return ( $service_index, $url ) if $url ne '';
	} # end while
	$log->debug("****** FOUND NO INCOMPLETE PRINTING SERVICES ********");
	
	$_ = "SELECT strValue, lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=?".
		" AND strName='ServiceType' AND strValue != 'AdditionalSignature' AND lngServiceIndex IN (".join(',',@incomplete_services).")";
	my @project_services = sql::execute( $log, $dbh, $_, $project_index );

	$_ = "SELECT name, strDetailedUrl FROM Service_Types WHERE strDetailedUrl != '' ORDER BY sorting";
	my @service_info = sql::execute( $log, $dbh, $_ );

	while ( @service_info ) {
		my $index = shift @service_info;
		my $url = shift @service_info;
		for (my $x = 0; $x < @project_services; $x += 2 ) {
			if ( $project_services[$x] eq $index ) {
				return ( $project_services[$x+1], '/main/project/'.$url );
			} # end if	
		} # end for
	} # end while

	return ( '', '' );
} # end sub choose_service

# What the hell does this function do?
# As far as I can tell, it get's called if the ContinueProject param is Y, or if someone hits the continue project button on project view.	What it does is pick an uncalculated service using choose_service, and that's about it.	Just a little glue to hold things together.	Unfortunately the glue is ugly, and I'm not sure why it's needed.	It might not be needed anymore.
# The glue basiscally makes it look like someone clicked on the service link on the project view page, so it sets params ProjectIndex,and ServiceIndex, and sets the redirect.
sub continue_project {
	my ( $log, $dbh, $variable, $project_index ) = @_;
	my $incoming_service_index = $openprint::param{'ServiceIndex'};
			
	$log->info(" ************* STARTING continue_project **************** " );

	if ( $$variable{'Redirect'} eq '' ) {
		$project_index = get_unfinished_project( $log, $dbh, undef ) if ! $project_index;

		my ( $service_index, $redirect ) = choose_service( $log, $dbh, $project_index );
		# pick the next unfinished service.

		if ( ! $service_index ) {
			my $Project = new openprint::Project( $project_index );
			foreach my $qty_index ( 1 .. 3 ) {
				next if ! $Project->quantity($qty_index);
				if ( $_ = openprint::Estimating::Multipage::status( $project_index, undef, $qty_index ) ) {
					my @sigs = $Project->signatures($_);
					my $src_id = pop @sigs;
					my $src_specs = openprint::service::get_specs_ref( $Project, $src_id );
					$service_index = openprint::Estimating::Multipage::copy_signature( $project_index, $src_specs );
					( $service_index, $redirect ) = choose_service( $log, $dbh, $project_index );
					last;
				} # end if
			} # end foreach
		} # end if

		if ( $redirect ne '' and $service_index != $incoming_service_index ) {
			#plugin new service.
			$$variable{'Redirect'} = $redirect;

			$$variable{'ServiceIndex'} = $service_index;
			$openprint::param{'ServiceIndex'} = $service_index;
		} # end if

		$$variable{'ProjectIndex'} = $project_index;
	} # end if

	$log->debug("********************* END PROJECT CONTINUE REDIRECT IS $$variable{'Redirect'} $$variable{'ProjectIndex'} $$variable{'ServiceIndex'} *************************");
} # end sub continue_project 

sub try_to_delete_project {
	my ( $log, $dbh, $variable, $project_index ) = @_;
	my $error = '';
	my $delete = 1;

	my $Project = new openprint::Project( $project_index );
	my $proj_reference = $Project->reference();

	if ( $Project->company_id() != $openprint::session{'company_id'} ) {
		$error .= "Project $proj_reference does not belong to you.	Not deleted.<br>";
		$delete = 0;
	} # end if
	$_ = "SELECT Orders.Index FROM Orders,Order_Contents WHERE Orders.Index=Order_Contents.OrderIndex AND lngProjectIndex=? AND Orders.strStatus != 'Incomplete'";
	( $_ ) = sql::execute( $log, $dbh, $_, $project_index );
	if ( $_ ) {
		$error .= "Project $proj_reference is in order <a href=\"/main/order/history_details.html?order_id=$_\">$_</a>.	You must delete the order before you can delete the project.<br>";
		$delete = 0;
	} # end if
	$_ = "SELECT tbl_Quotes.Index FROM tbl_Quotes,tbl_Quote_Details WHERE tbl_Quotes.Index=tbl_Quote_Details.QuoteIndex AND ProjectIndex=? AND tbl_Quotes.strStatus != 'Incomplete'";
	( $_ ) = sql::execute( $log, $dbh, $_, $project_index );
	if ( $_ ) {
		$error .= "Project $proj_reference is in quote <a href=\"/main/quote/history_details.html?quote_id=$_\">$_</a>.	You must delete the quote before you can delete the project.<br>";
		$delete = 0;
	} # end if
	if ( $delete ) {
		$Project->delete();
	} # end if
	return $error;
} # end sub try_to_delete_project

sub history_list {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $error = '';
	foreach my $key ( $r->param() ) {
		if ( $key =~ /chkDelete(\d*)/ ) {
			$error = try_to_delete_project( $log, $dbh, $variable, $1 );
		} elsif ( $key eq 'btnFunction' and $r->param($key) eq 'Delete Project' ) {
			$error = try_to_delete_project( $log, $dbh, $variable, $r->param('ProjectIndex') );
		} # end if
	} # end foreach

	if ( $error ne '' ) {
		return misc::error( $log, $dbh, $variable, 'Error',$error );
	} # end if

} # end sub history_list 

sub view_pdfs {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $project_index = $r->param('ProjectIndex');
	$_ = "SELECT strFileName, strDescription FROM tbl_Project_PDFs WHERE lngProjectIndex=?";
	@{$$variable{'PDFS'}} = sql::execute( $log, $dbh, $_, $project_index );

	$$variable{'ProjectIndex'} = $project_index;
} # end sub view_pdfs

# Returns an array of pairs (ServiceIndex, ProductIndex)
sub get_services_in_category {
	my ( $log, $dbh, $project_index, $category) = @_;
	my @services;

	if ( $category eq 'Printing' ) {
#The entire point of this is to sort the signature groups
		if ( my @ServiceTypes = openprint::ServiceType::find('name'=>'AdditionalSignature') ) {
			$_ = "SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName = 'txtSignatureType' AND strValue IN ('Interior Spreads','GateFolded Spreads','Cover Spreads') ORDER BY lngServiceIndex";
			my @signatures = sql::execute( $log, $dbh, $_, $project_index );
			
			while ( @signatures ) {
				push @services, shift @signatures, $ServiceTypes[0];
			} # end while
		} # end if
	} else { 
		$_ = "SELECT lngServiceIndex, id FROM tbl_Service_Specifications, Service_Types WHERE lngProjectIndex=?
			  AND tbl_Service_Specifications.strName='ServiceType'
			  AND strValue IN ( SELECT name FROM Service_Types WHERE category = ? )
			  AND strValue = name
			  ORDER BY sorting";
		@services = sql::execute( $log, $dbh, $_, $project_index, $category );
	} # end if
	return @services;
} # end sub get_services_in_category

sub summary {
	my ( $r, $log, $dbh, $variable, $project_index ) = @_;
	my ( @services );

	$log->debug("************************* START OF PROJECT SUMMARY **********************************");

	$project_index = $r->param('ProjectIndex') if ! $project_index;
	return if ! $project_index;

	my $order_id = $r->param('Order_Id');

	openprint::project::get_header( $log, $dbh, $variable, $project_index, $order_id );
	$$variable{'OrderId'} = $order_id;
	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();
	$$variable{'Services'} = \%services;

	if ( $services{''} ) {
		my $ProjectType = $Project->Type();
		# print service comes first
		@$variable{'ProjectTypeName','ProjectTypeURL'} = ( $ProjectType->name(), $ProjectType->url() );

		@services = ( $services{''}[0], 'Printing', $$variable{'ProjectTypeURL'} );

		#@{$$variable{$project_type_id}} = ( $service_index );
		openprint::print_project::get_service_specifications( $r, $log, $dbh, $variable, $project_index, $services{''}[0] );
	} # end if
	
   push @services, sql::execute( $log, $dbh, q{SELECT lngServiceIndex, name, strdetailedurl FROM tbl_Project_Contents, Service_Types WHERE servicetype_id=Service_Types.id AND lngProjectIndex=? AND view_visible=true AND servicetype_id IS NOT NULL ORDER BY sorting,lngServiceIndex}, $project_index );

   while ( @services ) {
        my ( $service_index, $name, $url ) = splice @services,0,3;
        push @{$$variable{'SERVICES'}}, $service_index, $name, $url;
    } # end while

	$$variable{'TOTAL1'} = sprintf( '%.2f', $Project->price1() );
	$$variable{'TOTAL2'} = sprintf( '%.2f', $Project->price2() );
	$$variable{'TOTAL3'} = sprintf( '%.2f', $Project->price3() );

	$$variable{'UNITPRICE1'} = $$variable{'txtQuantity1'} ? sprintf( "%.2f", $$variable{'TOTAL1'}/$$variable{'txtQuantity1'} ) : '0.00';
	$$variable{'UNITPRICE2'} = $$variable{'txtQuantity2'} ? sprintf( "%.2f", $$variable{'TOTAL2'}/$$variable{'txtQuantity2'} ) : '0.00';
	$$variable{'UNITPRICE3'} = $$variable{'txtQuantity3'} ? sprintf( "%.2f", $$variable{'TOTAL3'}/$$variable{'txtQuantity3'} ) : '0.00';

	openprint::print::get_quantities( $variable, $project_index);

	$$variable{'ProjectIndex'} = $project_index;
	$$variable{'NoPriceBreakDown'} = $r->param('NoPriceBreakDown');

	@{$$variable{'PrintingServices'}} = $Project->signatures();
	# new stuff

	$$variable{'ProofServiceIndex'}	= $services{'Proofs'} ? $services{'Proofs'}[0] : $services{'FilmStripping'}[0];

	if ( my %services = get_services_in_category( $log, $dbh, $project_index, 'Bindery') ) {
		$_ = "SELECT description FROM Service_Types WHERE id IN ( '" . join("','", @services{keys %services} ) . "') ORDER BY sorting";
		$$variable{'BinderyServices'} = join(',', sql::execute( $log, $dbh, $_ ));
	} # end if

	if ( my %services = get_services_in_category( $log, $dbh, $project_index, 'Packaging') ) {
		$_ = "SELECT description FROM Service_Types WHERE id IN ( '" . join("','", @services{keys %services} ) . "') ORDER BY sorting";
		$$variable{'PackagingServices'} = join(',', sql::execute( $log, $dbh, $_ ));
	} # end if

	my $Currency = openprint::Currency::get_current();
	if ( $Currency ) {
		@$variable{'CurrencyName', 'CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
	} # end if
} # end sub summary

sub get_proof_colours {
# this function is used for summary pages in employee and admin sections.
	my ( $r, $log, $dbh, $variable, $project_index, $service_index, $proof_index ) = @_;

	$$variable{'chkProcessColourSideOne'} = '';
	$$variable{'chkProcessColourSideTwo'} = '';
	$$variable{'chkBlackColourSideOne'} = '';
	$$variable{'chkBlackColourSideTwo'} = '';

	$_ = 'SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=? AND strValue=?';
	my ($index) = sql::execute( undef, undef, $_, $project_index, 'SignatureIndex',$proof_index );

	my %specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $index );
	foreach my $key ( keys %specs ) {
		if ( $key =~ /Colour/ and $specs{$key} =~ /Black/ ) {
			$$variable{$key} = $specs{$key};
		} # end if
	} # end foreach
} # end sub


sub get_service_specifications {
# this function is used for summary pages in employee and admin sections.
	my ( $r, $log, $dbh, $variable, $project_index, $service_index ) = @_;

	if ( $project_index and $service_index ) {
		$$variable{'txtServiceDescription'} = '';
		$$variable{'ddmRunStyle'} = '';
		$$variable{'ServiceName'} = '';

		$$variable{'chkVarnishOverallGlossSideOne'} = '';
		$$variable{'chkVarnishOverallMatteSideOne'} = '';
		$$variable{'chkVarnishSpotGlossSideOne'} = '';
		$$variable{'chkVarnishSpotMatteSideOne'} = '';
		$$variable{'chkVarnishDryTrapSideOne'} = '';

		$$variable{'chkVarnishOverallGlossSideTwo'} = '';
		$$variable{'chkVarnishOverallMatteSideTwo'} = '';
		$$variable{'chkVarnishSpotGlossSideTwo'} = '';
		$$variable{'chkVarnishSpotMatteSideTwo'} = '';
		$$variable{'chkVarnishDryTrapSideTwo'} = '';

		$$variable{'chkBlackSideOne'} = '';
		$$variable{'chkBlackSideTwo'} = '';
		$$variable{'chkProcessColourSideOne'} = '';
		$$variable{'chkProcessColourSideTwo'} = '';
		$$variable{'chkSpecialColourSideOne'} = '';
		$$variable{'chkSpecialColourSideTwo'} = '';

		# Get the Product Index
		my ( $service_type_id ) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'ServiceType' );

		if ( ! $service_type_id ) {
# Maybe it's a project type
			@$variable{'ServiceTypeID','ServiceTypeName'} = openprint::print::get_project_type( $log, $dbh, $project_index );
			$$variable{'ServiceTypeName'} = 'Printing';
		} else {
			$$variable{'ServiceType'} = openprint::print::get_ServiceType( $project_index, $service_index );	
			@$variable{'ServiceTypeID','ServiceTypeName'} = ( $$variable{'ServiceType'}->name(), $$variable{'ServiceType'}->description() ) if $$variable{'ServiceType'};
		} # end if

		# Do Specific Stuff
		if ( $service_type_id eq 'Perforating' ) {
			my $specs = openprint::service::get_specs_ref( $project_index, $service_index );
			foreach my $name ( keys %$specs ) {
				$$variable{$name} = $$specs{$name};
			} # end foreach
			require openprint::Estimating::Perforating;
			openprint::Estimating::Perforating::get_specs( $log, $dbh, $variable, $project_index, $service_index );
		} elsif ( $service_type_id eq 'Scoring' ) {
			my $specs = openprint::service::get_specs_ref( $project_index, $service_index );
			foreach my $name ( keys %$specs ) {
				$$variable{$name} = $$specs{$name};
			} # end foreach
			require openprint::Estimating::Scoring;
			openprint::Estimating::Scoring::get_specs( $log, $dbh, $variable, $project_index, $service_index );
		} elsif ( $service_type_id eq 'Proofs' ) {
			my $specs = openprint::service::get_specs_ref( $project_index, $service_index );
			foreach ( keys %$specs ) {
				$$variable{$_} = $$specs{$_};
			} # end foreach
			openprint::Estimating::Proofs::get_proof_specs( $log, $dbh, $variable, $project_index, $service_index );
		} elsif ( $service_type_id ) {
			my $specs = openprint::service::get_specs_ref( $project_index, $service_index );
			foreach ( keys %$specs ) {
				$$variable{$_} = $$specs{$_};
			} # end foreach
		} else {
			my $specs = openprint::service::get_specs_ref( $project_index, $service_index );
			my $side_one_colours = 0;
			my $side_two_colours = 0;
			foreach my $name ( keys %$specs ) {
				#$log->debug("Setting: $name:($value)");
				$$variable{$name} = $$specs{$name};
				if ( $name =~ /ProcessColourSideOne/ ) {
					$side_one_colours += 4 if $$specs{$name};
				} elsif ( $name =~ /chkBlackSideOne/ or $name =~/txtSpecialSideOneColour\d/ ) {
					$side_one_colours++ if $$specs{$name};
				} elsif ( $name =~ /ProcessColourSideTwo/ ) {
					$side_two_colours += 4 if $$specs{$name};;
				} elsif ( $name =~ /chkBlackSideTwo/ or $name =~/txtSpecialSideTwoColour\d/ ) {
					$side_two_colours++ if $$specs{$name};;
				} # end if
			} # end while
			$$variable{'SideOneColours'} = $side_one_colours;
			$$variable{'SideTwoColours'} = $side_two_colours;

			$$variable{"hdnPaperTotal1"} = sprintf("%.2f",$$variable{"hdnPaperTotal1"});
			$$variable{"hdnPaperTotal2"} = sprintf("%.2f",$$variable{"hdnPaperTotal2"});
			$$variable{"hdnPaperTotal3"} = sprintf("%.2f",$$variable{"hdnPaperTotal3"});
		} # end if
		$$variable{'ServiceTypeName'} = $$variable{'ServiceName'} if $$variable{'ServiceName'} ne '';

		$$variable{'ProjectIndex'} = $project_index;
	} else {
		$log->debug(" *********** PROBLEM HERE Project Index: $project_index AND Service Index: $service_index **********************");
	} # end if
} # End sub get_service_specifications

sub create_edit_process {
	my ( $r, $log, $dbh, $variable ) = @_;

	$openprint::param{'txtQuantity1'} =~ s/\D//g;
	$openprint::param{'txtQuantity2'} =~ s/\D//g;
	$openprint::param{'txtQuantity3'} =~ s/\D//g;

	my $error = '';
	my ( $ref ) = misc::trim( $r->param('txtProjectReference') );
	$error .= "You must specify a Project Reference.<br/>" if ! $ref =~ /[^\s]/;
	$error .= "No quantities specified.<br/>" if $r->param('txtQuantity1') eq '' and $r->param('txtQuantity2') eq '' and $r->param('txtQuantity3') eq '';
	$error .= "Invalid Quantity 1.<br/>" if $r->param('txtQuantity1') and ! int $r->param('txtQuantity1');
	$error .= "Invalid Quantity 2.<br/>" if $r->param('txtQuantity2') and ! int $r->param('txtQuantity2');
	$error .= "Invalid Quantity 3.<br/>" if $r->param('txtQuantity3') and ! int $r->param('txtQuantity3');
	if ( $error ne '' ) {
		$$variable{'Redirect'} = '/main/project/create_edit.html';
		$$variable{'error'} = 'Fields not complete';
		$$variable{'details'} = $error;
		foreach ( $r->param() ) {
			$$variable{$_} = $r->param($_);
		} # end foreach
        return;
    } # end if

	my $Project = new openprint::Project( int $openprint::param{'ProjectIndex'} );
	$Project->save() if ( ! $Project->id() );
	$openprint::session{'project_id'} = $Project->id();
	my $project_index = $Project->id();

	my %services = $Project->get_services();
	my @service_ids;
	foreach my $stype ( keys %services ) {
		foreach my $s_id ( @{$services{$stype}} ) {
			push @service_ids, $s_id;
		} # end foreach
	} # end foreach

	if ( $openprint::param{'txtQuantity1'} != $Project->quantity1() ) {
		if ( ! $Project->quantity1() ) {
			if ( $Project->quantity2() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project->id(), $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( $key =~ /(.*)2$/ and ! $key =~ /Special/ ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $1.'1', $$specs{$key} );
						} # end if
					} # end foreach
				} # end if
			} elsif ( $Project->quantity3() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project->id(), $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( $key =~ /(.*)3$/ and ! $key =~ /Special/ ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $1.'1', $$specs{$key} );
						} # end if
					} # end foreach
				} # end if
			} # end if Project 2 or 3
		} elsif ( ! $openprint::param{'txtQuantity1'} ) { # Project has a quantity, we are deleting it
			foreach my $service_id ( @service_ids ) {
				foreach my $spec ( 'txtPrice1','txtUnitPrice1','txtQuantity1' ) {
					openprint::service::delete_service_spec( $project_index, $service_id, $spec );
				} # end foreach
			} # end foreach
		} # end if
		foreach my $service_id ( @service_ids ) {
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_id, 'txtQuantity1', int $openprint::param{'txtQuantity1'} );
		} # end foreach
		$Project->quantity1( int $openprint::param{'txtQuantity1'} );
	} # end if
	if ( $openprint::param{'txtQuantity2'} != $Project->quantity2() ) {
		if ( ! $Project->quantity2() ) {
			if ( $Project->quantity1() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project->id(), $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( $key =~ /(.*)1$/ and ! $key =~ /Special/ ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $1.'2', $$specs{$key} );
						} # end if
					} # end foreach
				} # end if
			} elsif ( $Project->quantity3() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project->id(), $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( $key =~ /(.*)3$/ and ! $key =~ /Special/ ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $1.'2', $$specs{$key} );
						} # end if
					} # end foreach
				} # end if
			} # end if Project 2 or 3
		} elsif ( ! $openprint::param{'txtQuantity2'} ) {
			foreach my $service_id ( @service_ids ) {
				foreach my $spec ( 'txtPrice2','txtUnitPrice2','txtQuantity2' ) {
					openprint::service::delete_service_spec( $project_index, $service_id, $spec );
				} # end foreach
			} # end foreach
		} # end if
		foreach my $service_id ( @service_ids ) {
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_id, 'txtQuantity2', int $openprint::param{'txtQuantity2'} );
		} # end foreach
		$Project->quantity2( int $openprint::param{'txtQuantity2'} );
	} # end if
	if ( $openprint::param{'txtQuantity3'} != $Project->quantity3() ) {
		if ( ! $Project->quantity3() ) {
			if ( $Project->quantity1() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project->id(), $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( $key =~ /(.*)1$/ and ! $key =~ /Special/ ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $1.'3', $$specs{$key} );
						} # end if
					} # end foreach
				} # end if
			} elsif ( $Project->quantity2() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project->id(), $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( $key =~ /(.*)2$/ and ! $key =~ /Special/ ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $1.'3', $$specs{$key} );
						} # end if
					} # end foreach
				} # end if
			} # end if Project 2 or 3
		} elsif ( ! $openprint::param{'txtQuantity3'} ) {
			foreach my $service_id ( @service_ids ) {
				foreach my $spec ( 'txtPrice3','txtUnitPrice3','txtQuantity3' ) {
					openprint::service::delete_service_spec( $project_index, $service_id, $spec );
				} # end foreach
			} # end foreach
		} # end if
		foreach my $service_id ( @service_ids ) {
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_id, 'txtQuantity3', int $openprint::param{'txtQuantity3'} );
		} # end foreach
		$Project->quantity3( int $openprint::param{'txtQuantity3'} );
	} # end if

	# Because we do some low-level crappy stuff, we need to clear the caches, cuz they are stale
	openprint::service::init_cache();

	my @project_types = openprint::ProjectType::find( 'strid' => $openprint::param{'rdbProjectType'} );
	my $ProjectType = shift @project_types;
	my $OldProjectType = $Project->Type();

	$Project->reference( $ref );
	$Project->comments( $r->param('txtComments') );
	$Project->mode( $r->param('rdbMode') );
	$Project->design( $r->param('ddmDesign') );
	$Project->programs( $r->param('chkPrograms') );
	$Project->other_programs( $r->param('txtOtherPrograms') );
	$Project->currency_id( $openprint::session{'Currency_id'} ) if ! $Project->currency_id();

# Handle ProjectType
	if ( $OldProjectType->strid() ne $ProjectType->strid() ) {
		if ( $services{''} ) {
			foreach ( @{$services{''}} ) { delete_service( $log, $dbh, $Project->id(), $_ ); };
		} # end if
		delete $services{''};
		$Project->Type( $ProjectType );
	} # end if
	if ( ! $services{''} ) {
		my $printing_service_index = insert_project_type( $r, $log, $dbh, $Project->id(), $r->param('rdbProjectType') );
		push @{$services{''}}, $printing_service_index;
	} # end if
	$Project->save();

	# take care of the Graphic Design service
	if ( $r->param('rdbGraphicDesign') eq 'Y' ) {
		push @{$services{'GraphicDesign'}}, insert_service( $log, $dbh, $project_index, 'GraphicDesign') if ! $services{'GraphicDesign'};
	} # end if

	push @{$services{'Proofs'}}, insert_service( $log, $dbh, $project_index, 'Proofs') if ! $services{'Proofs'};

	my %statuses = sql::execute( $log, $dbh, 'SELECT lngserviceindex, strstatus FROM tbl_Project_Contents WHERE lngprojectindex=?', $project_index );

	foreach my $ServiceType ( openprint::ServiceType::find( 'create_visible'=>'Y') ) {
		if ( $openprint::param{'chkServices'.$ServiceType->name()} eq $ServiceType->name() ) {
			if ( ! $services{$ServiceType->name()} ) {	
				push @{$services{$ServiceType->name()}}, insert_service( $log, $dbh, $Project->id(), $ServiceType->name() ) if ! $services{$ServiceType->name() };
			} # end if
		} else {
			if ( $services{$ServiceType->name()} ) {
				foreach my $s_id ( @{$services{$ServiceType->name()}} ) {
					if ( $statuses{$s_id} ne 'Completed' ) {
						delete_service( $log, $dbh, $Project->id(), $s_id );
					} # end if
				} # end foreach
				delete $services{$ServiceType->name()};
			} # end if
		} # end if
	} # end foreach

	$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Edited' );
	return $Project->id();
} # end sub create_edit_process

sub del_service {
	# THis is an external wrapper 
	my ( $r, $log, $dbh, $variable, $project_index, $service_id ) = @_;
	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();
	if ( $services{$service_id} ) {
		foreach my $service_index ( @{$services{$service_id}} ) {
			delete_service( $log, $dbh, $project_index, $service_index );
		} # end foreach
	} # end if
} # end sub del_service

sub delete_service {
	my ( $log, $dbh, $project_index, $service_index ) = @_;
	my $ac = sql::start_transaction( $dbh );
	sql::execute( $log, $dbh, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index );
	sql::execute( $log, $dbh, q{DELETE FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index );
	my $Project = new openprint::Project( $project_index );
	delete $$Project{'Services'};
	delete $$Project{'signatures'};
	sql::end_transaction( $dbh, $ac );
	#openprint::logs::insertLogRecord('10', "Service Index: " . $service_index . " for Project Index: " . $project_index,);
} # end sub delete_service

sub display_reuse_project {
	my ( $r, $log, $dbh, $variable ) = @_;

	$$variable{'ProjectIndex'} = $openprint::param{'ProjectIndex'};
	$$variable{'Project'} = new openprint::Project( $openprint::param{'ProjectIndex'} );
	
} # end sub

sub reuse_project {
	my ( $r, $log, $dbh, $cookie, $variable, $project_index ) = @_;

	$openprint::param{'quantity1'} =~ s/\D//g;
	$openprint::param{'quantity2'} =~ s/\D//g;
	$openprint::param{'quantity3'} =~ s/\D//g;
	@openprint::param{'reference','comments'} = misc::trim( @openprint::param{'reference','comments'} );

	my $Project = new openprint::Project( $project_index );
	my $NewProject = $Project->copy();
	$NewProject->quantity1( $openprint::param{'quantity1'} );
	$NewProject->quantity2( $openprint::param{'quantity2'} );
	$NewProject->quantity3( $openprint::param{'quantity3'} );
	$NewProject->reference( $openprint::param{'reference'} );
	$NewProject->comments( $openprint::param{'comments'} );
	$NewProject->docket( '' );
	$NewProject->due_date( '' );
	$NewProject->user_id( $openprint::session{'user_id'} );
	$NewProject->order_id( '' );
	# This allows uncalc->uncalc, everything else to UnOrdered
	if ( sets::isin( $Project->status(), [ 'Pending Deposit', 'In Prepress', 'Proofs Out', 'Approved', 'Printed', 'Complete' ] ) ) {
		$NewProject->status('Unordered');
	} # end if
	$NewProject->company_id( $r->param('ddmCompany') ) if $r->param('ddmCompany');
	$NewProject->save();

	$NewProject->add_to_log( @openprint::session{'company_id','user_id'}, 'Reused from project '.$Project->id() );
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Reused to project '.$NewProject->id() );

	if ( $r->param('ddmCompany') and $r->param('ddmCompany') != $openprint::session{'company_id'} ) {
		openprint::main_account::select_company( $r, $log, $dbh, $cookie, $variable ) if sets::isin( $openprint::session{'user_type'}, ['A','E'] );
	} # end if


	my @dont_copy = (
			'ServiceIndex','ProjectIndex','TemplateType',
			'txtEmployeeComments','rdbComplete','rdbApproved','ddmApprovalDateMonth','ddmApprovalDateDay','ddmApprovalDateYear',
			'ddmCompletionDate.*','txtRunHours','txtDowntimeHours',
			'ddmPressCompletionDate.*',	'UsePress.*', 'rdbPressComplete.*',
			'UsedPaper.*',
			'txtMakeReadySetupHours', 'txtStartQuantity','txtFinalQuantity','txtWasteQuantity','txtEmployeeName',
			);

	# Make this all one transaction... Don't need locking because a reload would get a different projectindex
	my $ac = sql::start_transaction( $dbh );

	my @contents = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, servicetype_id, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $Project->id() );
			
	while ( @contents ) {
		my ( $service_index, $servicetype_id, $status ) = splice @contents, 0, 3;

		# uncalc->uncalc,	*->calc
		if ( $status ne '' and sets::isin( $status, [ 'Pending Deposit', 'Ordered', 'Proofs Out', 'Approved', 'Complete' ] ) ) {
			$status = 'calculated';
		} # end if

		my ( $new_service_index ) = sql::execute( $log, $dbh, q{SELECT nextval('ContentsServiceIndex_seq')} );
		sql::insert( $log, $dbh, 'tbl_Project_Contents',[
				'lngProjectIndex',	$NewProject->id(),
				'lngServiceIndex', $new_service_index,
				'servicetype_id',   $servicetype_id,
				'strStatus',	$status
				] );
		openprint::service::insert_service_spec( $log, $dbh, $NewProject->id(), $new_service_index, 'ProjectIndex', $NewProject->id(), 1 );
		openprint::service::insert_service_spec( $log, $dbh, $NewProject->id(), $new_service_index, 'ServiceIndex', $new_service_index, 1 );

		my $specs = openprint::service::get_specs_ref( $Project->id(), $service_index );
		foreach my $key ( keys %$specs ) {
			if ( ! sets::isin_regx( $key, @dont_copy ) ) {
				openprint::service::insert_service_spec( $log, $dbh, $NewProject->id(), $new_service_index, $key, $$specs{$key}, 1 );
			} # end if
		} # end foreach
		if ( $Project->quantity1() != $NewProject->quantity1() ) {
			openprint::service::insert_service_spec( $log, $dbh, $NewProject->id(), $new_service_index, 'txtQuantity1', $NewProject->quantity1() );
		} # end if
		if ( $Project->quantity2() != $NewProject->quantity2() ) {
			openprint::service::insert_service_spec( $log, $dbh, $NewProject->id(), $new_service_index, 'txtQuantity2', $NewProject->quantity2() );
		} # end if
		if ( $Project->quantity3() != $NewProject->quantity3() ) {
			openprint::service::insert_service_spec( $log, $dbh, $NewProject->id(), $new_service_index, 'txtQuantity3', $NewProject->quantity3() );
		} # end if

	} # end while
	sql::end_transaction( $dbh, $ac );
	if ( $Project->quantity1() != $NewProject->quantity1()
			or $Project->quantity2() != $NewProject->quantity2()
			or $Project->quantity3() != $NewProject->quantity3() ) {
		foreach my $signature_service_id ( $NewProject->signatures() ) {
			my $sig_specs = openprint::service::internal_calc( $log, $dbh, $variable, $NewProject->id(), $signature_service_id,'Printing' );
		} # end foreach
		openprint::service::auto_calculate( $r, $log, $dbh, $variable, $NewProject->id(), undef );
	} # endif
	return $NewProject->id();
} # end sub reuse_project

my @no_outputs = (
	'txtShippingPostalCode',
	'txtHoleQty','UPSShipping','HoleDrilling',
	'Aqueous','txtTotalPageQuantity','Colours',
	'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight',
	'txtHoleSize', 
	'rdbAqueousSideOne','rdbAqueousSideTwo',
	'chkProcessColourSideOne', 'chkProcessColourSideTwo',
	'TemplateType','PrintingType','FoldType','Dimensions','Turnaround',
	# Presentation Folders
	'rdbPanels','rdbPocketSize','chkPocketLeft','chkPocketRight',
	'txtQuantity1',
	'chkOverrideScoreQty',
);

# creates a new project, first clearing out any previous projects
sub calc {
	my ( $r, $log, $dbh, $variable, %specs ) = @_;

# FIrst thing: Normalize the inputs
	$specs{'Help'} = '';
	$specs{'alert'} = '';
	$specs{'txtQuantity1'} =~ s/\D//g;

	my @project_types = openprint::ProjectType::find( 'strid' => $specs{'ProjectType'} );
	return if ! @project_types;
	my $ProjectType = shift @project_types;

	my $project = new openprint::Project( $specs{'ProjectIndex'} );
	$project->Currency( openprint::Currency::get_current() );
	$project->type_id( $ProjectType->id() );
	if ( $specs{'txtQuantity1'} != $project->quantity1() ) {
		sql::update( $log, $dbh, 'tbl_service_specifications', ['lngprojectindex=? and strName=?', $project->id(), 'txtQuantity1'], 'strvalue', $specs{'txtQuantity1'} );
	} # end if
	$project->quantity1( $specs{'txtQuantity1'} );
	
	$project->mode( 'Simple' );
	$project->design( 'ElectronicFile' );
	$project->save();

	my $services = $project->services();
	push @{$$services{'Cutting'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'Cutting' ) if ! $$services{'Cutting'};

	if ( $$project{'id'} ) {
		$openprint::session{'project_id'} = $project->id();
		$specs{'ProjectIndex'} = $$project{'id'};

		my $printing_service_index = openprint::project::get_project_type_service_index( $log, $dbh, $$project{'id'} );
		if ( ! $printing_service_index ) {
			$printing_service_index = openprint::print_project::insert_project_type( $r, $log, $dbh, $$project{'id'}, $specs{'ProjectType'} );
		} # end if

		my %printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $$project{'id'}, $printing_service_index );
		if ( $printing_specs{'ProjectType'} ne $specs{'ProjectType'} ) {
			openprint::print_project::delete_service( $log, $dbh, $$project{'id'}, $printing_service_index ) if $printing_service_index;
			$printing_service_index = openprint::print_project::insert_project_type( $r, $log, $dbh, $$project{'id'}, $specs{'ProjectType'} );
			%printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $$project{'id'}, $printing_service_index );
		} # end if

		if ( ! sets::isin( $specs{'Dimensions'}, ['', 'Custom'] ) ) {
			my ( $width, $height, $type ) = $specs{'Dimensions'} =~ /([\d\.]*)x([\d\.]*)(\w*)/;
			my @args = ( $specs{'ProjectType'}, $width, $height );

			if ( $type eq 'Flat' ) {
				$_ = q{SELECT dblfinishedwidth::float, dblfinishedheight::float FROM projecttemplate WHERE projecttype_id = (SELECT lngIndex FROM project_types where strid=?) AND dblFlatWidth=? AND dblFlatHeight=?};
				if ( $specs{'FoldType'} ) {
					$_ .= q{ AND type=?};
					push @args, $specs{'FoldType'};
				} # end if
				@specs{'txtFinalWidth','txtFinalHeight'} = sql::execute( $log, $dbh, $_, @args );
				@specs{'txtWidth','txtHeight'} = ($width, $height);
				if ( ! $specs{'txtFinalWidth'} ) {
					if ( ( my ( $pages, $folds ) = $specs{'FoldType'} =~ /^(\d+)pg(\d)Panel/ ) ) {
						$specs{'txtFinalWidth'} = sprintf('%.3f', int($specs{'txtWidth'} * 1000 / $folds)/1000 );
						$specs{'txtFinalHeight'} = $specs{'txtHeight'} / (($pages/2)/$folds);
					} elsif ( ( my ( $folds ) = $specs{'FoldType'} =~ /^(\d)Panel/ ) ) {
						#$folds =~ s/\D//g;
						#$folds += 1;
						$specs{'txtFinalWidth'} = sprintf('%.3f', int($specs{'txtWidth'} *1000/ $folds)/1000 );
						$specs{'txtFinalHeight'} = $specs{'txtHeight'};
					} # end if
				} # end if
			} else {
				$_ = q{SELECT dblFlatWidth::float, dblFlatHeight::float FROM projecttemplate WHERE projecttype_id = (SELECT lngIndex FROM project_types where strid=?) AND dblFinishedWidth=? AND dblFinishedHeight=?};
				if ( $specs{'FoldType'} ) {
					$_ .= q{ AND type=?};
					push @args, $specs{'FoldType'};
				} # end if
				@specs{'txtWidth','txtHeight'} = sql::execute( $log, $dbh, $_, @args );
				@specs{'txtFinalWidth','txtFinalHeight'} = ($width, $height);
				if ( ! $specs{'txtWidth'} ) {
					my $folds = $specs{'FoldType'};
					$folds =~ s/\D//g;
					$folds += 1;
					$specs{'txtWidth'} = $specs{'txtFinalWidth'} * $folds;
					$specs{'txtHeight'} = $specs{'txtFinalHeight'};
				} # end if
			} # end if
		} else {
			$specs{'txtWidth'} =~ s/[^\.\d]//g;
			$specs{'txtFinalWidth'} =~ s/[^\.\d]//g;
			$specs{'txtHeight'} =~ s/[^\.\d]//g;
			$specs{'txtFinalHeight'} =~ s/[^\.\d]//g;
		} # end if
		if ( ! ( $specs{'txtWidth'} and $specs{'txtHeight'} and $specs{'txtFinalWidth'} and $specs{'txtFinalHeight'} ) ) {
			$specs{'alert'} .= 'No dimensions found for this fold type.';
			$specs{'Status'} = 'uncalculated';
			return jsrs::encode_pairs(%specs);
		} elsif ( ! $specs{'txtQuantity1'} ) {
			$specs{'alert'} .= 'Please enter the quantity.';
			$specs{'Status'} = 'uncalculated';
			return jsrs::encode_pairs(%specs);
		} # end if

		if ( exists $specs{'txtTotalPageQuantity'} ) {
			if ( ! $specs{'txtTotalPageQuantity'} ) {
				$specs{'alert'} .= 'Please enter the number of pages.<br/>';
				$specs{'Status'} = 'uncalculated';
				return jsrs::encode_pairs(%specs);
			} # end if
			if ( $specs{'rdbCover'} eq 'Different' ) {
				if ( ! $specs{'ddmStockBrandCoverSpreads'} ) {
					$specs{'alert'} .= 'Please select Cover Stock Brand<br/>';
					$specs{'Status'} = 'uncalculated';
					return jsrs::encode_pairs(%specs);
				} # end if
				if ( ! $specs{'ddmStockFinishCoverSpreads'} ) {
					$specs{'alert'} .= 'Please select Cover Stock Finish<br/>';
					$specs{'Status'} = 'uncalculated';
					return jsrs::encode_pairs(%specs);
				} # end if
				if ( ! $specs{'ddmStockColourCoverSpreads'} ) {
					$specs{'alert'} .= 'Please select Cover Stock Colour<br/>';
					$specs{'Status'} = 'uncalculated';
					return jsrs::encode_pairs(%specs);
				} # end if
				if ( ! $specs{'ddmStockWeightCoverSpreads'} ) {
					$specs{'alert'} .= 'Please select Cover Stock Weight<br/>';
					$specs{'Status'} = 'uncalculated';
					return jsrs::encode_pairs(%specs);
				} # end if
			} # end if
			if ( ! $specs{'ddmStockBrandInteriorSpreads'} ) {
                    $specs{'alert'} .= 'Please select Interior Stock Brand<br/>';
                    $specs{'Status'} = 'uncalculated';
                    return jsrs::encode_pairs(%specs);
                } # end if
                if ( ! $specs{'ddmStockFinishInteriorSpreads'} ) {
                    $specs{'alert'} .= 'Please select Interior Stock Finish<br/>';
                    $specs{'Status'} = 'uncalculated';
                    return jsrs::encode_pairs(%specs);
                } # end if
                if ( ! $specs{'ddmStockColourInteriorSpreads'} ) {
                    $specs{'alert'} .= 'Please select Interior Stock Colour<br/>';
                    $specs{'Status'} = 'uncalculated';
                    return jsrs::encode_pairs(%specs);
                } # end if
                if ( ! $specs{'ddmStockWeightInteriorSpreads'} ) {
                    $specs{'alert'} .= 'Please select Interior Stock Weight<br/>';
                    $specs{'Status'} = 'uncalculated';
                    return jsrs::encode_pairs(%specs);
                } # end if

				if ( $specs{'rdbTemplateType'} eq 'SaddleStitching' and $specs{'txtTotalPageQuantity'} % 4 ) {
                    $specs{'alert'} .= '# of pages should be a multiple of 4<br/>';
                    $specs{'Status'} = 'uncalculated';
                    return jsrs::encode_pairs(%specs);
				} elsif ( $specs{'rdbTemplateType'} eq 'PerfectBound' and $specs{'txtTotalPageQuantity'} % 2 ) {
                    $specs{'alert'} .= '# of pages should be a multiple of 2<br/>';
                    $specs{'Status'} = 'uncalculated';
                    return jsrs::encode_pairs(%specs);
				} # end if

# It's a multi-page publication
			my $ac = sql::start_transaction( $dbh );
			foreach my $spec ( 'txtWidth','txtHeight','txtFinalWidth','txtFinalHeight','txtTotalPageQuantity','rdbCover','rdbTemplateType','PrintingType' ) {
				if ( $printing_specs{$spec} ne $specs{$spec} ) {
					openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $printing_service_index, $spec, $specs{$spec} );
					$printing_specs{$spec} = $specs{$spec};
				} # end if
			} # end foreach
			sql::end_transaction( $dbh, $ac );
			openprint::service::internal_calc( $log, $dbh, $variable, $$project{'id'}, $printing_service_index, 'Multipage' );

			if ( $specs{'Colours'} eq '4/4' ) {
				$specs{'chkBlackSideOneInteriorSpreads'} = undef;
				$specs{'chkBlackSideTwoInteriorSpreads'} = undef;
				$specs{'chkProcessColourSideOneInteriorSpreads'} = 'ProcessColour';
				$specs{'chkProcessColourSideTwoInteriorSpreads'} = 'ProcessColour';
			} elsif ( $specs{'Colours'} eq '4/0' ) {
				$specs{'chkBlackSideOneInteriorSpreads'} = undef;
				$specs{'chkBlackSideTwoInteriorSpreads'} = undef;
				$specs{'chkProcessColourSideOneInteriorSpreads'} = 'ProcessColour';
				$specs{'chkProcessColourSideTwoInteriorSpreads'} = '';
			} elsif ( $specs{'Colours'} eq '4/1' ) {
				$specs{'chkBlackSideOneInteriorSpreads'} = undef;
				$specs{'chkBlackSideTwoInteriorSpreads'} = 'Black';
				$specs{'chkProcessColourSideOneInteriorSpreads'} = 'ProcessColour';
				$specs{'chkProcessColourSideTwoInteriorSpreads'} = undef;
			} elsif ( $specs{'Colours'} eq '1/1' ) {
				$specs{'chkBlackSideOneInteriorSpreads'} = 'Black';
				$specs{'chkBlackSideTwoInteriorSpreads'} = 'Black';
				$specs{'chkProcessColourSideOneInteriorSpreads'} = undef;
				$specs{'chkProcessColourSideTwoInteriorSpreads'} = undef;
			} # end if
			@specs{'rdbAqueousSideOneInteriorSpreads','rdbAqueousSideTwoInteriorSpreads'} = @specs{'InteriorSpreadsAqueous','InteriorSpreadsAqueous'};

			if ( $specs{'rdbCover'} eq 'Different' ) {
				if ( $specs{'ColoursCover'} eq '4/4' ) {
					$specs{'chkBlackSideOneCoverSpreads'} = undef;
					$specs{'chkBlackSideTwoCoverSpreads'} = undef;
					$specs{'chkProcessColourSideOneCoverSpreads'} = 'ProcessColour';
					$specs{'chkProcessColourSideTwoCoverSpreads'} = 'ProcessColour';
				} elsif ( $specs{'ColoursCover'} eq '4/0' ) {
					$specs{'chkBlackSideOneCoverSpreads'} = undef;
					$specs{'chkBlackSideTwoCoverSpreads'} = undef;
					$specs{'chkProcessColourSideOneCoverSpreads'} = 'ProcessColour';
					$specs{'chkProcessColourSideTwoCoverSpreads'} = undef;
				} elsif ( $specs{'ColoursCover'} eq '4/1' ) {
					$specs{'chkBlackSideOneCoverSpreads'} = undef;
					$specs{'chkBlackSideTwoCoverSpreads'} = 'Black';
					$specs{'chkProcessColourSideOneCoverSpreads'} = 'ProcessColour';
					$specs{'chkProcessColourSideTwoCoverSpreads'} = undef;
				} # end if
			@specs{'rdbAqueousSideOneCoverSpreads','rdbAqueousSideTwoCoverSpreads'} = @specs{'CoverSpreadsAqueous','CoverSpreadsAqueous'};
			} # end if
# The adding of signatures will be done automatically by multipage signatures
# This will add bindery services, and a printing service
			$specs{'Status'} = openprint::print::multipage_signatures( \%specs, $log, $dbh, $variable, $$project{'id'}, $printing_service_index );
		} else {
# Non-book

			if ( $specs{'Colours'} eq '4/4' ) {
				$specs{'chkBlackSideOne'} = undef;
				$specs{'chkBlackSideTwo'} = undef;
				$specs{'chkProcessColourSideOne'} = 'ProcessColour';
				$specs{'chkProcessColourSideTwo'} = 'ProcessColour';
			} elsif ( $specs{'Colours'} eq '4/0' ) {
				$specs{'chkBlackSideOne'} = undef;
				$specs{'chkBlackSideTwo'} = undef;
				$specs{'chkProcessColourSideOne'} = 'ProcessColour';
				$specs{'chkProcessColourSideTwo'} = '';
			} elsif ( $specs{'Colours'} eq '4/1' ) {
				$specs{'chkBlackSideOne'} = undef;
				$specs{'chkBlackSideTwo'} = 'Black';
				$specs{'chkProcessColourSideOne'} = 'ProcessColour';
				$specs{'chkProcessColourSideTwo'} = undef;
			} elsif ( $specs{'Colours'} eq '1/1' ) {
				$specs{'chkBlackSideOne'} = 'Black';
				$specs{'chkBlackSideTwo'} = 'Black';
				$specs{'chkProcessColourSideOne'} = undef;
				$specs{'chkProcessColourSideTwo'} = undef;
			} # end if
			if ( ! $specs{'ddmStockBrand'} ) {
				$specs{'alert'} .= 'Please select Stock Brand<br/>';
				$specs{'Status'} = 'uncalculated';
				return jsrs::encode_pairs(%specs);
			} # end if
			if ( ! $specs{'ddmStockFinish'} ) {
				$specs{'alert'} .= 'Please select Stock Finish<br/>';
				$specs{'Status'} = 'uncalculated';
				return jsrs::encode_pairs(%specs);
			} # end if
			if ( ! $specs{'ddmStockColour'} ) {
				$specs{'alert'} .= 'Please select Stock Colour<br/>';
				$specs{'Status'} = 'uncalculated';
				return jsrs::encode_pairs(%specs);
			} # end if
			if ( ! $specs{'ddmStockWeight'} ) {
				$specs{'alert'} .= 'Please select Stock Weight<br/>';
				$specs{'Status'} = 'uncalculated';
				return jsrs::encode_pairs(%specs);
			} # end if

			openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $$services{''}[0], 'SideOneUVCoatingType', $specs{'SideOneCoatingType'} );
			openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $$services{''}[0], 'SideTwoUVCoatingType', $specs{'SideTwoCoatingType'} );
			if ( 
					( $specs{'SideOneCoatingType'} and ( $specs{'SideOneCoatingType'} ne 'None' ) ) or
					( $specs{'SideTwoCoatingType'} and ( $specs{'SideTwoCoatingType'} ne 'None' ) ) 
			   ) {
				if ( ! $$services{'UVCoating'} ) {
					push @{$$services{'UVCoating'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'UVCoating' );
				} # end if
			} elsif ( $$services{'UVCoating'} ) {
				foreach ( @{$$services{'UVCoating'}} ) {
					openprint::print_project::delete_service( $log, $dbh, $$project{'id'}, $_ );
				} # end foreach
			} # end if


			@specs{'rdbAqueousSideOne','rdbAqueousSideTwo'} = @specs{'Aqueous','Aqueous'};
			my $ac = sql::start_transaction( $dbh );
			foreach my $spec ( 'txtWidth','txtHeight','txtFinalWidth','txtFinalHeight', 'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight','txtQuantity1','chkProcessColourSideOne','chkProcessColourSideTwo','chkBlackSideOne','chkBlackSideTwo','rdbAqueousSideOne','rdbAqueousSideTwo','PageQuantity' ) {
				if ( $printing_specs{$spec} ne $specs{$spec} ) {
					openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $printing_service_index, $spec, $specs{$spec} );
					$printing_specs{$spec} = $specs{$spec};
				} # end if
			} # end foreach
			if ( $specs{'PrintingType'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $printing_service_index, 'PrintingType1', $specs{'PrintingType'} );
				openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $printing_service_index, 'chkOverridePrintingType1', 'Y' );
			} else {
				openprint::service::delete_service_spec( $$project{'id'}, $printing_service_index, 'chkOverridePrintingType1' );
			} # end if
			if ( $specs{'ProjectType'} eq 'PresentationFolders' ) {
				foreach my $spec ( 'rdbPanels','rdbPocketSize','chkPocketLeft','chkPocketRight','chkPocketCenter' ) {
					if ( $printing_specs{$spec} ne $specs{$spec} ) {
						openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $printing_service_index, $spec, $specs{$spec} );
						$printing_specs{$spec} = $specs{$spec};
					} # end if
				} # end foreach
			} else {
				openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $printing_service_index, 'rdbTemplateType', $specs{'FoldType'} );
			} # end if
			sql::end_transaction( $dbh, $ac );
			my $sig_specs = openprint::service::internal_calc( $log, $dbh, $variable, $$project{'id'}, $printing_service_index, 'Printing' );
			@specs{'txtWidth','txtHeight','chkPocketCenter','Status','alert'} = @$sig_specs{'txtWidth','txtHeight','chkPocketCenter','Status','alert'};
			%printing_specs = %{$sig_specs};
		} # end if printing

		if ( $specs{'Status'} eq 'uncalculated' ) {
			$specs{'alert'} .= 'Problem calculating printing';
			return jsrs::encode_pairs(%specs);
		} # end if

		# Force a reload
		$services = $project->services();

		$log->debug("Adding Required Services");
		foreach my $servicetype_id ( sql::execute( $log, $dbh, q{SELECT (SELECT name FROM Service_Types WHERE id = servicetype_id ) FROM projecttype_requiredservices WHERE projecttype_id = ?}, $project->type_id() ) ) {
			if ( ! $$services{$servicetype_id} ) {
				push @{$$services{$servicetype_id}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, $servicetype_id );
			} # end if
		} # end foreach

		# Force a reload
		$services = $project->services();

		push @{$$services{'Proofs'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'Proofs' ) if ! $$services{'Proofs'};

		if ( openprint::Estimating::Folding::neccessary( $log, $dbh, $$project{'id'} ) ) {
$openprint::log->error('Adding Folding');
			push @{$$services{'Folding'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'Folding' ) if ! $$services{'Folding'};
			if ( (exists $specs{'FoldType'}) and ((! $specs{'FoldType'} ) or ( $specs{'FoldType'} eq 'NoFold' )) ) {
				$specs{'alert'} .= 'It appears that your project needs folding, but you have not selected the fold type.<br/>';
				$specs{'Status'} = 'uncalculated';
			} # end if
		} elsif ( $$services{'Folding'} ) {
			foreach ( @{$$services{'Folding'}} ) {
$openprint::log->debug('Deleting Folding');
				openprint::print_project::delete_service( $log, $dbh, $$project{'id'}, $_ );
			} # end foreach
			delete $$services{'Folding'};
		} # end if

		if ( $specs{'HoleDrilling'} eq 'Y' ) {
			push @{$$services{'Drilling'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'Drilling' ) if ! $$services{'Drilling'};
			my $ac = sql::start_transaction( $dbh );
			foreach my $sid ( @{$$services{'Drilling'}} ) {
				foreach my $spec ( 'txtHoleQty','txtHoleSize' ) {
					if ( $specs{$spec} ne '' ) {
						openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $sid, $spec, $specs{$spec} ) 
					} else {
						@no_outputs = sets::exclude( [$spec], \@no_outputs );
					} # end if
				} # end foreach
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} elsif ( $$services{'Drilling'} ) {
			foreach ( @{$$services{'Drilling'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$project{'id'}, $_ );
			} # end if
			delete $$services{'Drilling'};
		} # end if

		if ( ($specs{'Scoring'} ne 'Y') and openprint::Estimating::Scoring::neccessary( $project ) ) {
			$specs{'Scoring'} = 'Y';
		} # end if

		if ( $specs{'Scoring'} eq 'Y' ) {
			if ( ! $$services{'Scoring'} ) {
				push @{$$services{'Scoring'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'Scoring' );
			} # end if
			my $scoring_specs = openprint::service::get_specs_ref( $project, $$services{'Scoring'}[0] );
			my @sigs = $project->signatures();
			my $sig_specs = openprint::service::get_specs_ref( $project, $sigs[0] );

			# Preload auto-calc # of scores, so we can determine if we need to override
			openprint::Estimating::Scoring::get_scores( $project, $scoring_specs, $sig_specs );

			foreach my $sid ( @{$$services{'Scoring'}} ) {
				if ( ! ( $specs{'chkOverrideScoreQty'} or $$scoring_specs{"txtVerticalQty-$$sig_specs{SignatureIndex}"} or $$scoring_specs{"txtHorizontalQty-$$sig_specs{SignatureIndex}"} ) ) {
					$specs{'chkOverrideScoreQty'} = 'Y';
					$specs{'txtScoreQty'} = 1;
				} # end if
				openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $sid, "chkOverrideQty-$$sig_specs{SignatureIndex}", $specs{'chkOverrideScoreQty'} );
				if ( $specs{'chkOverrideScoreQty'} eq 'Y' ) {
					openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $sid, "txtVerticalQty-$$sig_specs{SignatureIndex}", $specs{'txtScoreQty'} );
					openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $sid, "txtHorizontalQty-$$sig_specs{SignatureIndex}", 0 );
				} # end if
			} # end foreach
		} else {
			foreach ( @{$$services{'Scoring'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$project{'id'}, $_ );
			} # end foreach
			delete $$services{'Scoring'};
		} # end if

		if ( $specs{'Perfing'} eq 'Y' ) {
			push @{$$services{'Perforating'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'Perforating' ) if ! $$services{'Perforating'};
			foreach my $sid ( @{$$services{'Perforating'}} ) {
				openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $sid, 'txtVerticalQty-0', $specs{'txtPerfQty'} );
				openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $sid, 'chkOverrideQty-0', 'Y' );
			} # end foreach
		} else {
			foreach ( @{$$services{'Perforating'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$project{'id'}, $_ );
			} # end foreach
			delete $$services{'Perforating'};
		} # end if


# Handle cartons
		push @{$$services{'PlainCartons'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'PlainCartons' ) if ! $$services{'PlainCartons'};
		if ( $specs{'UPSShipping'} eq 'Y' ) {
			push @{$$services{'UPS'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'UPS' ) if ! $$services{'UPS'};
			my $ac = sql::start_transaction( $dbh );
			foreach my $sid ( @{$$services{'UPS'}} ) {
				foreach my $spec ( 'txtShippingPostalCode' ) {
					openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $sid, $spec, $specs{$spec} );
				} # end foreach
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} else {
			foreach my $sid ( @{$$services{'UPS'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$project{'id'}, $sid );
			} # end foreach
			delete $$services{'UPS'};
		} # end if

		push @{$$services{'Turnaround'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'Turnaround' ) if ! $$services{'Turnaround'};


		if ( $specs{'ShrinkWrapping'} eq 'Y' ) {
			if ( ! $$services{'ShrinkWrap'} ) {
				push @{$$services{'ShrinkWrap'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'ShrinkWrap' );
			} # end if
			openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $$services{'ShrinkWrap'}[0], 'txtItemsPerPackage', $specs{'txtItemsPerShrinkWrap'} );

		} else {
			foreach ( @{$$services{'ShrinkWrap'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$project{'id'}, $_ );
			} # end foreach
		} # end if

		if ( $specs{'Bundling'} eq 'Y' ) {
			if ( ! $$services{'Bundling'} ) {
				push @{$$services{'Bundling'}}, openprint::print_project::insert_service( $log, $dbh, $$project{'id'}, 'Bundling' );
			} # end if
			openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $$services{'Bundling'}[0], 'txtItemsPerPackage', $specs{'txtItemsPerBundle'} );

		} else {
			foreach ( @{$$services{'Bundling'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$project{'id'}, $_ );
			} # end foreach
		} # end if

		my $ac = sql::start_transaction( $dbh );
		foreach my $sid ( @{$$services{'Turnaround'}} ) {
			foreach my $spec ( 'TurnaroundDays' ) {
				openprint::service::insert_service_spec( $log, $dbh, $$project{'id'}, $sid, $spec, $specs{$spec} );
			} # end foreach
		} # end foreach
		sql::end_transaction( $dbh, $ac );
$openprint::log->warn("Before auto");
		$specs{'alert'} .= openprint::service::auto_calculate( $r, $log, $dbh, $variable, $$project{'id'} );
$openprint::log->warn("Aftere auto");

		if ( $$services{'Scoring'} ) {
			my $score_specs = openprint::service::get_specs_ref( $$project{'id'}, $$services{'Scoring'}[0] );
			if ( $specs{'chkOverrideScoreQty'} ne 'Y' ) {
				$specs{'txtScoreQty'} = 0;
				foreach my $ss_id ( $project->signatures() ) {
					my $sig_specs = openprint::service::get_specs_ref( $$project{'id'}, $ss_id );
					$specs{'txtScoreQty'} += $$score_specs{'txtVerticalQty-'.$$sig_specs{'SignatureIndex'}} + $$score_specs{'txtHorizontalQty-'.$$sig_specs{'SignatureIndex'}};
				} # end foreach
			} # end if
			if ( ! $specs{'txtScoreQty'} ) {
				$specs{'alert'} .= 'Please enter the # of scores.';
				$specs{'Status'} = 'uncalculated';
			} # end if
		} # end if
		if ( $$services{'Drilling'} ) {
			my $drill_specs = openprint::service::get_specs_ref( $$project{'id'}, $$services{'Drilling'}[0] );
			$specs{'txtHoleQty'} = $$drill_specs{'txtHoleQty'};
		} # end if

		$specs{'txtPrice1'} = 0;
		$specs{'txtUnitPrice1'} = 0;
# add up the prices
		if ( $specs{'Status'} ne 'uncalculated' ) {
			foreach my $service_index ( sql::execute( $log, $dbh, q{SELECT lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$project{'id'} ) ) {
				my $service_specs = openprint::service::get_specs_ref( $$project{'id'}, $service_index );
				$specs{'txtPrice1'} += $$service_specs{'txtPrice1'};	
			} # end foreach
		} # end if
		$specs{'txtPrice1'} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $specs{'txtPrice1'} );
		$specs{'txtUnitPrice1'} = sprintf( '%.2f', $specs{'txtPrice1'}/$specs{'txtQuantity1'} );	
		$project->price1( $specs{'txtPrice1'} );
		$project->save();

		my %printing_types;
		foreach my $ss_id ( $project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $project->id(), $ss_id );
			$printing_types{$$sig_specs{'PrintingType1'}} = 1;
		} # end foreach
		my @printing_types = keys %printing_types;
		if ( ! @printing_types ) {
		} elsif ( @printing_types == 1 ) {
			if ( $printing_types[0] eq 'Offset' ) {
				$specs{'alert'} .= 'This quote is for printing on an ' . join(',', keys %printing_types ) . ' press.<br/>';
			} else {
				$specs{'alert'} .= 'This quote is for printing on a ' . join(',', keys %printing_types ) . ' press.<br/>';
			} # end if
		} else {
			$specs{'alert'} .= 'This quote is for printing on ' . join(',', keys %printing_types ) . ' presses.<br/>';
		} # end if

	} # end if project_id
	foreach my $key ( @no_outputs ) {
		delete $specs{$key};
	} # end foreach

	$project->update_status( $variable );
	$specs{'Status'} = $project->status() if $specs{'Status'} ne 'uncalculated';
	return jsrs::encode_pairs(%specs);
} # end sub calc

sub create_calc {
	my ( $r, $log, $dbh, $variable, %specs ) = @_;
	my @results;

	return if ! $specs{'rdbProjectType'};

	my $Project = new openprint::Project( $specs{'ProjectIndex'} );
	$Project->currency_id( $openprint::session{'Currency_id'} ) if ! $Project->currency_id();
	if ( ! $Project->id() ) {
		$Project->save();
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Created' );
	} # end if

	my %services = $Project->get_services( );
	if ( $specs{'txtQuantity1'} != $Project->quantity1() ) {
		foreach my $service_id ( keys %services ) {
			foreach my $s_id ( @{$services{$service_id}} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtQuantity1', $specs{'txtQuantity1'} );
			} # end foreach
		} # end foreach
		$Project->quantity1( $specs{'txtQuantity1'} );
	} # end if
	if ( $specs{'txtQuantity2'} != $Project->quantity2() ) {
		foreach my $service_id ( keys %services ) {
			foreach my $s_id ( @{$services{$service_id}} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtQuantity2', $specs{'txtQuantity2'} );
			} # end foreach
		} # end foreach
		$Project->quantity2( $specs{'txtQuantity2'} );
	} # end if
	if ( $specs{'txtQuantity3'} != $Project->quantity3() ) {
		foreach my $service_id ( keys %services ) {
			foreach my $s_id ( @{$services{$service_id}} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtQuantity3', $specs{'txtQuantity3'} );
			} # end foreach
		} # end foreach
		$Project->quantity3( $specs{'txtQuantity3'} );
	} # end if

	my @project_types = openprint::ProjectType::find( 'strid' => $specs{'rdbProjectType'} );
	my $ProjectType = shift @project_types;
	if ( $Project->Type()->strid() ne $ProjectType->strid() ) {
		my @oldRequiredServiceTypes = $Project->Type()->required_ServiceTypes();
		my @newRequiredServiceTypes = $ProjectType->required_ServiceTypes();

# Remove no longer needed services
		foreach my $ServiceType ( @oldRequiredServiceTypes ) {
			if ( ! sets::isin( $ServiceType, \@newRequiredServiceTypes ) ) {
				foreach my $s_id ( @{$services{$ServiceType->name()}} ) {
					delete_service( $log, $dbh, $Project->id(), $s_id );
				} # end foreach
				delete $services{$ServiceType->name()};
			} # end if
		} # end foreach

# add needed services
		foreach my $ServiceType ( @newRequiredServiceTypes ) {
			if ( ! $services{$ServiceType->name()} ) {
				my $s_id = insert_service( $log, $dbh, $Project->id(), $ServiceType->name() );
				push @{$services{$ServiceType->name()}}, $s_id;
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtQuantity1', $specs{'txtQuantity1'} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtQuantity2', $specs{'txtQuantity2'} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtQuantity3', $specs{'txtQuantity3'} );
			} # endif
		} # end foreach
		if ( $services{''} ) {
			foreach ( @{$services{''}} ) {
				delete_service( $log, $dbh, $Project->id(), $_ );
			} # end foreach
		} # end if
		$Project->Type( $ProjectType );
		$Project->save();
	} # end if

	foreach my $ServiceType ( openprint::ServiceType::find( 'create_visible' => 'Y' ) ) {
		if ( $services{$ServiceType->name()} ) {
			push @results, 'chkServices'.$ServiceType->name().'~'.$ServiceType->name();
		} else {
			#push @results, 'chkServices'.$ServiceType->name().'~';
		} # end if
	} # end foreach

	push @results, 'ProjectIndex~'.$Project->id();
	return join( '|', @results );
}

1;

__END__
