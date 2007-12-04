package openprint::print;

use strict;

require sql;
require openprint::print_project;
require openprint::service;
require openprint::Currency;

require openprint::Estimating::Skids;
require openprint::Estimating::Printing;
require openprint::Estimating::Shipping;
require openprint::Estimating::Stitching;
require openprint::Estimating::Padding;
require openprint::Estimating::Proofs;
require openprint::Estimating::Multipage;

sub get_project_type {
	my ( $log, $dbh, $project_index ) = @_;
	return if ! $project_index;
	if ( $_ = openprint::project::get_project_type( @_ ) ) {
		return sql::execute( $log, $dbh, 'SELECT strID, strName FROM Project_Types WHERE strID=?', $_ );
	} # end if
} # end sub

sub get_ServiceType {
	my ( $project_index, $service_index ) = @_;
	return if ! $service_index;
	return  new openprint::ServiceType(sql::execute( undef, undef, q{SELECT servicetype_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index ) );
} # end sub get_ServiceType

sub save_service {
	my ( $r, $log, $dbh, $variable, $Project, $service_index ) = @_;
	
	my $ServiceType = get_ServiceType( $Project->id(), $service_index );

	if ( $ServiceType and ( $ServiceType->name() eq 'Proofs' ) ) {
		openprint::Estimating::Proofs::save_proof_specs( $r, $log, $dbh, $variable, $Project->id(), $service_index );
	} else {
		openprint::service::save_service( $r, $log, $dbh, $Project->id(), $service_index );
	} # end if service_type_id
	sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=? AND (NOT strStatus=?) OR (strStatus IS NULL)', $Project->id(), $service_index, 'Completed' ], 'strStatus', ($openprint::param{'Status'} ? $openprint::param{'Status'} : 'calculated') );
	#eval "openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $service_index, $service_type_id );"
	if ( $ServiceType->id() ) {
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, $ServiceType->name().' service saved.' );
	} else {
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Printing service saved.' );
	} # end if
} # end sub save_service

