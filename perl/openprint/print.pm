use strict;
package openprint::print;

require sql;
require openprint::main_project;
require openprint::print_project;
require openprint::service;
require openprint::Currency;

require openprint::Estimating::Skids;
require openprint::Estimating::Printing;
require openprint::Estimating::Shipping;
require openprint::Estimating::Stitching;
require openprint::Estimating::Padding;
require openprint::Estimating::Proofs;
require openprint::Estimating::MultiPage;

sub get_ServiceType {
	my ( $project_index, $service_index ) = @_;
	return if ! $service_index;
	return  new openprint::ServiceType(sql::execute( undef, undef, q{SELECT servicetype_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index ) );
} # end sub get_ServiceType

# Adds completed/edited services, and then displays the status of the project
sub view_services {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $project_index = $openprint::param{project_id} ? $openprint::param{project_id} : $openprint::param{ProjectIndex};

	# I put these here because the don't need a project index
	if ( defined $openprint::param{btnFunction} ) {
		if ( $openprint::param{btnFunction} eq 'Save Project' ) {
			$log->debug("*** Time to Save Project - View Services Function ***");
			$project_index = openprint::print_project::create_edit_process( $r, $log, $dbh, $variable );
			return if $$variable{Redirect}; # Redirects on error
			my $Project = new openprint::Project( $project_index );
			my $services = $Project->services();
			my $s = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $$services{''}[0], $Project->Type()->type() );
			$log->debug("*** Time to Save Project - View Services Function *** $project_index $openprint::session{project_id}");
			# Display any resulting uncalculated services
			openprint::print_project::continue_project( $log, $dbh, $variable, $project_index );
			return if $$variable{ExternalRedirect};
		} elsif ( $openprint::param{btnFunction} eq 'Delete Project' ) {
			$$variable{error} .= openprint::print_project::try_to_delete_project( $openprint::log, $openprint::dbh, \%openprint::variable, $project_index );
			if ( ! $$variable{error} ) {
				$$variable{ExternalRedirect} = '/main/project/history.html';
				return;
			} # end if
		} elsif ( $openprint::param{btnFunction} eq 'Undelete Project' ) {
			my $Project = new openprint::Project( $project_index );
			$$variable{error} .= $Project->undelete();
		} # end if
	} # end if defined btnFunction

	$project_index = $openprint::session{project_id} if ! $project_index;
	if ( ! $project_index ) {
		$$variable{Project} = new openprint::Project();
		return;
	} # end if
	my $Project = $$variable{Project} = new openprint::Project( $project_index );
	my $services = $Project->services();
	my $Service = $Project->Service( $openprint::param{ServiceIndex} ) if $openprint::param{ServiceIndex};

	$log->debug(" **** STARTING VIEW SERVICES FUNCTION * Project $project_index( $$Project{id} ) *** $openprint::session{company_id}");

	if ( ( $Project->company_id() == $openprint::session{company_id} ) or sets::isin( $openprint::session{user_type}, ['E','A'] ) ) {

		if ( defined $openprint::param{btnFunction} ) {
			if ( $openprint::param{btnFunction} eq 'Export JDF' ) {
				misc::export( $r, $log, $variable, 'Docket-'.$Project->docket().'.jdf', [$Project->jdf()->toString()] );
			} elsif ( $openprint::param{btnFunction} eq 'Make Predefined' ) {
				$Project->predefined( 1 );
				$$variable{error} .= $Project->save();
			} elsif ( $openprint::param{btnFunction} eq 'Save Service' ) {
				# Update the 'current project'
				$openprint::session{project_id} = $project_index;
				$log->debug("** Save Service in View Services Function **");

				my $service_index = $openprint::param{ServiceIndex};
				if ( ! $Service ) {
					$$variable{error} .= $openprint::param{ServiceType} . ' service ' . $service_index . ' is no longer in project. It may have been removed while you were editing it.  Your changes may not have been saved.<br/>';
					$$variable{ExternalRedirect} = '/main/project/view.html?project_id='.$project_index;
					return;
				} # end if
				my $recalc = 0;	
				my $ServiceType = $Service->ServiceType();

				if ( $ServiceType and ( $ServiceType->name() eq 'Proofs' ) ) {
					openprint::Estimating::Proofs::save_proof_specs( $r, $log, $dbh, $variable, $Project->id(), $service_index );
				} else {
					openprint::service::save_service( $r, $log, $dbh, $Project->id(), $service_index );
				} # end if service_type_id
				$Service->save({ status=>($openprint::param{Status} ? $openprint::param{Status} : 'calculated')}) if $Service->status() and $Service->status() ne 'Completed';

				if ( $ServiceType->id() ) {
					$Project->add_to_log( @openprint::session{'company_id','user_id'}, $ServiceType->name().' service saved.' );
				} else {
					$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Project service saved.' );
				} # end if

				my $Currency = openprint::Currency::get_current();
				if ( $Project->currency_id() != $Currency->id() ) {
					$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Currency changed from '.$Project->Currency()->name() . ' to '. $Currency->name() );
					$Project->currency_id( $Currency->id() );
					# Change of currency calls for complete recalc
					if ( $openprint::param{ServiceType} eq 'Printing' or ! $openprint::param{ServiceType} ) {
					} else {
						openprint::Estimating::MultiPage::calculate_signatures( $Project );
						# Shouldn't we do this befiore that?
						openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $$services{''}[0], $Project->Type()->type() );
					} # end if
				} # end if

				$Project->lock();
				if ( !$openprint::param{ServiceType} ) {
					multipage_signatures( \%openprint::param, $log, $dbh, $variable, $project_index, $service_index );
					$Project->unlock();
					$Project->lock();
					my $s = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $service_index, $Project->Type()->type() );
					if ( $$s{Status} ne 'calculated' ) {
						$log->error("Error calculting Project service");
						# Don't want to redirect because it would be annoying.  Just go to view.
					} else {
						openprint::Estimating::MultiPage::calculate_signatures( $Project );
					} # end if
					$recalc = 1;
				} elsif ( $openprint::param{ServiceType} eq 'Printing' ) {
					openprint::Estimating::MultiPage::calculate_signatures( $Project );
					openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $$services{''}[0], $Project->Type()->type() );
# Might need to test for status of project service
					$recalc = 1;
				} elsif (sets::isin(  $openprint::param{ServiceType}, [ 'Scoring', 'Perforating','SpinePaste','Stitching','Sewing','DieCutting'] ) ) {
					openprint::Estimating::MultiPage::calculate_signatures( $Project );
					$recalc = 1;
				} elsif (sets::isin(  $r->param('ServiceType'), [ 'Folding' ] ) ) {
					if ( $$services{Cutting} and @{$$services{Cutting}} ) {	
						openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $$services{Cutting}[0], 'Cutting' );
					} # end if
					if ( $$services{SaddleStitching} and @{$$services{SaddleStitching}} ) {	
						openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $$services{SaddleStitching}[0], 'Stitching' );
					} # end if
				} elsif ( $openprint::param{ServiceType} eq 'Paper' ) {
					openprint::service::internal_calc( $log, $dbh, $variable, $project_index,  $service_index, 'Paper' );
				} # end if
				openprint::service::auto_calculate( $Project, $service_index ) if $recalc;
				$Project->update_status();
				$Project->unlock();
		
				$Project->summary(undef);
				$Project->save( { calculated_on => 'NOW()' } );
				openprint::print_project::continue_project( $log, $dbh, $variable, $project_index );
				return if $$variable{ExternalRedirect};
			} elsif ( $r->param('btnFunction') eq 'Modify Project' ) {
				my $service_name = $openprint::param{txtServiceName} ? $openprint::param{txtServiceName} : 'Adjustment';
				my $CurrentCurrency = openprint::Currency::get_current();
				my $ProjectCurrency = $Project->Currency();
				my $conversion_rate = $CurrentCurrency->conversions( $ProjectCurrency->id() );

				if ( my $ServiceType = openprint::ServiceType->find_one( name=>'CustomService' ) ) {
					my $service_id = $Project->add_service( $ServiceType, {
						( $openprint::param{txtPrice1} ? ( txtPrice1 => $conversion_rate * misc::moneyfilter($openprint::param{txtPrice1} ) ) : () ),
						( $openprint::param{txtPrice2} ? ( txtPrice2 => $conversion_rate * misc::moneyfilter($openprint::param{txtPrice2} ) ) : () ),
						( $openprint::param{txtPrice3} ? ( txtPrice3 => $conversion_rate * misc::moneyfilter($openprint::param{txtPrice3} ) ) : () ),
						ServiceName => $service_name }, { status=>'calculated' } );
 
					$Project->add_to_log( @openprint::session{'company_id','user_id'}, sprintf( 'Adding Custom Line: %s, (%.2f, %.2f, %.2f)', $service_name, @openprint::param{'txtPrice1','txtPrice2','txtPrice3'} ) );

				} # end if has Customer Service type

			} elsif ( $openprint::param{btnFunction} eq 'Delete Services' ) {
				foreach my $service_id ( ref $openprint::param{service_id} eq 'ARRAY' ? @$openprint::param{service_id} : ( $openprint::param{service_id} ) ) {
					my $Service = $Project->Service( $service_id );
					$$variable{error} .= $Service->delete();
					if ( $Service->Type()->name() eq 'Cutting' ) {
						if ( $$services{UVCoating} ) {
							openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $$services{UVCoating}[0], 'UVCoating' );
						} # end if
					} # end if
				} # end if
			} elsif ( $openprint::param{btnFunction} eq 'Recalculate Project' ) {
				if ( exists $openprint::param{markup} ) {
					$openprint::param{markup} =~ s/[^\d\.\-]//mg;
					$Project->markup( $openprint::param{markup} );
					$Project->save();
				} # end if
				$openprint::session{project_id} = $project_index;
				$Project->currency_id( $openprint::session{Currency_id} );
				$Project->recalculate();
				openprint::print_project::continue_project( $log, $dbh, $variable, $project_index );
				return if $$variable{ExternalRedirect};
			} elsif ( $openprint::param{btnFunction} eq 'Continue Project' ) {
				$openprint::session{project_id} = $project_index;
				$Project->currency_id( $openprint::session{Currency_id} );
				$Project->recalculate();
				openprint::print_project::continue_project( $log, $dbh, $variable, $project_index );
				return if $$variable{ExternalRedirect};
			} elsif ( $openprint::param{btnFunction} eq 'Reuse Project' ) {
				$project_index = openprint::print_project::reuse_project( $project_index );
				$Project = new openprint::Project( $project_index );
			} # end if
			if ( ! $$variable{Redirect} ) {
				$Project->update_status();
				$$variable{ExternalRedirect} = '/main/project/view.html?project_id='.$project_index;
				return;
			} # end if
		} # end if btnFunction defined
		if ( defined $openprint::param{remove} and ( $openprint::param{remove} ne '' ) ) {
			foreach my $s_id ( split(',', $openprint::param{remove} ) ) {
				my $PS = $Project->Service( $s_id );
				next if ! $PS->service_id();
				my $ServiceType = $PS->ServiceType();
				if ( sets::isin( $ServiceType->name(), ['Proofs'] ) and ( @{$$services{$ServiceType->name()}} == 1 ) ) {
					$$variable{error} .= 'Proofs cannot be removed from the project.<br/>';
					next;
				} # end if
				my $specs = $PS->specs();
				$$variable{error} .= $PS->delete();
				if ( $ServiceType->name() eq 'Signature' ) {
					openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $$services{''}[0], $Project->Type()->type() );
				} elsif ( $ServiceType->name() eq 'Cutting' ) {
					if ( $$services{UVCoating} ) {
						openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $$services{UVCoating}[0], 'UVCoating' );
					} # end if
				} # end if
			} # end foreach s_id
			$openprint::session{project_id} = $project_index;
			$Project->summary(undef);
			$Project->save();
			$Project->update_status();
			$$variable{ExternalRedirect} = '/main/project/view.html?project_id='.$Project->id();
		} elsif ( ( defined $openprint::param{calc} ) and $openprint::param{calc} ) {
			$log->debug("Recalculating $openprint::param{calc}");
			openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $r->param('calc') );
			$Project->summary(undef);
			$Project->save();
			$Project->update_status();
			$$variable{ExternalRedirect} = '/main/project/view.html?project_id='.$project_index;
			return;
		} # end if

		if ( $r->param('ContinueProject') and $r->param('ContinueProject') ne 'Incomplete Form' ) {
			$log->debug("*** Continue Project called From View Services ( view.html ) Function ***");
			openprint::print_project::continue_project( $log, $dbh, $variable, $project_index );
			return if $$variable{ExternalRedirect};
		} # end if 
		if ( ! $$variable{Redirect} ) {
			openprint::main_project::view( $project_index );
		} # end if
	} # end if can_edit

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

	my $service_index = $$variable{ServiceIndex};
	$service_index = $openprint::param{ServiceIndex} if ! $service_index;
	my @service_ids = split(',', $service_index);
	$service_index = $service_ids[0];
	my $project_index = $$variable{ProjectIndex};
	$project_index = $openprint::param{ProjectIndex} if ! $project_index;
	$project_index = $openprint::session{project_id} if ! $project_index;
	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

    $$variable{Cutting} = $$services{Cutting} ? 'YES' : 'NO';
    $$variable{Folding} = $$services{Folding} ? 'YES' : 'NO';
    $$variable{NoPrinting} = $$services{NoPrinting};

	$$variable{Mode} = $Project->mode();

	@{$$variable{RunStyleOptions}} = ( 'Sheet Work', 'Sheet Work', 'Work & Turn', 'Work & Turn', 'Work & Tumble', 'Work & Tumble', 'Perfecting','Perfecting','Web','Web');
} # end sub print_prices

