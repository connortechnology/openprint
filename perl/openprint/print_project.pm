package openprint::print_project;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;

use strict;

require sql;
require openprint::account;
require openprint::service;
require openprint::ServiceType;
require openprint::ProjectType;
require openprint::Project;
require openprint::Currency;
require openprint::User;
require openprint::ServiceType;
require openprint::logs;
require openprint::Estimating::MultiPage;

# Projects are like Orders, in that you can have several in here, but only ONE of them may be unfinished.

sub insert_project_type {
	my ( $r, $log, $dbh, $project_index, $project_type_id ) = @_;

	my ( $project_type_index ) = sql::execute( $log, $dbh, q{SELECT id FROM Project_Types WHERE name=?}, $project_type_id );
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
		$_ = q{SELECT name, value FROM User_Service_Defaults WHERE servicetype_id IS NULL AND user_id=?};
		push @defaults, sql::execute( $log, $dbh, $_, $openprint::session{'user_id'} );
		
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
		my $Project = new openprint::Project( $project_index );
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, "txtQuantity$qty_index", $Project->quantity($qty_index), 1 );
		} # end foreach
		sql::end_transaction( $dbh,  $ac );
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
	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	foreach my $service_id ( @services ) {
		if ( ! $$services{$service_id} ) {
		insert_service( $log, $dbh, $project_index, $service_id );
		} # end if
	} # end foreach
} # end sub add_service

sub insert_service {
	my ( $log, $dbh, $project_index, $service_id ) = @_;
	my $Project = new openprint::Project( $project_index );
	return $Project->add_service( $service_id );
} # end sub insert_service

sub create_edit_display {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $project_index = $openprint::param{'ProjectIndex'};

	my $Project = new openprint::Project( $project_index );

	@{$$variable{'ProjectTypes'}} = map { $_->name(), $_->description() } openprint::ProjectType->find( 'order'=>'sorting, lower(name)' );
	# Check the appropriate button for project type
	@$variable{'SelectedProjectType'} = $Project->Type()->name();

	@$variable{'txtProjectReference','ddmDesign','txtComments','txtQuantity1','txtQuantity2','txtQuantity3','rdbMode','chkPrograms','txtOtherPrograms'} = (
		$Project->reference(), $Project->design(), $Project->comments(), $Project->quantity1(), $Project->quantity2(), $Project->quantity3(), $Project->mode(), $Project->programs(), $Project->other_programs() 
	);

	my $services = $Project->services();
	@{$$variable{'SelectedServices'}} = keys %{$services};

	$$variable{'ProjectIndex'} = $project_index;
} # end sub edit_stage1_display