# Adds completed/edited services, and then displays the status of the project
sub view_services {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $project_index = $openprint::param{'ProjectIndex'};

	# I put these here because the don't need a project index
	if ( defined $openprint::param{'btnFunction'} and ( $openprint::param{'btnFunction'} eq 'Save Project' ) ) {
		$log->debug("*** Time to Save Project - View Services Function ***");
		$project_index = openprint::print_project::create_edit_process( $r, $log, $dbh, $variable );
		my $Project = new openprint::Project( $project_index );
		$Project->Currency( openprint::Currency::get_current() );
		foreach my $signature_service_index ( $Project->signatures() ) {
			openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $signature_service_index, 'Printing' );
		} # end foreach
		openprint::service::auto_calculate( $r, $log, $dbh, $variable, $project_index, undef );
		openprint::print_project::continue_project( $log, $dbh, $variable, $project_index );
		$Project->save();
	} # end if

	$project_index = $openprint::session{'project_id'} if ! $project_index;
	if ( ! $project_index ) {
		return;
	} # end if

	my $Project = new openprint::Project( $project_index );
	my ( $cust_id ) = $Project->company_id();

	$log->debug(" **** STARTING VIEW SERVICES FUNCTION * Project $project_index *** $openprint::session{'company_id'}");

	if ( $cust_id eq $openprint::session{'company_id'} or $openprint::session{'user_type'} eq 'A' ) {

		if ( defined $openprint::param{'btnFunction'} ) {
			if ( $openprint::param{'btnFunction'} eq 'Save Service' ) {
				# Update the 'current project'
				$openprint::session{'project_id'} = $project_index;
				$log->debug("** Save Service in View Services Function **");

				my $service_index = $r->param('ServiceIndex');
				save_service( $r, $log, $dbh, $variable, $Project, $service_index );

				if ( $r->param('NewBook') eq 'Y' ) {
					multipage_signatures( \%openprint::param, $log, $dbh, $variable, $project_index, $service_index );
					openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $service_index, 'Multipage' );
					openprint::service::auto_calculate( $r, $log, $dbh, $variable, $project_index, $service_index );
				} elsif ( $r->param('PrintingService') eq 'Y' ) {

					openprint::Estimating::Multipage::calculate_signatures( $log, $dbh, $variable, $project_index, $service_index );
					# Now run code to modify all other services
					# Only do this if all signatures have been specified, otherwise it is a waste of time
					$log->info("********* Auto Calculate  ( PrintingService eq 'Y' ) *************");
					openprint::service::auto_calculate( $r, $log, $dbh, $variable, $project_index, $service_index );
				} # end if
				$Project->Currency( openprint::Currency::get_current() );
				$Project->save();
			} elsif ( $r->param('btnFunction') eq 'Modify Project' ) {
				my $service_name = $openprint::param{'txtServiceName'};
				if ( $service_name eq '' ) {
					$service_name = 'Adjust';
				} # end if

				if ( my @ServiceTypes = openprint::ServiceType::find('name'=>'CustomService') ) {
					my $ac = sql::start_transaction( $dbh );

					sql::insert( $log, $dbh, 'tbl_Project_Contents',
							'lngProjectIndex',	$project_index,
							'strStatus',		'',
							'servicetype_id',	$ServiceTypes[0]->id(),
							);

					$_ = 'SELECT MAX(lngServiceIndex) FROM tbl_Project_Contents WHERE lngProjectIndex=?';
					my ( $service_index ) = sql::execute( $log, $dbh, $_, $project_index );
					sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
								'lngProjectIndex',  $project_index,
								'lngServiceIndex',  $service_index,
								'strName',          'ServiceType',
								'strValue',         'CustomService' ]);
					if ( defined $r->param('txtPrice1') ) {
					sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
								'lngProjectIndex',  $project_index,
								'lngServiceIndex',  $service_index,
								'strName',          'txtPrice1',
								'strValue',         misc::moneyfilter($r->param('txtPrice1') )]);
					} # end if
					if ( defined $r->param('txtPrice2') ) {
					sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
								'lngProjectIndex',  $project_index,
								'lngServiceIndex',  $service_index,
								'strName',          'txtPrice2',
								'strValue',         misc::moneyfilter($r->param('txtPrice2') )]);
					} # end if
					if ( defined $r->param('txtPrice3') ) {
					sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
								'lngProjectIndex',  $project_index,
								'lngServiceIndex',  $service_index,
								'strName',          'txtPrice3',
								'strValue',         misc::moneyfilter($r->param('txtPrice3') )]);
					} # end if
					sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
								'lngProjectIndex',  $project_index,
								'lngServiceIndex',  $service_index,
								'strName',          'ServiceName',
								'strValue',         $service_name ]);
					$Project->add_to_log( @openprint::session{'company_id','user_id'}, sprintf( 'Adding Custom Line: %s, (%.2f, %.2f, %.2f)', $service_name, @openprint::param{'txtPrice1','txtPrice2','txtPrice3'} ) );
					sql::end_transaction( $dbh, $ac );
				} # end if

			} elsif ( $openprint::param{'btnFunction'} eq 'Delete Services' ) {
				foreach my $service_id ( ref $openprint::param{'service_id'} eq 'ARRAY' ? @$openprint::param{'service_id'} : ( $openprint::param{'service_id'} ) ) {
				openprint::print_project::delete_service( $log, $dbh, $project_index, $service_id );
				} # end if
			} elsif ( $openprint::param{'btnFunction'} eq 'Recalculate Project' ) {
				$openprint::session{'project_id'} = $project_index;
				$Project->currency_id( $openprint::session{Currency_id} );
				foreach my $signature_service_index ( $Project->signatures( ) ) {
					openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $signature_service_index, 'Printing' );
				} # end foreach
				openprint::service::auto_calculate( $r, $log, $dbh, $variable, $project_index, undef );
				$Project->save();
				openprint::print_project::continue_project( $log, $dbh, $variable, $project_index );
			} elsif ( $openprint::param{'btnFunction'} eq 'Continue Project' ) {
				openprint::print_project::continue_project( $log, $dbh, $variable, $project_index );
			} elsif ( $openprint::param{'btnFunction'} eq 'Reuse Project' ) {
				$project_index = openprint::print_project::reuse_project( $r, $log, $dbh, $openprint::session{_session_id}, $variable, $project_index );
			} # end if
		} # end if btnFunction defined
		if ( defined $openprint::param{'remove'} and ( $openprint::param{'remove'} ne '' ) ) {
			openprint::print_project::delete_service( $log, $dbh, $project_index, $r->param('remove') );
			$openprint::session{'project_id'} = $project_index;
		} elsif ( ( defined $openprint::param{'calc'} ) and $openprint::param{'calc'} ) {
			openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $r->param('calc') );
		} # end if

		if ( $r->param('ContinueProject') and $r->param('ContinueProject') ne 'Incomplete Form' ) {
			$log->debug("*** Continue Project called From View Services ( view.html ) Function ***");
			openprint::print_project::continue_project( $log, $dbh, $variable, $project_index );
		} # end if 
		if ( ! $$variable{'Redirect'} ) {
			$Project->update_status();
			openprint::project::view( $log, $dbh, $variable, $project_index );
		} # end if
	} # end if

} # end sub view_services