# all this function does is the special code when coming from a book service
# it adds all the necceessary signatures, etc.
# It assumes that the book code has already been saved.
sub multipage_signatures {
	my ( $param, $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $ac = sql::start_transaction( $dbh );
	my $Project = new openprint::Project( $project_index );
	$Project->lock();
	my $services = $Project->services();
	$service_index = $$services{''}[0] if ! $service_index;

    $openprint::log->debug(" **** STARTING MULTIPAGE SIGNATURES FUNCTION **** ");

	if ( ! $$param{txtSpreadSize} ) {
		# now we have finished the first step for a new book, and have a basic signature set in place.
		if ( $$param{rdbTemplateType} eq 'PerfectBound' ) {
			# Insanity code:  Perfect Bound requires different cover.
			$$param{rdbCover} = 'Different';
			$$param{txtSpreadSize} = $openprint::config{PerfectBindSpreadSize} ? $openprint::config{PerfectBindSpreadSize} : 2;
		} elsif ( $$param{rdbTemplateType} eq 'SpinePaste' ) {
			# Insanity code:  Perfect Bound requires different cover.
			$$param{rdbCover} = 'Self';
			$$param{txtSpreadSize} = 2;
		} elsif ( sets::isin( $$param{rdbTemplateType}, ['SaddleStitching', 'LoopStitching'] ) ) {
			$$param{txtSpreadSize} = 4;
		} elsif ( sets::isin( $$param{rdbTemplateType}, ['CornerStitching', 'Cerlox', 'PlasticCoil','MetalCoil', 'Unbound'] ) ) {
			$$param{txtSpreadSize} = 2;
		} elsif ( $Project->Type()->name() eq 'MultiPage' ) {
			$openprint::log->warn("Unknown Bindery Type: $$param{rdbTemplateType}" );
			$$param{txtSpreadSize} = 4;
		} else {
			$openprint::log->warn("Unknown Bindery Type: $$param{rdbTemplateType}" );
			$$param{txtSpreadSize} = 2;
		} # end if
		openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'txtSpreadSize', $$param{txtSpreadSize} );
	} # end if

	my $max_group;
	my %needed_pages;
	$needed_pages{'Cover Pages'} = $$param{OverrideGroupPageQuantity1} eq 'Y' ? $$param{GroupPageQuantity1} : ($$param{rdbCover} eq 'Different' ? 4 : 0);
	$needed_pages{'Gate Folded Pages'} = $$param{txtGateFoldedPageQuantity};
	$needed_pages{'Interior Pages'} = ( $$param{txtTotalPageQuantity} - $needed_pages{'Cover Pages'} ) - $needed_pages{'Gate Folded Pages'};

	my %specified_pages;

	if ( $$param{rdbCover} eq 'Different' ) {
# now add a cover spread if we need one.
# First, see if we have one.
		if ( ! $Project->signatures({'type'=>'Cover Pages'}) ) {
			push @{$$services{Signature}}, $Project->add_signature( undef, undef, {
						'txtSignatureType'=>'Cover Pages',
						'txtServiceDescription'=>'Cover',
						'Group'	=>	1,
						'PrintingType'=>$$param{PrintingType},
						'txtSpreadSize'	=>	4,
						} );
			$specified_pages{'Cover Pages'} = 4;
		} # end if

		# Prime this for saving later
		if ( ( ! $$param{GroupPageQuantity1} ) and ( $$param{OverrideGroupPageQuantity1} ne 'Y' ) ) {
			$$param{GroupPageQuantity1} = $needed_pages{'Cover Pages'};
		} # end if
	} else {
# Don't need a cover, so get rid of it
		foreach ( $Project->signatures({'type'=>'Cover Pages'}) ) {
			openprint::print_project::delete_service( $Project, $_ );
		} # end foreach
		foreach ( $Project->signatures({'Group'=>1}) ) {
			openprint::print_project::delete_service( $Project, $_ );
		} # end foreach
	} # end if Self or Different Cover


	foreach my $k ( keys %$param ) {
		if ( $k =~ /^txtSignatureType(\d*)/ ) {
			my $group_id = $1;
$log->debug("group $group_id");
			next if $group_id == 1 and $$param{rdbCover} ne 'Different';

			if ( $$param{'GroupPageQuantity'.$group_id} and ! $Project->signatures({'Group'=>$group_id}) ) {
				$log->debug("adding special group $group_id");
				my $print_service_index = $Project->add_signature( undef, undef, {
						#'txtSignatureType'=>'Interior Pages',
						#'txtServiceDescription'=>'Interior Pages',
						'Group'	=>	$group_id,
						'PrintingType'=>$$param{PrintingType},
						'txtSpreadSize'	=>	$$param{txtSpreadSize},
						} );
				push @{$$services{Signature}}, $print_service_index;
			} # end if

			$specified_pages{$$param{$k}} += $$param{'GroupPageQuantity'.$group_id};
			if ( $group_id > $max_group ) {
				$max_group = $group_id;
			} # end if
		} # end if
	} # end foreach param
	$max_group = 3 if $max_group < 3; # Reserver 1, 2, 3 for Cover, Interior, Gate
	$openprint::log->debug("Max group: $max_group");

# On each call to this, we save, then check to see if there are any unspecified signatures

	# Now, make sure that we have all the gate spreads that we need
	my @gate_spread_services = $Project->signatures({'type'=>'Gate Folded Pages'});
	my $need_gate_spreads = int($$param{txtGateFoldedSpreadQuantity}) - scalar @gate_spread_services;
	while ( $need_gate_spreads > 0 ) {
		push @{$$services{Signature}}, $Project->add_signature( undef, undef, {
				'txtSignatureType'=>'Gate Folded Pages',
				'txtServiceDescription'=>'Gate Folded Pages',
				'Group'	=>	3,
				'PrintingType'=>$$param{PrintingType},
				} );
		$need_gate_spreads -= 1;
	} # end while need_gate_spreads

	if ( ! $Project->signatures({'type'=>'Interior Pages'}) ) {
# Must have at least 1 interioer signature
		$log->debug('add interiorpages');
		my $print_service_index = $Project->add_signature( undef,  undef, {
				'txtSignatureType'=>'Interior Pages',
				'txtServiceDescription'=>'Interior Pages',
				'Group'	=>	2,
				'PrintingType'=>$$param{PrintingType},
				'txtSpreadSize'	=>	$$param{txtSpreadSize},
				} );
		$specified_pages{'Interior Pages'} = $needed_pages{'Interior Pages'};
	} # end if
	if ( ( ! $$param{GroupPageQuantity2} ) and ( $$param{OverrideGroupPageQuantity2} ne 'Y' ) ) {
		$$param{GroupPageQuantity2} = $needed_pages{'Interior Pages'};
	} # end if

	foreach my $ss_id ( $Project->signatures() ) {
		if ( $ss_id == $service_index ) {
			$log->error("No signatures in multipage! Means we found the project service in the list of signatures");
			next;
		} # end if
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $group_id = $$sig_specs{Group};
		if ( $group_id == 1 ) {
			# Presentation Folder Cover -> Make sure required services like Die Cutting and Gluing are present
			if ( sets::isin( $$param{'rdbTemplateType'.$group_id}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
				if ( my $ProjectType = openprint::ProjectType->find_one('name'=>'PresentationFolders') ) {
					foreach my $ServiceType ( $ProjectType->required_ServiceTypes() ) {
						if ( ! $$services{$ServiceType->name()} ) {
							push @{$$services{$ServiceType->name()}}, $Project->add_service( $ServiceType );
						} # end if
					} # end foreach servicetype
				} # end if
			} # end if
		} # end if

		# We have to do this for simple printing.  Simple printing calls here, but doesn't have these fields, so it clears out the defaults!
		foreach my $spec ( 
				'txtSignatureType','pages_supplied','supplied_format',
				'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight','ddmStockQuality','ddmStockGroup',
				'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight',
				'txtSpecificStockWidth','txtSpecificStockHeight','txtSpecificStockCalliper',
				'rdbSuppliedStock','rdbSpecificStock','StockType',
				'CustomSheetDoubleSided', 'CustomStockPrice','txtCustomMWeight','txtStockGSM','CustomStockPriceUnits',
				'basis_width','basis_height','basis_mweight','StockGrade',
				'minimum_order', 'sheets_per_package', 'full_packages',

				'CyanSpotSideOneCoverage', 'MagentaSpotSideOneCoverage', 'YellowSpotSideOneCoverage', 'BlackSpotSideOneCoverage',
				'CyanSideOneCoverage', 'MagentaSideOneCoverage', 'YellowSideOneCoverage', 'BlackSideOneCoverage',
				'CyanSpotSideTwoCoverage', 'MagentaSpotSideTwoCoverage', 'YellowSpotSideTwoCoverage', 'BlackSpotSideTwoCoverage',
				'CyanSideTwoCoverage', 'MagentaSideTwoCoverage', 'YellowSideTwoCoverage', 'BlackSideTwoCoverage',
				'ColourCoatingType1SideOne', 'ColourCoatingColour1SideOne','ColourCoatingCoverage1SideOne',
				'ColourCoatingType2SideOne', 'ColourCoatingColour2SideOne','ColourCoatingCoverage2SideOne',
				'ColourCoatingType3SideOne', 'ColourCoatingColour3SideOne','ColourCoatingCoverage3SideOne',
				'ColourCoatingType4SideOne', 'ColourCoatingColour4SideOne','ColourCoatingCoverage4SideOne',
				'ColourCoatingType5SideOne', 'ColourCoatingColour5SideOne','ColourCoatingCoverage5SideOne',
				'ColourCoatingType6SideOne', 'ColourCoatingColour6SideOne','ColourCoatingCoverage6SideOne',
				'ColourCoatingType7SideOne', 'ColourCoatingColour7SideOne','ColourCoatingCoverage7SideOne',
				'ColourCoatingType8SideOne', 'ColourCoatingColour8SideOne','ColourCoatingCoverage8SideOne',
				'ColourCoatingType9SideOne', 'ColourCoatingColour9SideOne','ColourCoatingCoverage9SideOne',

				'ColourCoatingType1SideTwo', 'ColourCoatingColour1SideTwo','ColourCoatingCoverage1SideTwo',
				'ColourCoatingType2SideTwo', 'ColourCoatingColour2SideTwo','ColourCoatingCoverage2SideTwo',
				'ColourCoatingType3SideTwo', 'ColourCoatingColour3SideTwo','ColourCoatingCoverage3SideTwo',
				'ColourCoatingType4SideTwo', 'ColourCoatingColour4SideTwo','ColourCoatingCoverage4SideTwo',
				'ColourCoatingType5SideTwo', 'ColourCoatingColour5SideTwo','ColourCoatingCoverage5SideTwo',
				'ColourCoatingType6SideTwo', 'ColourCoatingColour6SideTwo','ColourCoatingCoverage6SideTwo',
				'ColourCoatingType7SideTwo', 'ColourCoatingColour7SideTwo','ColourCoatingCoverage7SideTwo',
				'ColourCoatingType8SideTwo', 'ColourCoatingColour8SideTwo','ColourCoatingCoverage8SideTwo',
				'ColourCoatingType9SideTwo', 'ColourCoatingColour9SideTwo','ColourCoatingCoverage9SideTwo',
				'BleedLeft','BleedRight','BleedTop','BleedBottom','rdbColourBar','txtCropMarkSpace',
				'GroupPageQuantity','OverrideGroupPageQuantity','txtServiceDescription','rdbTemplateType',
				'rdbPanels','PocketSize','chkPocketLeft','chkPocketCenter','chkPocketRight',
				'txtWidth','txtHeight','txtFinalWidth','txtFinalHeight','chkOverrideDimensions','txtQuantity1','txtQuantity2','txtQuantity3',
				) {
#$log->debug("Group $type : $spec " .$$param{$spec.$group_id});
			
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, $spec, $$param{$spec.$group_id} ) if exists $$param{$spec.$group_id};
		} # end foreach spec
		foreach my $spec ( 
				'chkCyanSideOne','chkMagentaSideOne','chkYellowSideOne','chkBlackSideOne', 'chkProcessColourSideOne',
				( map { 'chkColourCoating'.$_.'SideOne' } ( 1 .. 9 ) ),
				'chkCyanSideTwo','chkMagentaSideTwo','chkYellowSideTwo','chkBlackSideTwo', 'chkProcessColourSideTwo',
				( map { 'chkColourCoating'.$_.'SideTwo' } ( 1 .. 9 ) ),
		) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, $spec, $$param{$spec.$group_id} );
		} # end foreach spec
	} # end foreach signature

	my $old_bindery_type = get_book_type( $Project );
	if ( $old_bindery_type and ($$param{rdbTemplateType} ne $old_bindery_type) and $$services{$old_bindery_type} ) {
		foreach ( @{$$services{$old_bindery_type}} ) {
			openprint::print_project::delete_service( $Project, $_ );
		} # end foreach
		delete $$services{$old_bindery_type};
	} # end if

	if ( ! $$services{NoBindery} ) {
$log->debug("No Nobindery");
		if ( $$param{rdbTemplateType} ) {
# Insert the desired Bindery Type
			if ( ( ! $$services{$$param{rdbTemplateType}} ) and openprint::ServiceType->find_one( name=> $$param{rdbTemplateType} ) ) {
				next if $$services{$$param{rdbTemplateType}};
				push @{$$services{$$param{rdbTemplateType}}}, $Project->add_service( $$param{rdbTemplateType} );
			} # end if

			if ( sets::isin( $$param{rdbTemplateType}, ('SaddleStitching','LoopStitching','PerfectBound','Unbound') ) ) {
# Saddle and Loop Stitching requires Folding
				push @{$$services{Folding}}, $Project->add_service( 'Folding' ) if ! $$services{Folding};
				push @{$$services{Cutting}}, $Project->add_service( 'Cutting' ) if ! $$services{Cutting};
			} # end if
		} # end if
	} # end if
	$Project->unlock();
	sql::end_transaction( $dbh, $ac );
} # end sub multipage_signatures