sub get_incomplete_services_in_category {
	my ( $log, $dbh, $project_index, $category ) = @_;

	if ( $category eq 'Printing' ) {
		my $Project = new openprint::Project( $project_index );
		my $services = $Project->services();

		if ( $$services{'Signature'} ) {
			foreach my $index ( @{$$services{'Signature'}} ) {
				if ( openprint::service::status( $Project->id(), $index ) ne 'calculated' ) {
					return $index;
				} # end if
			} # end foreach
		} # end if
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

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	# get the printing service
	my $status = openprint::service::status( $Project->id(), $$services{''}[0] ) if $$services{''};
	
	# if the printing service is unfinished, return it.
	# the no url test will only occurr for the "no printing required" project type :)
	if ( $status eq 'uncalculated' ) {
		return ( $$services{''}[0], '/main/project/'.$Project->Type()->url() ) if $Project->Type()->url();
	} # end if

	$log->debug("****** GETTING INCOMPLETE PRINTING SERVICES ********");
	foreach my $service_index ( get_incomplete_services_in_category( $log, $dbh, $project_index, 'Printing' ) ) {
		$log->debug("****** SERVICE: $service_index is incomplete ********");
		my $url = get_redirect_for_service( $log, $dbh, $project_index, $service_index );
		return ( $service_index, $url ) if $url ne '';
	} # end while
	$log->debug("****** FOUND NO INCOMPLETE PRINTING SERVICES ********");
	
	$_ = "SELECT strValue, lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=?".
		" AND strName='ServiceType' AND strValue != 'Signature' AND lngServiceIndex IN (".join(',',@incomplete_services).")";
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
		$project_index = $openprint::session{'project_id'} if ! $project_index;

		my ( $service_index, $redirect ) = choose_service( $log, $dbh, $project_index );
		# pick the next unfinished service.

		if ( ! $service_index ) {
			my $Project = new openprint::Project( $project_index );
			foreach my $qty_index ( 1 .. 3 ) {
				next if ! $Project->quantity($qty_index);
				if ( $_ = openprint::Estimating::MultiPage::status( $project_index, undef, $qty_index ) ) {
					my @sigs = $Project->signatures({'Group'=>$_});
					my $src_id = pop @sigs;
					my $src_specs = openprint::service::get_specs_ref( $Project, $src_id );
					$service_index = $Project->copy_signature( $src_specs );
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
		$error .= "Project $proj_reference does not belong to you.	Not deleted.<br/>";
		$delete = 0;
	} # end if
	$_ = "SELECT Orders.Index FROM Orders,Order_Contents WHERE Orders.Index=Order_Contents.OrderIndex AND lngProjectIndex=? AND Orders.strStatus != 'Incomplete'";
	( $_ ) = sql::execute( $log, $dbh, $_, $project_index );
	if ( $_ ) {
		$error .= "Project $proj_reference is in order <a href=\"/main/order/history_details.html?order_id=$_\">$_</a>.	You must delete the order before you can delete the project.<br/>";
		$delete = 0;
	} # end if
	$_ = "SELECT Quotes.id FROM Quotes,tbl_Quote_Details WHERE Quotes.id=tbl_Quote_Details.quote_id AND project_id=? AND Quotes.strStatus != 'Incomplete'";
	( $_ ) = sql::execute( $log, $dbh, $_, $project_index );
	if ( $_ ) {
		$error .= "Project $proj_reference is in quote <a href=\"/main/quote/history_details.html?quote_id=$_\">$_</a>.	You must delete the quote before you can delete the project.<br/>";
		$delete = 0;
	} # end if
	if ( $delete ) {
		$Project->delete();
	} # end if
	return $error;
} # end sub try_to_delete_project


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
		if ( my @ServiceTypes = openprint::ServiceType->find('name'=>'Signature') ) {
			$_ = "SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName = 'txtSignatureType' AND strValue IN ('Interior Pages','Gate Folded Pages','Cover Pages') ORDER BY lngServiceIndex";
			my @signatures = sql::execute( $log, $dbh, $_, $project_index );
			
			while ( @signatures ) {
				push @services, shift @signatures, $ServiceTypes[0];
			} # end while
		} # end if
	} else { 
		$_ = "SELECT lngServiceIndex, Service_Types.id FROM tbl_Service_Specifications, Service_Types WHERE lngProjectIndex=?
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
	
	$$variable{'OrderId'} = $order_id;
	my $Project = new openprint::Project( $project_index );
	$$variable{'Project'} = $Project;
	my $services = $Project->services();
	$$variable{'Services'} = $services;

	if ( $$services{''} ) {
		my $ProjectType = $Project->Type();
		# print service comes first
		@$variable{'ProjectTypeName','ProjectTypeURL'} = ( $ProjectType->name(), $ProjectType->url() );

		@services = ( $$services{''}[0], 'Printing', $$variable{'ProjectTypeURL'} );

		openprint::print_project::get_service_specifications( $r, $log, $dbh, $variable, $project_index, $$services{''}[0] );
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

	$$variable{'ProjectIndex'} = $project_index;
	$$variable{'NoPriceBreakDown'} = $r->param('NoPriceBreakDown');

	@{$$variable{'PrintingServices'}} = $Project->signatures();
	# new stuff

	$$variable{'ProofServiceIndex'}	= $$services{'Proofs'} ? $$services{'Proofs'}[0] : $$services{'FilmStripping'}[0];

	my $Currency = openprint::Currency::get_current();
	if ( $Currency ) {
		@$variable{'Currency','CurrencyName', 'CurrencySymbol'} = ( $Currency, $Currency->name(), $Currency->symbol() );
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
			my $Project = new openprint::Project( $project_index );
			my $PT = $Project->Type();
			$$variable{'ServiceTypeID'} = $PT->get('name');
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

	my $recalculate;

	my $Project = new openprint::Project( int $openprint::param{'ProjectIndex'} );
	$error = $Project->save() if ( ! $Project->id() );
	$openprint::session{'project_id'} = $Project->id();
	if ( $error ne '' ) {
		$$variable{'Redirect'} = '/main/project/create_edit.html';
		$$variable{'error'} = 'Fields not complete';
		$$variable{'details'} = $error;
		foreach ( $r->param() ) {
			$$variable{$_} = $r->param($_);
		} # end foreach
        return;
    } # end if
	my $project_index = $Project->id();

	my %services = $Project->get_services();
	my @service_ids;
	foreach my $stype ( keys %services ) {
		foreach my $s_id ( @{$services{$stype}} ) {
			push @service_ids, $s_id;
		} # end foreach
	} # end foreach

	if ( $openprint::param{'txtQuantity1'} != $Project->quantity1() ) {
		$recalculate = 1;
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
		$recalculate = 1;
		if ( ! $Project->quantity2() ) {
			if ( $Project->quantity1() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project, $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( ( ! $key =~ /Special/ ) and ( $key =~ /^(.*)1$/ ) ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $1.'2', $$specs{$key} );
						} # end if
					} # end foreach
				} # end if
			} elsif ( $Project->quantity3() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project->id(), $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( ( ! $key =~ /Special/ ) and ( $key =~ /^(.*)3$/ ) ) {
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
		$recalculate = 1;
		if ( ! $Project->quantity3() ) {
			if ( $Project->quantity1() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project->id(), $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( ( ! $key =~ /Special/ ) and ( $key =~ /^(.*)1$/ ) ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $1.'3', $$specs{$key} );
						} # end if
					} # end foreach
				} # end if
			} elsif ( $Project->quantity2() ) {
				foreach my $service_id ( @service_ids ) {
					my $specs = openprint::service::get_specs_ref( $Project->id(), $service_id );
					foreach my $key ( keys %$specs ) {
						next if $key =~ /^txtQuantity/;
						if ( ( ! $key =~ /Special/ ) and ( $key =~ /^(.*)2$/ ) ) {
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

	my @project_types = openprint::ProjectType->find( 'name' => $openprint::param{'rdbProjectType'} );
	my $ProjectType = shift @project_types;
	my $OldProjectType = $Project->Type();

	$Project->reference( $r->param('txtProjectReference') );
	$Project->comments( $r->param('txtComments') );
	$Project->mode( $r->param('rdbMode') );
	$Project->design( $r->param('ddmDesign') );
	$Project->programs( $r->param('chkPrograms') );
	$Project->other_programs( $r->param('txtOtherPrograms') );
	$Project->currency_id( $openprint::session{'Currency_id'} ) if ! $Project->currency_id();

# Handle ProjectType
	if ( $OldProjectType->name() ne $ProjectType->name() ) {
		$recalculate = 1;
		if ( $services{''} ) {
			foreach ( @{$services{''}} ) { delete_service( $log, $dbh, $Project->id(), $_ ); };
		} # end if
		delete $services{''};
		$Project->Type( $ProjectType );
	} # end if
	if ( ! $services{''} ) {
		my $printing_service_index = insert_project_type( $r, $log, $dbh, $Project->id(), $r->param('rdbProjectType') );
		push @{$services{''}}, $printing_service_index;
		$recalculate = 1;
	} # end if
	$Project->save();

	# take care of the Graphic Design service
	if ( $r->param('rdbGraphicDesign') eq 'Y' ) {
		push @{$services{'GraphicDesign'}}, insert_service( $log, $dbh, $project_index, 'GraphicDesign') if ! $services{'GraphicDesign'};
	} # end if


	my %statuses = sql::execute( $log, $dbh, 'SELECT lngserviceindex, strstatus FROM tbl_Project_Contents WHERE lngprojectindex=?', $project_index );

	foreach my $ServiceType ( openprint::ServiceType->find( 'create_visible'=>'Y') ) {
		if ( $openprint::param{'chkServices'.$ServiceType->name()} eq $ServiceType->name() ) {
			if ( ! $services{$ServiceType->name()} ) {	
				push @{$services{$ServiceType->name()}}, insert_service( $log, $dbh, $Project->id(), $ServiceType->name() );
				$recalculate = 1;
			} # end if
		} else {
			if ( $services{$ServiceType->name()} ) {
				foreach my $s_id ( @{$services{$ServiceType->name()}} ) {
					if ( $statuses{$s_id} ne 'Completed' ) {
						delete_service( $log, $dbh, $Project->id(), $s_id );
					} # end if
				} # end foreach
				delete $services{$ServiceType->name()};
				$recalculate = 1;
			} # end if
		} # end if
	} # end foreach
	if ( ! ( $services{'Proofs'} or $services{'NoPrinting'} ) ) {
		push @{$services{'Proofs'}}, insert_service( $log, $dbh, $project_index, 'Proofs');
		$recalculate = 1;
	} # end if

	$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Edited' );
	if ( $recalculate ) {
		$Project->Currency( openprint::Currency::get_current() );
		foreach my $signature_service_index ( $Project->signatures() ) {
			openprint::service::internal_calc( $log, $dbh, $variable, $Project->id(), $signature_service_index, 'Printing' );
		} # end foreach
		openprint::service::auto_calculate( $r, $log, $dbh, $variable, $Project->id(), undef );
	} # end if
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
	sql::end_transaction( $dbh, $ac );
	my $Project = new openprint::Project( $project_index );
	delete $$Project{'Services'};
	delete $$Project{'signatures'};
	delete $$Project{'service_types'};
	#openprint::logs::insertLogRecord('10', "Service Index: " . $service_index . " for Project Index: " . $project_index,);
} # end sub delete_service

sub display_reuse_project {
	my ( $r, $log, $dbh, $variable ) = @_;

	$$variable{'Project'} = new openprint::Project( $openprint::param{'ProjectIndex'} );
	$$variable{'ProjectIndex'} = $$variable{'Project'}->id();
	if ( $$variable{'Project'}->reference() ) {
		$$variable{'Project'}->reference( 'Copy of ' . $$variable{'Project'}->reference() );
	} else {
		$$variable{'Project'}->reference( 'Copy of project # ' . $openprint::param{'ProjectIndex'} );
	} # end if
	
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
	if ( sets::isin( $Project->status(), [ 'Pending Deposit', 'In Prepress', 'Proofs Out', 'Approved', 'Printed', 'Complete','Shipped','Picked Up' ] ) ) {
		$NewProject->status('Unordered');
	} # end if
	$NewProject->company_id( $r->param('ddmCompany') ) if $r->param('ddmCompany');
	$NewProject->save();
	$openprint::session{'project_id'} = $NewProject->id();

	$NewProject->add_to_log( @openprint::session{'company_id','user_id'}, 'Reused from project '.$Project->id() );
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Reused to project '.$NewProject->id() );

	if ( $r->param('ddmCompany') and $r->param('ddmCompany') != $openprint::session{'company_id'} ) {
		openprint::switch_company( new openprint::Company( $r->param('ddmCompany') ) ) if sets::isin( $openprint::session{'user_type'}, ['A','E'] );
	} # end if

	# Make this all one transaction... Don't need locking because a reload would get a different projectindex
	my $ac = sql::start_transaction( $dbh );
	foreach my $service_index ( sql::execute( $log, $dbh, q{SELECT lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $NewProject->id() ) ) {
			
		if ( $Project->quantity1() != $NewProject->quantity1() ) {
			openprint::service::insert_service_spec( $log, $dbh, $NewProject->id(), $service_index, 'txtQuantity1', $NewProject->quantity1() );
		} # end if
		if ( $Project->quantity2() != $NewProject->quantity2() ) {
			openprint::service::insert_service_spec( $log, $dbh, $NewProject->id(), $service_index, 'txtQuantity2', $NewProject->quantity2() );
		} # end if
		if ( $Project->quantity3() != $NewProject->quantity3() ) {
			openprint::service::insert_service_spec( $log, $dbh, $NewProject->id(), $service_index, 'txtQuantity3', $NewProject->quantity3() );
		} # end if
	} # end foreach
	sql::end_transaction( $dbh, $ac );
	if ( $Project->quantity1() != $NewProject->quantity1()
			or $Project->quantity2() != $NewProject->quantity2()
			or $Project->quantity3() != $NewProject->quantity3() ) {
		openprint::Estimating::MultiPage::calculate_signatures( $log, $dbh, $variable, $NewProject->id() );
		openprint::service::auto_calculate( $r, $log, $dbh, $variable, $NewProject->id(), undef );
	} # endif
	$openprint::session{'project_id'} = $NewProject->id();
	return $NewProject->id();
} # end sub reuse_project

1;

__END__