sub get_project_quantities {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my @qtys;
	push @qtys, $Project->quantity1() if $Project->quantity1();
	push @qtys, $Project->quantity2() if $Project->quantity2();
	push @qtys, $Project->quantity3() if $Project->quantity3();
	return @qtys;
} # end sub get_project_quantities


sub print_prices {
	my ( $r, $log, $dbh, $cookie, $variable ) = @_;

	my $service_index = $$variable{'ServiceIndex'};
	$service_index = $openprint::param{'ServiceIndex'} if ! $service_index;
	my $project_index = $$variable{'ProjectIndex'};
	$project_index = $openprint::param{'ProjectIndex'} if ! $project_index;
	$project_index = $openprint::session{'project_id'} if ! $project_index;
	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();

    get_quantities( $variable, $project_index);

    $$variable{'Cutting'} = $services{'Cutting'} ? 'YES' : 'NO';
    $$variable{'Folding'} = $services{'Folding'} ? 'YES' : 'NO';

	$$variable{'Mode'} = $Project->mode();

	@{$$variable{'ddmPressOptions'}} = sql::execute( $log, $dbh, q{SELECT strID, strName FROM tbl_Equipment WHERE strcategory='Printing' AND (UseInEstimating IS true) ORDER BY lower(strName)} );

	@{$$variable{'RunStyleOptions'}} = ( 'Sheet Work', 'Sheet Work', 'Work & Turn', 'Work & Turn', 'Work & Tumble', 'Work & Tumble', 'Perfecting','Perfecting','Web','Web');
	load_template_sizes( $log, $dbh, $$variable{'ProjectTypeID'}, $variable );
} # end sub print_prices

sub load_template_sizes {
	my ( $log, $dbh, $project_type, $variable ) = @_;
    my %templates;
    my $opt;
    my $text = q`
				function option ( text, value ) {
                    this.text = text;
                    this.value = value;
                }
                var options = new Array();
                `;

	$_ = q{SELECT dblFinishedWidth, dblFinishedHeight,dblFlatWidth, dblFlatHeight, Description, Type FROM ProjectTemplate WHERE ProjectType_id=(SELECT lngIndex FROM Project_Types WHERE strID=?) ORDER BY lower(Description)};
	my @templates = sql::execute( $log, $dbh, $_, $project_type );

	while ( @templates ) {
		my $value = shift (@templates) * 1 . 'x' . shift (@templates) * 1  . ',' . shift (@templates) * 1 . 'x' . shift (@templates) * 1;	
		my $desc = shift @templates;
		my $type = shift @templates;
        $opt .= "options\['$type'\]\[options\['$type'\].length\] = new Option ('$value','$desc');\n";
        $templates{$type} = 1;
    } # end while

    foreach my $key ( keys %templates ) {
        $text .= "options['$key'] = new Array();\n";
    } # end foreach
    #$log->debug("***************** $text $arrays $opt  **************");
	$$variable{'TemplateSizes'} = $text . $opt;
} # end sub