sub get_book_type {
	my ( $Project ) = @_;
	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
	my $services = $Project->services();

# the way we cut down the book depends on how it is being bound, so we need this for the signature information.
	foreach my $service ( 'SaddleStitching', 'LoopStitching', 'PerfectBound','SpinePaste','Spiral','MetalCoil','PlasticCoil','DoubleLoopWire','Cerlox','Unbound' ) {
		
		if ( $$services{$service} ) {
			return $service;
		} # end if
	} # end foreach
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	if ( $$printing_specs{rdbTemplateType} eq 'PerfectBound' ) {
		return 'PerfectBound';
	} # end if
	return;
} # end sub get_book_type


sub publication_pages {
	my ( $r, $log, $dbh, $variable ) = @_;
    my $service_index = $openprint::param{ServiceIndex};
    my $project_index = $openprint::param{ProjectIndex};
	$project_index = $openprint::session{project_id} if ! $project_index;
	$log->debug("********************************** STARTING MULTIPAGE PUBLICATION PAGES *******************************");

	@{$$variable{RunStyleOptions}} = ( 'Sheet Work', 'Sheet Work', 'Work & Turn', 'Work & Turn', 'Work & Tumble', 'Work & Tumble', 'Perfecting','Perfecting','Web','Web');
	
	my $Project = new openprint::Project( $project_index );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $type = $$sig_specs{Group};
$log->error("No Group!") if ! $type;
		foreach my $spec ( 
				'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight','ddmStockGroup','ddmStockQuality',
				'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight',
				'txtSpecificStockWidth','txtSpecificStockHeight','txtSpecificStockCalliper',
				'rdbSuppliedStock','rdbSpecificStock','StockType',
				'CustomSheetDoubleSided', 'CustomStockPrice','txtCustomMWeight','txtStockGSM','CustomStockPriceUnits',
				'basis_width','basis_height','basis_mweight','StockGrade',
				'minimum_order', 'sheets_per_package', 'full_packages',
				'chkCyanSideOne','chkMagentaSideOne','chkYellowSideOne','chkBlackSideOne', 'chkProcessColourSideOne',
				'chkColourCoating1SideOne', 'ColourCoatingType1SideOne', 'ColourCoatingColour1SideOne','ColourCoatingCoverage1SideOne',
				'chkColourCoating2SideOne', 'ColourCoatingType2SideOne', 'ColourCoatingColour2SideOne','ColourCoatingCoverage2SideOne',
				'chkColourCoating3SideOne', 'ColourCoatingType3SideOne', 'ColourCoatingColour3SideOne','ColourCoatingCoverage3SideOne',
				'chkColourCoating4SideOne', 'ColourCoatingType4SideOne', 'ColourCoatingColour4SideOne','ColourCoatingCoverage4SideOne',
				'chkColourCoating5SideOne', 'ColourCoatingType5SideOne', 'ColourCoatingColour5SideOne','ColourCoatingCoverage5SideOne',
				'chkColourCoating6SideOne', 'ColourCoatingType6SideOne', 'ColourCoatingColour6SideOne','ColourCoatingCoverage6SideOne',
				'chkColourCoating7SideOne', 'ColourCoatingType7SideOne', 'ColourCoatingColour7SideOne','ColourCoatingCoverage7SideOne',
				'chkColourCoating8SideOne', 'ColourCoatingType8SideOne', 'ColourCoatingColour8SideOne','ColourCoatingCoverage8SideOne',
				'chkColourCoating9SideOne', 'ColourCoatingType9SideOne', 'ColourCoatingColour9SideOne','ColourCoatingCoverage9SideOne',
				'chkCyanSideTwo','chkMagentaSideTwo','chkYellowSideTwo','chkBlackSideTwo', 'chkProcessColourSideTwo',
				'chkColourCoating1SideTwo', 'ColourCoatingType1SideTwo', 'ColourCoatingColour1SideTwo','ColourCoatingCoverage1SideTwo',
				'chkColourCoating2SideTwo', 'ColourCoatingType2SideTwo', 'ColourCoatingColour2SideTwo','ColourCoatingCoverage2SideTwo',
				'chkColourCoating3SideTwo', 'ColourCoatingType3SideTwo', 'ColourCoatingColour3SideTwo','ColourCoatingCoverage3SideTwo',
				'chkColourCoating4SideTwo', 'ColourCoatingType4SideTwo', 'ColourCoatingColour4SideTwo','ColourCoatingCoverage4SideTwo',
				'chkColourCoating5SideTwo', 'ColourCoatingType5SideTwo', 'ColourCoatingColour5SideTwo','ColourCoatingCoverage5SideTwo',
				'chkColourCoating6SideTwo', 'ColourCoatingType6SideTwo', 'ColourCoatingColour6SideTwo','ColourCoatingCoverage6SideTwo',
				'chkColourCoating7SideTwo', 'ColourCoatingType7SideTwo', 'ColourCoatingColour7SideTwo','ColourCoatingCoverage7SideTwo',
				'chkColourCoating8SideTwo', 'ColourCoatingType8SideTwo', 'ColourCoatingColour8SideTwo','ColourCoatingCoverage8SideTwo',
				'chkColourCoating9SideTwo', 'ColourCoatingType9SideTwo', 'ColourCoatingColour9SideTwo','ColourCoatingCoverage9SideTwo',
				'CyanSpotSideOneCoverage', 'MagentaSpotSideOneCoverage', 'YellowSpotSideOneCoverage', 'BlackSpotSideOneCoverage',
				'CyanSideOneCoverage', 'MagentaSideOneCoverage', 'YellowSideOneCoverage', 'BlackSideOneCoverage',
				'CyanSpotSideTwoCoverage', 'MagentaSpotSideTwoCoverage', 'YellowSpotSideTwoCoverage', 'BlackSpotSideTwoCoverage',
				'CyanSideTwoCoverage', 'MagentaSideTwoCoverage', 'YellowSideTwoCoverage', 'BlackSideTwoCoverage',
				'BleedLeft','BleedRight','BleedTop','BleedBottom','rdbColourBar','txtCropMarkSpace',
				'GroupPageQuantity','txtServiceDescription',
				'txtSignatureType','rdbTemplateType','pages_supplied','supplied_format',
				'rdbPanels','PocketSize','chkPocketLeft','chkPocketCenter','chkPocketRight',
				'txtWidth','txtHeight','chkOverrideDimensions','txtQuantity1','txtQuantity2','txtQuantity3',
				) {
			$$variable{$spec.$type} = $$sig_specs{$spec} if $$sig_specs{$spec} and ! $$variable{$spec.$type};
#$openprint::log->debug("$spec . $type = $$variable{$spec.$type}");
		} # end foreach spec
	} # end foreach ss_id

	if ( ! $$variable{rdbTemplateType} ) {
		$$variable{rdbTemplateType} = get_book_type( $project_index );
	} # end if

} # end sub publication_pages

sub get_insert_specs {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;
	$log->debug("************************** GETTING INSERT SPECS **************************");
	if ( $$variable{txtInsertQuantity} eq '' ) {
		$_ = "SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex='$project_index' AND strName='txtInsertQuantity'";
		( $$variable{txtInsertQuantity} ) = sql::execute( $log, $dbh, $_ );
	} # end if
	for (my $x = 1; $x <= $$variable{txtInsertQuantity}; $x += 1 ) {
		push @{$$variable{INSERTS}}, $x, $$variable{"txtInsertPage1$x"}, $$variable{"txtInsertPage2$x"}, $$variable{"txtFinalWidth$x"}, $$variable{"txtFinalHeight$x"};
	} # end for
	$$variable{txtPockets} = $$variable{SignatureCount} + $$variable{txtInsertQuantity};

} # end sub

sub get_finished_weight {
	my ( $project_index ) = @_; 
	my $project_weight;

	my $Project = new openprint::Project( $project_index );
	# We do a weird thing with qty_index here, becasue all quantities should have the same weight, but may be calculated diferent ways, so we run through them until we get a valid weight.

# calculate project weight
	foreach my $qty_index ( $Project->quantity_indexes() ) {

		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			next if $$sig_specs{txtSignatureType} and ! $$sig_specs{'PageQuantity'.$qty_index};
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			my $sig_weight = openprint::Estimating::Printing::get_weight( $Project, $sig_specs, $qty_index );
			if ( ! $sig_weight ) {
				# unable to get weight for a sig, must recalc printing service
$openprint::log->debug("Unable to get sig_weight for signature $$sig_specs{SignatureIndex}");
				return 0;
			} # end if
			$project_weight += $sig_weight;
		} # end foreach signature_service_index
		last;
	} # end foreach qty_index
	#$openprint::log->debug("Project Weight: $project_weight : Marked Up: ". $project_weight * (1+$openprint::config{WeightMarkup}/100));
	
	# This 1.1 was actually requested by Amin.  So it was pretty random, but then I thought abotu it, and our weight calculations don't take into account the weight of the ink, etc... so it may actually be not too off.... would love to see some real figures on it.
	return $project_weight * (1+$openprint::config{WeightMarkup}/100);
} # end sub get_finished_weight

# Finished calliper for books will be calculated from the first qty.  All three should be the same.
sub get_finished_calliper { 
	my ( $project_index ) = @_; 
	my $Project = new openprint::Project( $project_index );
	return $Project->calliper();
} # end sub get_finished_calliper

sub get_quantities {
	my ( $variable, $project_index) = @_;
	if ( ! $$variable{QUANTITIES} ) {
		my $Project = new openprint::Project( $project_index );
		my @qtys = $Project->quantities();
		my $columns = 0;
		for ( my $index = 0; $index < @qtys; $index += 1 ) {
			$$variable{QUANTITIES} .= " quantities[$index] = '$qtys[$index]'; \n";
			$$variable{'QUANTITY'.($index+1)} = $qtys[$index];
			$$variable{'txtQuantity'.($index+1)} = $qtys[$index];
			$columns += 1 if $qtys[$index];
		} # end for
		$$variable{Columns} = 'One' if $columns == 1;
		$$variable{Columns} = 'Two' if $columns == 2;
		$$variable{Columns} = 'Three' if $columns == 3;
	} # end if
} # end sub get_quantities

1;
__END__