# all this function does is the special code when coming from a book service
# it adds all the necceessary signatures, etc.
# It assumes that the book code has already been saved.
sub multipage_signatures {
	my ( $param, $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
    $log->debug(" **** STARTING MULTIPAGE SIGNATURES FUNCTION **** ");

	if ( ! $$param{'txtSpreadSize'} ) {
		# now we have finished the first step for a new book, and have a basic signature set in place.
		if ( $$param{'rdbTemplateType'} eq 'PerfectBound' ) {
			# Insanity code:  Perfect Bound requires different cover.
			$$param{'rdbCover'} = 'Different';
			$$param{'txtSpreadSize'} = 2;
		} elsif ( $$param{'rdbTemplateType'} eq 'SpinePaste' ) {
			# Insanity code:  Perfect Bound requires different cover.
			$$param{'rdbCover'} = 'Self';
			$$param{'txtSpreadSize'} = 2;
		} elsif ( sets::isin( $$param{'rdbTemplateType'}, ['SaddleStitching', 'LoopStitching'] ) ) {
			$$param{'txtSpreadSize'} = 4;
		} elsif ( sets::isin( $$param{'rdbTemplateType'}, ['CornerStitching', 'Cerlox', 'PlasticCoil','MetalCoil'] ) ) {
			$$param{'txtSpreadSize'} = 2;
		} else {
			$log->warn("Unknown Bindery Type: $$param{'rdbTemplateType'}" );
			$$param{'txtSpreadSize'} = 4;
		} # end if
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'txtSpreadSize', $$param{'txtSpreadSize'} );
	} # end if

	#if ( ! $$param{'txtTotalSpreadQuantity'} ) {
		#$$param{'txtTotalSpreadQuantity'} = $$param{'txtTotalPageQuantity'} / $$param{'txtSpreadSize'};
		#$log->warn("INSANITY: TotalSpreadQuantity Not Specified. Setting to $$param{'txtTotalSpreadQuantity'}");
		#openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'txtTotalSpreadQuantity', $$param{'txtTotalSpreadQuantity'});
	#} # end if

	#if ( ! $$param{'txtInteriorSpreadQuantity'} ) {
		## Can happen if all signatures are gatefolded...
		#$log->warn('INSANITY: No interiorspreadquantity!');
		#$$param{'txtInteriorSpreadQuantity'} = int($$param{'txtTotalSpreadQuantity'}) - int($$param{'txtGateFoldedSpreadQuantity'});
		#if ( $$param{'rdbCover'} eq 'Different' ) {
			#if ( $$param{'txtSpreadSize'} == 4 ) {
				#$$param{'txtInteriorSpreadQuantity'} -= 1;
			#} else {
				#$$param{'txtInteriorSpreadQuantity'} -= 2;
			#} # end if
		#} # end if
		#openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'txtInteriorSpreadQuantity', $$param{'txtInteriorSpreadQuantity'} );
	#} # end if


	if ( $$param{'rdbCover'} eq 'Different' ) {
# now add a cover spread if we need one.
# First, see if we have one.
		if ( ! $Project->signatures('Cover Pages') ) {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do( "LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
			my ($cover_index) = openprint::print_project::insert_service( $log, $dbh, $project_index, 'AdditionalSignature' );
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $cover_index, 'txtSignatureType', 'Cover Pages');
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $cover_index, 'txtServiceDescription', 'Cover');
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $cover_index, 'Group', 1 );
# Used to give each signature a # for reference in proofs, etc.
			$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
			my ( $signature_count ) = sql::execute( $log, $dbh, $_, $project_index );
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $cover_index, 'SignatureIndex', ++$signature_count );
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $cover_index, 'rdbTemplateType', '2PanelFold' );
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $cover_index, 'PrintingType', $$param{'PrintingType'} );
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $cover_index, 'txtSpreadSize', 4 );
			# Width and Height will be added on auto-calc
			sql::end_transaction( $dbh, $ac );
		} # end if
	} else {
		# Don't need a cover, so get rid of it
		foreach ( $Project->signatures('Cover Pages') ) {
		openprint::print_project::delete_service( $log, $dbh, $project_index, $_ );
		} # end foreach
	} # end if


# On each call to this, we save, then check to see if there are any unspecified signatures

	# Now, make sure that we have all the gate spreads that we need
	my @gate_spread_services = $Project->signatures('GateFolded Spreads');
	my $need_gate_spreads = int($$param{'txtGateFoldedSpreadQuantity'}) - scalar @gate_spread_services;
	while ( $need_gate_spreads > 0 ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do( "LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
		my ($gate_index) = openprint::print_project::insert_service( $log, $dbh, $project_index, 'AdditionalSignature' );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $gate_index, 'txtSignatureType', 'GateFolded Spreads');
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $gate_index, 'txtServiceDescription', 'Gate Fold Spread');
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $gate_index, 'Group', 3 );
		$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
		my ( $signature_count ) = sql::execute( $log, $dbh, $_, $project_index );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $gate_index, 'SignatureIndex', ++$signature_count );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $gate_index, 'PrintingType', $$param{'PrintingType'} );
		sql::end_transaction( $dbh, $ac );
		$need_gate_spreads -= 1;
	} # end while need_gate_spreads

	if ( ! $Project->signatures('Interior Pages') ) {
# Must have at least 1 interioer signature
		my $ac = sql::start_transaction( $dbh );
		$dbh->do( "LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
		my ($print_service_index) = openprint::print_project::insert_service( $log, $dbh, $project_index, 'AdditionalSignature' );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'txtSignatureType', 'Interior Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'txtServiceDescription', 'Interior Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'Group', 2 );
		$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
		my ( $signature_count ) = sql::execute( $log, $dbh, $_, $project_index );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'SignatureIndex', ++$signature_count );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'PrintingType', $$param{'PrintingType'} );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'txtSpreadSize', $$param{'txtSpreadSize'} );
		sql::end_transaction( $dbh, $ac );
	} # end if

	my %pages = ();

	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
		my $type = $$sig_specs{'Group'};
		foreach my $spec ( 
				'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight',
				'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight',
				'txtSpecificStockWidth','txtSpecificStockHeight','txtSpecificStockCalliper',
				'rdbSuppliedStock','rdbSpecificStock','StockType',
				'CustomSheetDoubleSided', 'CustomStockPrice','txtCustomMWeight','txtStockGSM','CustomStockPriceUnits',
				'basis_width','basis_height','basis_mweight','StockGrade',

				'chkCyanSideOne','chkMagentaSideOne','chkYellowSideOne','chkBlackSideOne', 'chkProcessColourSideOne',
				'CyanSpotSideOneCoverage', 'MagentaSpotSideOneCoverage', 'YellowSpotSideOneCoverage', 'BlackSpotSideOneCoverage',
				'CyanSideOneCoverage', 'MagentaSideOneCoverage', 'YellowSideOneCoverage', 'BlackSideOneCoverage',
				'SideOneUVCoatingType','SideTwoUVCoatingType',
				'CyanSpotSideTwoCoverage', 'MagentaSpotSideTwoCoverage', 'YellowSpotSideTwoCoverage', 'BlackSpotSideTwoCoverage',
				'CyanSideTwoCoverage', 'MagentaSideTwoCoverage', 'YellowSideTwoCoverage', 'BlackSideTwoCoverage',
				'chkSpecialSideOneColour1', 'txtSpecialSideOneColour1', 'txtSpecialSideOneColourInkPercent1',
				'chkSpecialSideOneColour2', 'txtSpecialSideOneColour2', 'txtSpecialSideOneColourInkPercent2',
				'chkSpecialSideOneColour3', 'txtSpecialSideOneColour3', 'txtSpecialSideOneColourInkPercent3',
				'chkSpecialSideOneColour4', 'txtSpecialSideOneColour4', 'txtSpecialSideOneColourInkPercent4',
				'chkSpecialSideOneColour5', 'txtSpecialSideOneColour5', 'txtSpecialSideOneColourInkPercent5',
				'chkSpecialSideOneColour6', 'txtSpecialSideOneColour6', 'txtSpecialSideOneColourInkPercent6',
				'chkSpecialSideOneColour7', 'txtSpecialSideOneColour7', 'txtSpecialSideOneColourInkPercent7',
				'chkSpecialSideOneColour8', 'txtSpecialSideOneColour8', 'txtSpecialSideOneColourInkPercent8',
				'rdbAqueousSideOne',
				'chkVarnishSpotGlossSideOne','chkVarnishSpotMatteSideOne','chkVarnishOverallGlossSideOne','chkVarnishOverallMatteSideOne','chkVarnishDryTrapSideOne',
				'chkCyanSideTwo','chkMagentaSideTwo','chkYellowSideTwo','chkBlackSideTwo', 'chkProcessColourSideTwo',
				'chkSpecialSideTwoColour1', 'txtSpecialSideTwoColour1', 'txtSpecialSideTwoColourInkPercent1',
				'chkSpecialSideTwoColour2', 'txtSpecialSideTwoColour2', 'txtSpecialSideTwoColourInkPercent2',
				'chkSpecialSideTwoColour3', 'txtSpecialSideTwoColour3', 'txtSpecialSideTwoColourInkPercent3',
				'chkSpecialSideTwoColour4', 'txtSpecialSideTwoColour4', 'txtSpecialSideTwoColourInkPercent4',
				'chkSpecialSideTwoColour5', 'txtSpecialSideTwoColour5', 'txtSpecialSideTwoColourInkPercent5',
				'chkSpecialSideTwoColour6', 'txtSpecialSideTwoColour6', 'txtSpecialSideTwoColourInkPercent6',
				'chkSpecialSideTwoColour7', 'txtSpecialSideTwoColour7', 'txtSpecialSideTwoColourInkPercent7',
				'chkSpecialSideTwoColour8', 'txtSpecialSideTwoColour8', 'txtSpecialSideTwoColourInkPercent8',
				'rdbAqueousSideTwo',
				'chkVarnishSpotGlossSideTwo','chkVarnishSpotMatteSideTwo','chkVarnishOverallGlossSideTwo','chkVarnishOverallMatteSideTwo','chkVarnishDryTrapSideTwo',
				'chkBleedLeft','chkBleedRight','chkBleedTop','chkBleedBottom','rdbColourBar','txtCropMarkSpace',
				'GroupPageQuantity','OverrideGroupPageQuantity',
				) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, $spec, $$param{$spec.$type} );
			$pages{$type} = $$sig_specs{'GroupPageQuantity'};
		} # end foreach spec
	} # end foreach

$openprint::log->debug("Summ: " . misc::sum( values %pages ) );

	if ( misc::sum( values %pages ) < $$param{'txtTotalPageQuantity'} ) {
# Must have at least 1 interioer signature
		my $ac = sql::start_transaction( $dbh );
		$dbh->do( "LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
		my ($print_service_index) = openprint::print_project::insert_service( $log, $dbh, $project_index, 'AdditionalSignature' );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'txtSignatureType', 'Interior Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'txtServiceDescription', 'Interior Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'Group', sets::max( keys %pages ) + 1 );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'GroupPageQuantity', $$param{'txtTotalPageQuantity'} - misc::sum( values %pages ) );
		$_ = q{SELECT MAX(strValue) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
		my ( $signature_count ) = sql::execute( $log, $dbh, $_, $project_index );
		$signature_count += 1;
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'SignatureIndex', $signature_count );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'PrintingType', $$param{'PrintingType'} );
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $print_service_index, 'txtSpreadSize', $$param{'txtSpreadSize'} );
		sql::end_transaction( $dbh, $ac );
		$$variable{'Redirect'} = '/main/project/prin/prin_multi.html';
	} # end if

	my %services = $Project->get_services();
	my $old_bindery_type = get_book_type( $project_index );
	if ( $old_bindery_type and ($$param{'rdbTemplateType'} ne $old_bindery_type) and $services{$old_bindery_type} ) {
		foreach ( @{$services{$old_bindery_type}} ) {
			openprint::print_project::delete_service( $log, $dbh, $project_index, $_ );
		} # end foreach
		delete $services{$old_bindery_type};
	} # end if

	if ( $$param{'rdbTemplateType'} eq 'NoBindery' ) {
		foreach ( openprint::print_project::get_services_in_category( $log, $dbh, $project_index, 'Bindery' ) ) {
			if ( $_ ne 'NoBindery' ) {
				openprint::print_project::delete_service( $log, $dbh, $project_index, $_ );
				@{$services{$_}} = sets::exclude( [ $_ ], $services{$_} );
			} # end if
		} # end foreach
		
		push @{$services{'NoBindery'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'NoBindery' ) if ! $services{'NoBindery'};
	} elsif ( $$param{'rdbTemplateType'} ) {
		# Delete No Bindery Service
		if ( $services{'NoBindery'} ) {
			foreach ( @{$services{'NoBindery'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $project_index, $_ );
			} # end foreach
			delete $services{'NoBindery'};
		} # end if

		# Insert the desired Bindery Type
		push @{$services{$$param{'rdbTemplateType'}}}, openprint::print_project::insert_service( $log, $dbh, $project_index, $$param{'rdbTemplateType'} ) if ! $services{$$param{'rdbTemplateType'}};
	} # end if

	if ( sets::isin( $$param{'rdbTemplateType'}, ('SaddleStitching','LoopStitching','PerfectBound') ) ) {
		# Saddle and Loop Stitching requires Folding
		push @{$services{'Folding'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Folding' ) if ! $services{'Folding'};
		push @{$services{'Cutting'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Cutting' ) if ! $services{'Cutting'};
	} # end if
	return openprint::Estimating::Multipage::calculate_signatures( $log, $dbh, $variable, $project_index );
} # end sub multipage_signatures

sub get_book_type {
	my ( $Project ) = @_;
	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
	my $services = $Project->services();

# the way we cut down the book depends on how it is being bound, so we need this for the signature information.
	foreach my $service ( 'SaddleStitching', 'LoopStitching', 'PerfectBound','SpinePaste','Spiral','MetalCoil','PlasticCoil','DoubleLoopWire, Cerlox','NoBindery' ) {
		
		if ( $$services{$service} ) {
			return $service;
		} # end if
	} # end foreach
	return;
} # end sub get_book_type


sub publication_pages {
	my ( $r, $log, $dbh, $cookie, $variable ) = @_;
    my $service_index = $openprint::param{'ServiceIndex'};
    my $project_index = $openprint::param{'ProjectIndex'};
	$project_index = $openprint::session{'project_id'} if ! $project_index;
	$log->debug("********************************** STARTING MULTIPAGE PUBLICATION *******************************");
	
	load_template_sizes ( $log, $dbh, $$variable{'ProjectTypeID'}, $variable );

	$$variable{'rdbGateFoldNo'} = $$variable{'rdbGateFoldYes'} eq '' ? 'checked' : '';

	my $Project = new openprint::Project( $project_index );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
		my $type = $$sig_specs{'Group'};
		foreach my $spec ( 
				'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight',
				'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight',
				'txtSpecificStockWidth','txtSpecificStockHeight','txtSpecificStockCalliper',
				'rdbSuppliedStock','rdbSpecificStock','StockType',
				'CustomSheetDoubleSided', 'CustomStockPrice','txtCustomMWeight','txtStockGSM','CustomStockPriceUnits',
				'basis_width','basis_height','basis_mweight','StockGrade',
				'chkCyanSideOne','chkMagentaSideOne','chkYellowSideOne','chkBlackSideOne', 'chkProcessColourSideOne',
				'chkSpecialSideOneColour1', 'txtSpecialSideOneColour1', 'txtSpecialSideOneColourInkPercent1',
				'chkSpecialSideOneColour2', 'txtSpecialSideOneColour2', 'txtSpecialSideOneColourInkPercent2',
				'chkSpecialSideOneColour3', 'txtSpecialSideOneColour3', 'txtSpecialSideOneColourInkPercent3',
				'chkSpecialSideOneColour4', 'txtSpecialSideOneColour4', 'txtSpecialSideOneColourInkPercent4',
				'chkSpecialSideOneColour5', 'txtSpecialSideOneColour5', 'txtSpecialSideOneColourInkPercent5',
				'chkSpecialSideOneColour6', 'txtSpecialSideOneColour6', 'txtSpecialSideOneColourInkPercent6',
				'chkSpecialSideOneColour7', 'txtSpecialSideOneColour7', 'txtSpecialSideOneColourInkPercent7',
				'chkSpecialSideOneColour8', 'txtSpecialSideOneColour8', 'txtSpecialSideOneColourInkPercent8',
				'rdbAqueousSideOne',
				'chkVarnishSpotGlossSideOne','chkVarnishSpotMatteSideOne','chkVarnishOverallGlossSideOne','chkVarnishOverallMatteSideOne','chkVarnishDryTrapSideOne',
				'chkCyanSideTwo','chkMagentaSideTwo','chkYellowSideTwo','chkBlackSideTwo', 'chkProcessColourSideTwo',
				'chkSpecialSideTwoColour1', 'txtSpecialSideTwoColour1', 'txtSpecialSideTwoColourInkPercent1',
				'chkSpecialSideTwoColour2', 'txtSpecialSideTwoColour2', 'txtSpecialSideTwoColourInkPercent2',
				'chkSpecialSideTwoColour3', 'txtSpecialSideTwoColour3', 'txtSpecialSideTwoColourInkPercent3',
				'chkSpecialSideTwoColour4', 'txtSpecialSideTwoColour4', 'txtSpecialSideTwoColourInkPercent4',
				'chkSpecialSideTwoColour5', 'txtSpecialSideTwoColour5', 'txtSpecialSideTwoColourInkPercent5',
				'chkSpecialSideTwoColour6', 'txtSpecialSideTwoColour6', 'txtSpecialSideTwoColourInkPercent6',
				'chkSpecialSideTwoColour7', 'txtSpecialSideTwoColour7', 'txtSpecialSideTwoColourInkPercent7',
				'chkSpecialSideTwoColour8', 'txtSpecialSideTwoColour8', 'txtSpecialSideTwoColourInkPercent8',
				'rdbAqueousSideTwo',
				'chkVarnishSpotGlossSideTwo','chkVarnishSpotMatteSideTwo','chkVarnishOverallGlossSideTwo','chkVarnishOverallMatteSideTwo','chkVarnishDryTrapSideTwo',
				'CyanSpotSideOneCoverage', 'MagentaSpotSideOneCoverage', 'YellowSpotSideOneCoverage', 'BlackSpotSideOneCoverage',
				'CyanSideOneCoverage', 'MagentaSideOneCoverage', 'YellowSideOneCoverage', 'BlackSideOneCoverage',
				'CyanSpotSideTwoCoverage', 'MagentaSpotSideTwoCoverage', 'YellowSpotSideTwoCoverage', 'BlackSpotSideTwoCoverage',
				'CyanSideTwoCoverage', 'MagentaSideTwoCoverage', 'YellowSideTwoCoverage', 'BlackSideTwoCoverage',
				'chkBleedLeft','chkBleedRight','chkBleedTop','chkBleedBottom','rdbColourBar','txtCropMarkSpace',
				'GroupPageQuantity','OverrideGroupPageQuantity','txtServiceDescription',
				'SideOneUVCoatingType','SideTwoUVCoatingType',
				) {
			$$variable{$spec.$type} = $$sig_specs{$spec};
		} # end foreach spec
	} # end foreach ss_id

	if ( ! $$variable{'rdbTemplateType'} ) {
		$$variable{'rdbTemplateType'} = get_book_type( $project_index );
	} # end if

} # end sub publication_pages

sub get_insert_specs {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;
	$log->debug("************************** GETTING INSERT SPECS **************************");
	if ( $$variable{'txtInsertQuantity'} eq '' ) {
		$_ = "SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex='$project_index' AND strName='txtInsertQuantity'";
		( $$variable{'txtInsertQuantity'} ) = sql::execute( $log, $dbh, $_ );
	} # end if
	for (my $x = 1; $x <= $$variable{'txtInsertQuantity'}; $x += 1 ) {
		push @{$$variable{'INSERTS'}}, $x, $$variable{"txtInsertPage1$x"}, $$variable{"txtInsertPage2$x"}, $$variable{"txtFinalWidth$x"}, $$variable{"txtFinalHeight$x"};
	} # end for
	$$variable{'txtPockets'} = $$variable{'SignatureCount'} + $$variable{'txtInsertQuantity'};

} # end sub

sub get_finished_weight {
	my ( $project_index ) = @_; 
	my $project_weight;

	my $Project = new openprint::Project( $project_index );
	# We do a weird thing with qty_index here, becasue all quantities should have the same weight, but may be calculated diferent ways, so we run through them until we get a valid weight.

# calculate project weight
	foreach my $signature_service_index ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		foreach my $qty_index ( 1 .. 3 ) {
			next if ! $$specs{'txtQuantity'.$qty_index};
			$project_weight += openprint::Estimating::Printing::get_weight( $Project, $specs, $qty_index );
			last;
		} # end foreach
	} # end foreach
	#$openprint::log->debug("Project Weight: $project_weight : Marked Up: ". $project_weight * (1+$openprint::config{'WeightMarkup'}/100));
	
	# This 1.1 was actually requested by Amin.  So it was pretty random, but then I thought abotu it, and our weight calculations don't take into account the weight of the ink, etc... so it may actually be not too off.... would love to see some real figures on it.
	return $project_weight * (1+$openprint::config{'WeightMarkup'}/100);
} # end sub get_finished_weight


# Finished calliper for books will be calculated from the first qty.  All three should be the same.
sub get_finished_calliper { 
	my ( $project_index, $folding_service_index, $project_type ) = @_; 
	#$openprint::log->debug("******************************* GETTING FINSIHED CALLIPER PROJECT TYPE $project_type *********************************");

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	my $folding_specs;	
	$folding_service_index = $$services{'Folding'}[0] if ( ! $folding_service_index ) and $$services{'Folding'};
	if ( $folding_service_index ) {
		$folding_specs = openprint::service::get_specs_ref( $project_index, $folding_service_index );
	} # end if

	my $finished_calliper;
    foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		my $calliper = $$sig_specs{'txtSpecificStockCalliper'};
		if ( $$sig_specs{'PageQuantity1'} ) {
			$calliper *= $$sig_specs{'PageQuantity1'}/2;
		} # end if

		if ( $$sig_specs{'ServiceType'} eq 'AdditionalSignature' ) {
			$finished_calliper += $calliper;
		} elsif ( $$sig_specs{'ProjectType'} eq 'ScratchPads' ) {
			$finished_calliper += $$sig_specs{'PageQuantity'} * $calliper;
		} else {
				my $pages = 1;
				if ( $$sig_specs{'rdbTemplateType'} eq '2PanelFold' ) {
					$pages = 2;
				} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'},['3PanelFold','3PanelZFold'] ) ) {
					$pages = 3;
				} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['4PanelFold', '4PanelZFold'] ) ) {
					$pages = 4;
				} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['5PanelFold', '5PanelZFold'] ) ) {
					$pages = 5;
				} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['6PanelFold', '6PanelZFold'] ) ) {
					$pages = 6;
				} elsif ( $$sig_specs{'rdbTemplateType'} eq 'SingleGateFold' ) {
					$pages = 3;
				} elsif ( $$sig_specs{'rdbTemplateType'} eq 'DoubleGateFold' ) {
					$pages = 4;
				} elsif ( $$sig_specs{'rdbTemplateType'} eq 'DifficultFold' ) {
					$pages = 6;
				} #// end if
				$finished_calliper += $pages * $$sig_specs{'txtSpecificStockCalliper'};
		} # end if
	} # end foreach
#$openprint::log->debug("Calliper: $finished_calliper");
	return $finished_calliper;
} # end sub get_finished_calliper

sub get_quantities {
	my ( $variable, $project_index) = @_;
	if ( ! $$variable{'QUANTITIES'} ) {
		my $Project = new openprint::Project( $project_index );
		my @qtys = $Project->quantities();
		for ( my $index = 0; $index < @qtys; $index += 1 ) {
			$$variable{'QUANTITIES'} .= " quantities[$index] = '$qtys[$index]'; \n";
			$$variable{'QUANTITY'.($index+1)} = $qtys[$index];
			$$variable{'txtQuantity'.($index+1)} = $qtys[$index];
		} # end for
	} # end if
} # end sub get_quantities

1;

__END__
