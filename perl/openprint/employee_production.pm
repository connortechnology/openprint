package openprint::employee_production;
use strict;
use Date::Calc qw(Add_Delta_Days Date_to_Days check_date );
use MIME::QuotedPrint;

use openprint ();

require openprint::Project;
require openprint::order;
require openprint::project;
require openprint::service;
require openprint::Equipment;
require openprint::employee_schedule;
require openprint::bindery_schedule;
require openprint::press_schedule;

require sql;
require openprint::MXML;

sub print_overview {
	press_schedule( @_ );
} 

sub press_schedule {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $openprint::param{'btnFunction'} eq 'JumpToDate' ) {
		my $service_index = $openprint::param{'ServiceIndex'};
		my $date = $openprint::param{"ScheduleDate-$service_index"};
		sql::update( $log, $dbh, 'Schedule', "ServiceIndex=$service_index", 'starttime', $date );
	} elsif ( $openprint::param{'btnFunction'} eq 'SetDueDate' ) {
		my $service_index = $openprint::param{'ServiceIndex'};
		my $date = $openprint::param{"ScheduleDate-$service_index"};
		my ( $project_index ) = sql::execute( $log, $dbh, q{SELECT ProjectIndex FROM Schedule WHERE ServiceIndex=?}, $service_index );
		my $Project = new openprint::Project( $project_index );
		$Project->due_date( $date );
		$Project->save();
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Duedate changed to $date from Print Schedule" );
	} elsif ( $openprint::param{'btnFunction'} eq 'ApproveJob' ) {
		my $service_index = $openprint::param{'ServiceIndex'};
		my $project_index = $openprint::param{'ProjectIndex'};
		my $Project = new openprint::Project( $project_index );
		openprint::employee_project::mark_proofs_approved( $log, $dbh, $variable, $project_index );
		sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND strStatus='Waiting For Customer Approval'", 'strStatus', 'Complete' );
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Approved from print overview' );
		$Project->update_status();
	} elsif ( $openprint::param{'btnFunction'} eq 'BumpJob' ) {
		my $service_index = $openprint::param{'ServiceIndex'};
		my $project_index = $openprint::param{'ProjectIndex'};
		my $Project = new openprint::Project( $project_index );
		my ( $starttime ) = sql::execute( $log, $dbh, q{SELECT starttime FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, $project_index, $service_index );
		my ( $year, $month, $day, $hours, $minutes, $seconds ) = $starttime =~ /(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/;
		$seconds = 0;
		$minutes = 0;
		if ( $hours < 12 ) {
			$hours = 12;
		} else {
			( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, 1 );
			$hours = 0;
		} # end if
		if ( $year ) {
			my $starttime = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', $year, $month, $day, $hours, $minutes, $seconds );
			sql::update( $log, $dbh, 'Schedule', "ProjectIndex=$project_index AND ServiceIndex=$service_index", 'starttime', $starttime );
			$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Job bumped to next shift: $starttime " );
		} # end if

	} elsif ( $openprint::param{'btnFunction'} eq 'CompleteJob' ) {
# Actually this is complete Signature
		my $service_index = $openprint::param{'ServiceIndex'};
		my $project_index = $openprint::param{'ProjectIndex'};
		my $Project = new openprint::Project( $project_index );
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Job Completed from print schedule." );
		complete_signature( $log, $dbh, $variable, $project_index, $service_index );
		$Project->update_status();
	} elsif ( $openprint::param{'btnFunction'} eq 'RemoveJob' ) {
		my $service_index = $openprint::param{'ServiceIndex'};
		my $project_index = $openprint::param{'ProjectIndex'};
		sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, $project_index, $service_index );
		my $Project = new openprint::Project( $project_index );
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Job removed from print schedule." );
	} # end if
	openprint::employee_schedule::add_missing_jobs_to_schedule( $log, $dbh );
#openprint::employee_schedule::update_late_jobs( $log, $dbh );
} # end sub press_schedule

sub bindery_overview {
	my ( $r, $log, $dbh, $variable ) = @_;

	my @time = localtime(time);
	my ( $start_year, $start_month, $start_day ) = Date::Calc::Add_Delta_Days( $time[5], $time[4]+1, $time[3], -6 );
	my ( $end_year, $end_month, $end_day ) = Date::Calc::Add_Delta_Days( $time[5], $time[4]+1, $time[3], 14 );
	$$variable{'Today'} = sprintf('%.4d-%.2d-%.2d', $time[5]+1900, $time[4]+1, $time[3] );
	ssi::get_start_end_dates( $log, $dbh, $variable,
			( defined $r->param('ddmStartYear') ? $r->param('ddmStartYear') : $start_year+1900 ),
			( defined $r->param('ddmStartMonth') ? $r->param('ddmStartMonth') : $start_month ),
			( defined $r->param('ddmStartDay') ? $r->param('ddmStartDay') : $start_day ),
			( defined $r->param('ddmEndYear') ? $r->param('ddmEndYear') : $end_year+1900 ),
			( defined $r->param('ddmEndMonth') ? $r->param('ddmEndMonth') : $end_month ),
			( defined $r->param('ddmEndDay') ?$r->param('ddmEndDay') : $end_day ),
			);

	my @possible_statuses = ( 'Approved','Printed','Complete' );
	my @statuses = $r->param('Status') ? sets::intersection( @possible_statuses , $r->param('Status') ) : ( 'Printed' );
	$$variable{'Status'} = ssi::make_select( [ map { $_, $_ } @possible_statuses ], [@statuses] );

	my %services = (
			'Cut'               => [ 'Cutting' ],
			'Fold, Perf, Score' => [ 'Folding', 'Perforating', 'Scoring' ],
			'Stitch'            => [ 'SaddleStitching', 'LoopStitching' ],
			'Drill'             => [ 'Drilling' ],
			'No Bindery'        => [ 'NoBindery' ],
			);
	my @Services;
	@{$$variable{'DisplayServices'}} = sort keys %services;

	foreach my $service ( keys %services ) {
		if ( ! defined $r->param('btnFunction') or $r->param('chkViewServices'.$service) eq 'checked' ) {
			$$variable{'chkViewServices'.$service} = 'checked';
			push @{$$variable{'Services'}}, $service;
			push @Services, @{$services{$service}};
		} # end if
	} # end foreach

	$_ = "SELECT tbl_Projects.Index, Orders.Index, tbl_Projects.lngDocketNumber, (SELECT strName FROM Company WHERE Company.Index=tbl_Projects.CompanyIndex)";
	$_ .= ", intQuantityIndex, duedate, tbl_Projects.strStatus\n";
	$_ .=" FROM tbl_Projects, Order_Contents, Orders";
	$_ .= " WHERE tbl_Projects.strStatus IN ( '". join("','", @statuses ) ."' )";
	$_ .= " AND Orders.Index=Order_Contents.OrderIndex AND Orders.strStatus='In Production'";
	$_ .= " AND tbl_Projects.Index = Order_Contents.lngProjectIndex";
	$_ .= " AND duedate BETWEEN '$$variable{'StartDate'}' AND '$$variable{'EndDate'}'";
	$_ .= " AND Orders.lngEmployeeID=".$r->param('ddmSalesRep') if $r->param('ddmSalesRep');
	$_ .= " ORDER BY duedate";
	my @projects = sql::execute( $log, $dbh, $_ );

	@{$$variable{'Projects'}} = ();
	while ( my ( $project_index, $order_id, $docket, $company, $qty_index, $date_required, $status ) = splice @projects, 0, 7 ) {
		my %times;

		my $Project = new openprint::Project( $project_index );
		my %service_indices = $Project->get_services();
		my %statuses = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $project_index );
		my $complete = 1;
		foreach my $service_type ( sets::intersection( @Services, keys %service_indices ) ) {
			if ( sets::isin( $service_type, ['LoopStitching', 'SaddleStitching'] ) ) {
				foreach my $service_index ( @{$service_indices{$service_type}} ) {
					if ( $statuses{$service_index} eq 'Complete' ) {
						$times{'Stitch'} = 'done';
					} else {
						my ( $runtime) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'txtRunTime'.$qty_index );
						$times{'Stitch'} += int $runtime;
						$complete = 0;
					} # end if
				} # end foreach
			} elsif ( sets::isin( $service_type,'Folding','Perforating','Scoring' ) ) {
				foreach my $service_index ( @{$service_indices{$service_type}} ) {
					if ( $statuses{$service_index} eq 'Complete' ) {
						$times{'Fold, Perf, Score'} = 'done';
					} else {
						my ($runtime) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'txtRunTime'.$qty_index );
						$times{'Fold, Perf, Score'} += int $runtime;
						$complete = 0;
					} # end if
				} # end foreach
			} elsif ( $service_type eq 'Cutting' ) {
				foreach my $service_index ( @{$service_indices{$service_type}} ) {
					if ( $statuses{$service_index} eq 'Complete' ) {
						$times{'Cut'} = 'done';
					} else {
						my ($runtime) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'txtRunTime'.$qty_index );
						$times{'Cut'} += int $runtime;
						$complete = 0;
					} # end if
				} # end if
			} elsif ( $service_type eq 'Drilling' ) {
				foreach my $service_index ( @{$service_indices{$service_type}} ) {
					if ( $statuses{$service_index} eq 'Complete' ) {
						$times{'Drill'} = 'done';
					} else {
						my ($runtime) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'txtRunTime'.$qty_index );
						$times{'Drill'} += int $runtime;
						$complete = 0;
					} # end if
				} # end if
			} # end if
		} # end foreach
        next if $complete;

#my %printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $service_indices{''} );
		my %printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, openprint::project::get_project_type_service_index( $log, $dbh, $project_index ) );

		my @BinderyServices = ();
		if ( my %bindery_services = openprint::print_project::get_services_in_category( $log, $dbh, $project_index, 'Bindery') ) {
			$_ = 'SELECT name FROM Service_Types WHERE id IN ( ' . join(',', @bindery_services{keys %bindery_services} ) . ')';
			@BinderyServices = sql::execute( $log, $dbh, $_ );
		} # end if

		if ( ! $printing_specs{'txtQuantity'.$qty_index} ) {
			$printing_specs{'txtQuantity'.$qty_index} = $Project->quantity( $qty_index );
		} # end if
		my $description = $printing_specs{'txtQuantity'.$qty_index};

		if ( ! @BinderyServices ) {
			$description .= ' Ship Flat';
		} elsif ( sets::isin( 'No Bindery', \@BinderyServices ) ) {
			$description .= ' Ship Flat';
		} else {
			if ( ! @service_indices{'SaddleStitching','Loop Stitching'} ) {
				if ( $service_indices{'Cutting'} and ! $service_indices{'Folding'} ) {
					$description .= ', ' . $printing_specs{'txtFinalWidth'} . 'x'  . $printing_specs{'txtFinalHeight'};
				} # end if
				if ( $service_indices{'Folding'} ) {
					$description .= ', '. $printing_specs{'txtWidth'} . 'x' . $printing_specs{'txtHeight'} . ' > ' . $printing_specs{'txtFinalWidth'} . 'x'  . $printing_specs{'txtFinalHeight'};
				} # end if
			} # end if

			if ( $printing_specs{'txtTotalPageQuantity'} ) {
				$description .= ', ';
				if ( $printing_specs{'rdbCover'} eq 'DifferentCover' ) {
					$description .= $printing_specs{'txtTotalPageQuantity'} -4 . 'pp+C';
				} else {
					$description .= $printing_specs{'txtTotalPageQuantity'} . 'pp';
				} # end if
				$description .= ', ' . $printing_specs{'txtFinalWidth'} . 'x' . $printing_specs{'txtFinalHeight'};

				if ( $printing_specs{'txtInsertQuantity'} ) {
					$description .= ' with ' . $printing_specs{'txtInsertQuantity'} . ' Inserts Page ' . $printing_specs{'Page1'} . ' and page ' . $printing_specs{'Page2'};
				} # end if
			} # end if
		} # end if

		if ( $printing_specs{'txtSignatureQuantity'} ) {
			$description .= $printing_specs{'txtSignatureQuantity'} . '-';

			if ( $printing_specs{'txtSignatureQty2Page'} ) { $description .= '2pp' };
			if ( $printing_specs{'txtSignatureQty4Page'} ) { $description .= '4pp' };
			if ( $printing_specs{'txtSignatureQty8Page'} ) { $description .= '8pp' };
			if ( $printing_specs{'txtSignatureQty12Page'} ) { $description .= '12pp' };
			if ( $printing_specs{'txtSignatureQty16Page'} ) { $description .= '16pp' };
			if ( $printing_specs{'txtSignatureQty20Page'} ) { $description .= '20pp' };
			if ( $printing_specs{'txtSignatureQty24Page'} ) { $description .= '24pp' };
			if ( $printing_specs{'txtSignatureQty32Page'} ) { $description .= '32pp' };
			if ( $printing_specs{'txtSignatureQtySingleGateFolded'} ) { $description .= 'Single Gate Folded' };
			if ( $printing_specs{'txtSignatureQtyDoubleGateFolded'} ) { $description .= 'Double Gate Folded' };
		} # end if

		if ( sets::intersection( @Services, keys %service_indices ) ) {
			push @{$$variable{'Projects'}}, $project_index, $order_id, $docket, $company, $description,$date_required;
			foreach my $service_type ( @{$$variable{'Services'}} ) {
				if ( defined $times{$service_type} ) {
					if ( $times{$service_type} ne 'done' ) {
						$times{$service_type} = int($times{$service_type}/360) . ':' . int(($times{$service_type}%360)/60);
					} # end if
				} else {
					$times{$service_type} = 'n/a';
				} # end if
				push @{$$variable{'Projects'}}, $times{$service_type};
			} # end foreach
		} # end if
	} # end while

	if ( $r->param('btnFunction') eq 'Download in CSV format' ) {
		my @header = ('Docket #','Company Name', 'Description', 'Date Required');
		foreach my $service_type ( @{$$variable{'Services'}} ) {
			push @header, $service_type;
		} # end foreach
		my @data;
		while ( @{$$variable{'Projects'}} ) {
			my ( $project_index, $order_id, $docket, $company, $description, $date_required ) = splice @{$$variable{'Projects'}}, 0, 6;
			push @data, $docket, $company, $description, $date_required;
			foreach my $service_type ( @{$$variable{'Services'}} ) {
				push @data, shift @{$$variable{'Projects'}};
			} # end foreach
		} # end while
		misc::export_csv( $r, $log, $variable, 'bindery_overview.csv', \@header, \@data );
	} # end if
} # end sub bindery_overview

sub projects {
	my ( $r, $log, $dbh, $variable ) = @_;

	my @projects;

	my $startdocket = $openprint::param{'StartDocket'};
	my $enddocket = $openprint::param{'EndDocket'};
	my $project_index = $openprint::param{'Project'};
	my $order_id = $openprint::param{'OrderID'};

	$startdocket =~ s/\D//g;
	$enddocket =~ s/\D//g;
	$project_index =~ s/\D//g;
	$order_id =~ s/\D//g;

	if ( $openprint::param{'btnFunction'} eq 'Go' ) {
		if ( $project_index ) {
			@projects = ( new openprint::Project( $project_index ) );
		} elsif ( $order_id ) {
			my $Order = new openprint::Order( $order_id );
			@projects = $Order->Projects();
		} elsif ( $startdocket and $enddocket ) {
			@projects = openprint::Project::find( 'docket_start'=>$startdocket, 'docket_end' => $enddocket );
		} elsif ( $startdocket ) {
			@projects = openprint::Project::find( 'docket'=>$startdocket );
		} elsif ( $enddocket ) {
			@projects = openprint::Project::find( 'docket'=>$enddocket );
		} # end if
		if ( @projects == 1 ) {
			$order_id = $projects[0]->order_id();
			$$variable{'Redirect'} = '/employee/production/project_view.html';
			$openprint::param{'OrderID'} = $order_id;
			$openprint::param{'ProjectIndex'} = @projects[0]->id();
			return;
		} # end if
	} # end if

	$$variable{'txtDocket'} = $openprint::param{'txtDocket'};

} # end sub list_current

sub project_view {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $project_index = $openprint::param{'ProjectIndex'};
	my $Project = new openprint::Project( $project_index );
	my $order_id = $openprint::param{'OrderID'};
	if ( ! $order_id ) {
		if ( $openprint::param{'Docket'} ) {
			( $order_id ) = sql::execute( $log, $dbh, q{SELECT Index FROM Orders WHERE Index IN ( SELECT DISTINCT OrderIndex FROM Order_Contents WHERE lngProjectIndex=? ) AND lngDocketNumber=?}, $project_index, $openprint::param{'Docket'} );
		} # end if
	} # end if
	$$variable{'OrderID'} = $order_id;

	if ( $openprint::param{'btnFunction'} eq 'Export JDF' ) {
		misc::export( $r, $log, $variable, 'Docket-'.$Project->docket().'-Metrix.jdf', [$Project->jdf()->toString()] );
	} elsif ( $openprint::param{'btnFunction'} eq 'Export MXML' ) {
		misc::export( $r, $log, $variable, 'Docket-'.$Project->docket().'-Metrix.mxml', [new openprint::MXML($Project)->toString()] );
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		my $service_index = $openprint::param{'ServiceIndex'};
		my $status = openprint::service::get_status( $log, $dbh, $service_index, $project_index );

		my ( $service_type ) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'ServiceType' );
		if ( $service_type eq 'AdditionalSignature' ) {
			my $complete = is_sig_complete( $r, $log, $dbh, $project_index, $service_index );
			if ( $complete ) {
# Run through each of the signatures and if everyone is complete, then set the printing service to complete
				foreach my $signature_service_index ( $Project->signatures() ) {
					next if $signature_service_index == $service_index;
					my $status = openprint::service::get_status( $log, $dbh, $signature_service_index, $project_index );
					if ( $status ne 'Complete' ) {
						$complete = 0;
					} # end if
				} # end foreach
			} # end if

			my $printing_service_index = openprint::print::get_printing_service( $log, $dbh, $project_index );
			if ( $complete ) {
				sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND lngServiceIndex=$printing_service_index", 'strStatus', 'Complete' );	
			} else {
				sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND lngServiceIndex=$printing_service_index", 'strStatus', 'Ordered' );	
			} # end if

		} elsif ( sets::isin( $service_type,[ 'Proofs', 'FilmStripping' ] ) ) {

			# Store Usepress
			foreach my $signature_service_index ( $Project->signatures() ) {
				my %printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $signature_service_index );
				next if ! $openprint::param{'UsePress-'.$printing_specs{'SignatureIndex'}};
				next if $openprint::param{'UsePress-'.$printing_specs{'SignatureIndex'}} eq $printing_specs{'UsePress'};

				if ( $r->param("UsePress-$printing_specs{'SignatureIndex'}") ne $printing_specs{'UsePress'} ) {
					openprint::service::insert_service_spec( $log, $dbh, $project_index, $signature_service_index, 'UsePress', $r->param("UsePress-$printing_specs{'SignatureIndex'}") );
					my $runtime = openprint::service::get_runtime( $log, $dbh, $project_index, $signature_service_index );

					my @Equipment = openprint::Equipment::find('strid'=>$openprint::param{"UsePress-$printing_specs{'SignatureIndex'}"} );
					next if ! @Equipment;

					sql::update( $log, $dbh, 'Schedule', ['ServiceIndex=?', $signature_service_index],
							'Equipment_id', $Equipment[0]->id(), 
							'RunTime', "$runtime minutes",
							);
				} # end if
			} # end foreach signature_service_index

			if ( $service_type eq 'FilmStripping' ) {
				if ( $openprint::param{'rdbComplete'} eq 'Yes' ) {
					if ( ! Date::Calc::check_date( @openprint::param{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'} ) ) {
						( $_ ) = sql::execute( $log,  $dbh, q{SELECT strEmployeeURL FROM Service_Types WHERE name='FilmStripping'});
						$$variable{'Redirect'} = '/employee/proj/'.$_;
						$$variable{'ErrorMessage'} = 'There was an error saving the DueDate.  Please check that a real date was selected.';
						$r->param( 'rdbComplete' => 'No' );
					} else {
						my $duedate = join('-', @openprint::param{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'} );
						$Project->due_date( $duedate );
						$Project->save();
						$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Duedate changed to $duedate" );

						if ( $openprint::config{'Smart Schedule'} eq 'Y' ) {
							foreach my $signature_service_index ( $Project->signatures() ) {
								my %sig_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $signature_service_index );
								if ( my @Equipment = openprint::Equipment::find( 'strid'=>$sig_specs{'UsePress'} ) ) {
								openprint::employee_schedule::insert( $log, $dbh, $project_index, $signature_service_index, $Equipment[0]->id() );
								} # end if
							} # end foreach signature_service_index
						} # end if

						sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], 'strStatus', 'Approved' );
					} # end if
				} else { # Not Complete
					if ( $status ne 'Ordered' ) {
# Make sure we don't get approved without complete, because they can't unapprove
						$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Filmstripping Ordered from $status" );
						sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex='$project_index' AND lngServiceIndex='$service_index'", 'strStatus', 'Ordered' );
					} # end if
				} # end if Complete or NOT
			} elsif ( $service_type eq 'Proofs' ) {
				if ( $openprint::param{'rdbComplete'} eq 'Yes' ) {
# Only send if completion date has changed
					my ( $c_date, $complete ) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'CompletionDate','rdbComplete' );
					if ( $complete ne $openprint::param{'rdbComplete'} and $c_date ne $openprint::param{'CompletionDate'} ) {
						send_proofs_complete_email( $r, $log, $dbh, $variable, $project_index, $order_id );
					} # end if completion date has changed

					if ( $openprint::param{'ScheduleForPress'} eq 'Y' ) {
						my $ac = sql::start_transaction( $dbh );

						foreach my $s_s_id ( $Project->signatures() ) {
							my %sig_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $s_s_id );
							sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ServiceIndex=?}, $s_s_id );
							my $runtime = openprint::service::get_runtime( $log, $dbh, $project_index, $s_s_id );
							if ( my @Equipment = openprint::Equipment::find('strid'=>$sig_specs{'UsePress'}) ) {
								$_ = sql::insert( $log, $dbh, 'Schedule', 'ProjectIndex', $project_index, 'ServiceIndex', $s_s_id, 'Equipment_id', $Equipment[0]->id(),'StartTime', undef, 'RunTime', ($runtime ? "$runtime minutes" : undef ) );
								if ( $_ ) {
									$$variable{'error'} .= 'Error adding to press schedule: ' . $_;
								} else {
									$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Added Form $sig_specs{'SignatureIndex'} to pending press schedule." );

								} # end if
							} # end if
						} # end foreach
						sql::end_transaction( $dbh, $ac );
					} # end if

					if ( $openprint::param{'rdbApproved'} eq 'Y' or ! defined $openprint::param{'rdbApproved'} ) {
						if ( ! Date::Calc::check_date( @openprint::param{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'} ) ) {
							( $_ ) = sql::execute( $log,  $dbh, "SELECT strEmployeeURL FROM Service_Types WHERE name='Proofs'");
							$$variable{'Redirect'} = '/employee/proj/'.$_;
							$$variable{'ErrorMessage'} = 'There was an error saving the DueDate.  Please check that a real date was selected.';
							$openprint::param{'rdbApproved'} = 'N';
						} else {
# It's a valid duedate
							my $duedate = sprintf('%.4d-%.2d-%.2d', @openprint::param{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'} );

							if ( $status ne 'Approved' ) {
								mark_proofs_approved( $log, $dbh, $variable, $project_index, $service_index, $status );
								send_proofs_approved_email( $r, $log, $dbh, $variable, $project_index, $order_id );
							} # end if
							if ( $duedate ne $Project->due_date() ) {
								$Project->due_date( $duedate );
								$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Duedate changed to $duedate" );
# Notify CSR
								send_duedate_change_notification( $r, $log, $dbh, $variable, $project_index, $order_id );
							} # end if
						} # end if
					} elsif ( $openprint::param{'rdbApproved'} eq 'N' ) { # NOT APPROVED
						if ( $status ne 'Proofs Out' and $status ne 'Waiting For Customer Approval' ) {
							$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Proofs Proofs Out from $status" );
							sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND lngServiceIndex=$service_index", 'strStatus', 'Proofs Out' );
						} # end if
					} # end if Approved
				} else { # Not Complete
# Make sure we don't get approved without complete, because they can't unapprove
					$openprint::param{'rdbApproved' => 'N'};
					$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Proofs Ordered from $status" );
					sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND lngServiceIndex=$service_index", 'strStatus', 'Ordered' );
				} # end if Complete Or NOT

			} # end if				
		} else { # A Service, But Not Film Stripping or Proofs
			if ( $openprint::param{'rdbComplete'} eq 'Yes' ) {
				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], 'strStatus', 'Complete' );

				my @ServiceTypes = openprint::ServiceType::find('name'=>$service_type);
				my $category = @ServiceTypes? @ServiceTypes[0]->category():'';
				if ( $category eq 'Bindery' ) {
					$_ = q{ SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=?
						 AND strName='ServiceType'
						 AND strValue IN ( SELECT name FROM Service_Types WHERE category = 'Bindery' )
						 AND lngServiceIndex IN ( SELECT lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=? AND strStatus != 'Complete' ) };
					if ( ! sql::execute( $log, $dbh, $_, $project_index, $project_index ) ) {
# If no more incomplete bindery services, then mark all packaging services complete
						$_ = q{SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=?  AND strName='ServiceType'
							 AND strValue IN ( SELECT name FROM Service_Types WHERE category = 'Packaging' )};
						foreach my $packaging_service_index ( sql::execute( $log, $dbh, $_, $project_index ) ) {
							sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $packaging_service_index], 'strStatus', 'Complete' );
						} # end foreach
					}  # end if
				} # end if Bindery
			} elsif ( $service_type ) { # rdbComplete == No
				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], 'strStatus', 'Ordered' );

			} # end if Complete or NOT
		} # end if FilmStripping, Proofs or other

		if ( $openprint::param{'TakeOver'} ) {
# Take Over
			$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Taken Over by '. $openprint::param{'Operator'} );
			if ( $openprint::param{'PickupDate'} ) {
				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], ['starttime', $openprint::param{'PickupDate'}, 'operator_id', $openprint::session{'user_id'} ] );
			} else {
				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], ['starttime', 'NOW()', 'operator_id', $openprint::session{'user_id'} ] );
			} # end if
		} # end if

# Save info
		my $ac = sql::start_transaction( $dbh );
		my %specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $service_index );
		if ( $specs{'ProjectType'} ) {
			my $complete = 1;

			foreach my $signature_service_index ( $Project->signatures() ) {
				my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );

				foreach my $param ( qw/txtEmployeeName txtEmployeeComments UsedStockBrand UsedStockFinish UsedStockColour UsedStockWeight UsedStockSheetSize UsedSheetQuantity ddmPressCompletionDateMonth ddmPressCompletionDateDay ddmPressCompletionDateYear rdbPressComplete UsedImposition UsedColumns UsedRows UsedDutchColumns UsedDutchRows UsedRunStyle UsePress/ ) {
					next if $$sig_specs{$param} eq $openprint::param{"$param-$$sig_specs{'SignatureIndex'}"};
					openprint::service::insert_service_spec( $log, $dbh, $project_index, $signature_service_index, $param, $openprint::param{"$param-$$sig_specs{'SignatureIndex'}"} );
				} # end foreach

				if ( ! is_sig_complete( $r, $log, $dbh, $project_index, $signature_service_index ) ) {
					$complete = 0;
				} elsif ( my @Equipment = openprint::Equipment::find('strid'=>$$sig_specs{'UsePress'}) ) {
					$Equipment[0]->update_schedule();
				} # end if
			} # end foreach signature_service_index

# There is now a set of press completion buttons for each signature
			if ( $complete ) {
				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], 'strStatus', 'Complete' );
				$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Printed from $status" );
# shuffle jobs on the print schedule

			} else {
				sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND lngServiceIndex=$service_index", 'strStatus', 'Ordered' );
				$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Ordered from $status" );
			} #nd if
		} elsif ( $service_type eq 'AdditionalSignature' ) {
			foreach my $param ( qw/txtEmployeeName txtEmployeeComments UsedStockBrand UsedStockFinish UsedStockColour UsedStockWeight UsedStockSheetSize UsedSheetQuantity ddmPressCompletionDateMonth ddmPressCompletionDateDay ddmPressCompletionDateYear rdbPressComplete UsedImposition UsedColumns UsedRows UsedDutchColumns UsedDutchRows UsedRunStyle UsePress/ ) {
				next if $specs{"$param-$specs{'SignatureIndex'}"} eq $openprint::param{"$param-$specs{'SignatureIndex'}"};
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, $param, $openprint::param{"$param-$specs{'SignatureIndex'}"} );
			} # end foreach

			if ( my @Equipment = openprint::Equipment::find( 'strid'=>$specs{'UsePress'} ) ) {
				$Equipment[0]->update_schedule();
			} # end if
		} else {

			my @do_not_save = ( 'btnFunction','ProjectIndex','ServiceIndex','order_id', 'ddmDueDateDay','ddmDueDateMonth','ddmDueDateYear','rdbApproved','Docket' );
			foreach my $param ( $r->param() ) {
				next if ( sets::isin_regx( $param, @do_not_save ) );
				next if $specs{$param} eq $openprint::param{$param};
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, $param, $openprint::param{$param} );
			} # end foreach
		} # end if

		openprint::project::update_status( $log, $dbh, $variable, $project_index );
		$order_id = $Project->order_id() if ! $order_id;
		openprint::order::update_order_status( $r, $log, $dbh, $order_id );
		sql::end_transaction( $dbh, $ac );
	} elsif ( $openprint::param{'btnFunction'} eq 'Shipped' ) {
		$Project->status_change( undef, undef, 'Shipped' );
	} elsif ( $openprint::param{'btnFunction'} eq 'Picked Up' ) {
		$Project->status_change( undef, undef, 'Picked Up' );
	} elsif ( $openprint::param{'btnFunction'} eq 'BinderyComplete' ) {
		$Project->status_change( undef, undef, 'BinderyComplete' );
	} elsif ( $openprint::param{'btnFunction'} eq 'Complete' ) {
		$Project->status_change( undef, undef, 'Complete' );
	} elsif ( $openprint::param{'btnFunction'} eq 'AddToBinderySchedule' ) {
		openprint::bindery_schedule::add_project( $Project );
	} elsif ( $openprint::param{'btnFunction'} eq 'Add Service' ) {

		if ( $openprint::param{'NewServiceType'} ) {
			my $ServiceType = new openprint::ServiceType( $openprint::param{'NewServiceType'} );
			my $new_service_index = openprint::print_project::insert_service( $log, $dbh, $project_index, $ServiceType->name() );

			if ( $ServiceType->name() eq 'AdditionalSignature' ) {
				$_ = q{SELECT MAX(strValue) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
				my ( $signature_count ) = sql::execute( $log, $dbh, $_, $project_index );
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'txtSignatureType', 'AdditionalSignature' );
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'txtServiceDescription', 'Additional Signature' );
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'SignatureIndex', ++$signature_count );
			} # end if
			$Project->add_to_log( @openprint::session{'company_id','user_id'}, sprintf( 'Added Service: %s', $ServiceType->name() ) );
		} elsif ( $openprint::param{'txtServiceName'} ) {
			
			my @ServiceTypes = openprint::ServiceType::find('name'=>'CustomService');
			if ( @ServiceTypes ) {

			my $ac = sql::start_transaction( $dbh );

			sql::insert( $log, $dbh, 'tbl_Project_Contents', 'lngProjectIndex', $project_index, 'strStatus', 'Waiting For Customer Approval', 'servicetype_id', $ServiceTypes[0]->id() );
			$_ = q{SELECT MAX(lngServiceIndex) FROM tbl_Project_Contents WHERE lngProjectIndex=?};
			my ( $service_index ) = sql::execute( $log, $dbh, $_, $project_index );
			sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
						'lngProjectIndex',  $project_index,
						'lngServiceIndex',  $service_index,
						'strName',          'ServiceType',
						'strValue',         'CustomService' ]);
			sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
						'lngProjectIndex',  $project_index,
						'lngServiceIndex',  $service_index,
						'strName',          'txtPrice1',
						'strValue',         misc::moneyfilter($openprint::param{'txtPrice'}) ]);
			sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
						'lngProjectIndex',  $project_index,
						'lngServiceIndex',  $service_index,
						'strName',          'txtPrice2',
						'strValue',         misc::moneyfilter($openprint::param{'txtPrice'}) ]);
			sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
						'lngProjectIndex',  $project_index,
						'lngServiceIndex',  $service_index,
						'strName',          'txtPrice3',
						'strValue',         misc::moneyfilter($openprint::param{'txtPrice'}) ]);
			sql::insert( $log, $dbh, 'tbl_Service_Specifications',[
					'lngProjectIndex',  $project_index,
					'lngServiceIndex',  $service_index,
					'strName',          'ServiceName',
					'strValue',         $openprint::param{'txtServiceName'}
					] );

			$Project->add_to_log( @openprint::session{'company_id','user_id'}, sprintf( 'Added Custom Line: %s, (%.2f)', @openprint::param{'txtServiceName','txtPrice'} ) );
			$Project->update_status( );
			openprint::order::update_order_status( $r, $log, $dbh, $order_id );

			sql::end_transaction( $dbh, $ac );
			} # end if
		} # end if NewServiceType or txtServiceName
#openprint::service::auto_calculate( $r, $log, $dbh, $variable, $project_index );
## needs approval
#        # email CSR
	} elsif ( $openprint::param{'btnFunction'} eq 'AdditionalChargeNotify' ) {
		send_additional_charges_notifications( $r, $log, $dbh, @openprint::param{'OrderID','ProjectIndex'} );
		$$variable{'information'} = 'Additional Charges Email sent.';
	} elsif ( $openprint::param{'btnFunction'} eq 'DeleteServices' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $key ( keys %openprint::param ) {
			if ( $key =~ /chkDelete-(\d*)/ ) {
				my $sid = $1;
				my $specs = openprint::service::get_specs_ref( $project_index, $sid );
				openprint::print_project::delete_service( $log, $dbh, $project_index, $sid );
				openprint::press_schedule::remove( $project_index, $sid );
				openprint::bindery_schedule::remove( $project_index, $sid );
				$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Deleted service $$specs{'ServiceType'} $$specs{'ServiceName'}." );
			} # end if
		} # end foreach
		$Project->update_status();
		openprint::order::update_order_status( $r, $log, $dbh, $openprint::param{'OrderID'} );
		sql::end_transaction( $dbh, $ac );
	} elsif ( $openprint::param{'btnFunction'} eq 'Approve' ) {
		my $Order = new openprint::Order( $openprint::param{'OrderID'} );
		$Order->approve();
		$Project->update_status();
		openprint::order::update_order_status( $r, $log, $dbh, $order_id );
	} # end if

	if ( $project_index ) {
		openprint::project::view( $log, $dbh, $variable, $project_index, $order_id );
	} # end if

} # end sub view_project

sub send_additional_charges_notifications {
	my ( $r, $log, $dbh, $order_id, $project_index ) = @_;
# Email CSR
	my %info;
	$info{'ProjectIndex'} = $project_index;
	$info{'OrderID'} = $order_id;

	my $Order = new openprint::Order( $order_id );
	my $CSR = new openprint::User( $Order->salesrep_id() );
	my $Operator = new openprint::User( $openprint::session{'user_id'} );

	@info{'CSRFirstName','CSRLastName','CSREmail'} = ( $CSR->firstname(), $CSR->lastname(), $CSR->email() );

	@info{'CustomerFirstName','CustomerLastName','CustomerEmail'} = ( $Order->first_name(), $Order->last_name(), $Order->email() );
	@info{'OperatorFirstName','OperatorLastName','OperatorEmail'} = ( $Operator->firstname(), $Operator->lastname(), $Operator->email() );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $Operator->firstname(), $Operator->lastname(), $Operator->email(), $Operator->extension() );

	$info{'CompletionDate'} = Date::Format::time2str( $openprint::config{'DateTimeFormat'}, time );
	$info{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
	$info{'siteURL'} = $r->dir_config('ExternalSiteURL');

	my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );

#$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/additional_charges_csr_notification.html\"-->";
#$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, $email_template, \%info ) );
#my @body = ('', $_, 'text/html', 'quoted-printable');
#my %mail = (
#SMTP    => $openprint::config{'Mail Server'},
#FROM    => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#'Return-receipt-to'    => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#'Disposition-Notification-To' => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
##TO      => 'iconnor@point-one.com, rick@point-one.com',
#TO      => 'iconnor@point-one.com',
#SUBJECT => "Additional Charges required for project $project_index",
#);
#misc::send_email_with_attachment( $log, \%mail, @body );

	$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/additional_charges_client_notification.html\"-->";
	$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');
	my %mail = (
			SMTP    => $openprint::config{'Mail Server'},
			FROM    => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#TO      => 'iconnor@point-one.com, rick@point-one.com',
			'Return-receipt-to' => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
			'Disposition-Notification-To' => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#TO      => 'iconnor@point-one.com',
			TO      => join(',', sprintf( "%s %s <%s>", @info{'CustomerFirstName','CustomerLastName','CustomerEmail'}), $openprint::param{'AdditionalEmailRecipients'}),
			CC      => sprintf( '"%s %s" <%s>', @info{'CSRFirstName','CSRLastName','CSREmail'}),
			SUBJECT => 'Additional Charges required',
			);
	misc::send_email_with_attachment( $log, \%mail, @body );
	my $Project = new openprint::Project( $project_index );
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Additional charges notification sent to : $mail{TO}." );

} # End sub send_additional_charges_notifications

sub upload_pdfs {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $project_index = $openprint::param{'ProjectIndex'};
	my $Project = new openprint::Project( $project_index );

	my $Company = new openprint::Company( $openprint::session{'company_id'} );
	$$variable{'CompanyName'} = $Company->name();

	$$variable{'Docket'} = $Project->docket();
	my $destdir = $openprint::config{'PDFS Path'} . "/$$variable{'CompanyName'}";
	if ( ! -e $destdir  ) {
		if ( ! mkdir $destdir ) {
			$log->error("Cannot create company PDFs dir $destdir : Reason: $!" );
		} # end if
	} # end if
	$destdir .= "/$$variable{'Docket'}";
	if ( ! -e $destdir  ) {
		if ( ! mkdir $destdir ) {
			$log->error("Cannot create PDFs dir $destdir : Reason: $!" );
		} # end if
	} # end if

	if ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		my $destdir = $ENV{DOCUMENT_ROOT} . "/pdfs/$project_index";
		foreach my $filename ( $openprint::param{'chkFiles'} ) {
			sql::execute( $log, $dbh, 'DELETE FROM tbl_Project_PDFs WHERE lngProjectIndex=? AND strFileName=?', $project_index, $filename );
			if ( ! unlink "$destdir/$filename" ) {
				$log->debug( "Error deleting file $destdir/$filename");
			} # end if
		} # end foreach

	} elsif ( $openprint::param{'btnFunction'} eq 'Upload Files' ) {
		foreach my $index ( 1 .. 5 ) {

			if ( $r->param('fileUpload'.$index) ) {
				my $filename = $r->param('fileUpload'.$index);
				$filename =~ s/.*[\/\\](.*)/$1/;
				$filename =~ s/ /_/g;
				$log->debug("Filename: $filename");
				if ( ! -e $destdir  ) {
					if ( ! mkdir $destdir ) {
						$log->error("Cannot create dir $destdir : Reason: $!" );
						return misc::error( $log, $dbh, $variable, "Error creating directory", "I was unable to create a directory to hold the pdf files.   Please contact the administrator" );
					} # end if  
				} elsif ( ! -d $destdir ) {
					$log->error("$destdir exists but is not a directory.");
					return misc::error( $log, $dbh, $variable, "Error creating directory", "I was unable to create a directory to hold the pdf files.   Please contact the administrator" );
				} # end if

				my $upload = $r->upload('fileUpload'.$index);

				if ( ! $upload->link( "$destdir/$filename" ) ) {
					return misc::error( $log, $dbh, $variable, 'Error uploading file.', "$!<br/>Please contact the administrator" );
				} # end if

				if ( ! sql::execute( $log, $dbh, 'SELECT * FROM tbl_Project_PDFs WHERE lngProjectIndex=? AND strFileName=?', $project_index, $filename ) ) {
					sql::insert( $log, $dbh, 'tbl_Project_PDFs',[
							'lngProjectIndex',  $project_index,
							'strFileName',      $filename,
							'strDescription',   $r->param('txtDescription'.$index)
							] );
				} else {
					sql::update( $log, $dbh, 'tbl_Project_PDFs', ['lngProjectIndex=? AND strFileName=?', $project_index, $filename ],
							'strDescription',   $r->param('txtDescription'.$index)
							);

				} # end if
			} # end if
		} # end foreach

	} # end if

	@{$$variable{'PDFS'}} = sql::execute( $log, $dbh, 'SELECT strFileName, strDescription FROM tbl_Project_PDFs WHERE lngProjectIndex=?', $project_index );

	$$variable{'ProjectIndex'} = $project_index; 
} # end sub upload_pdfs

sub send_proofs_complete_email {
	my ( $r, $log, $dbh, $variable, $project_index, $order_id ) = @_;
# Do proofs specific stuff, which for now is send an email.
#Look up Employee info
	my %info;

	my $Project = new openprint::Project( $project_index );
	( my $user_index, @info{'DocketNumber','ProjectReference'} ) = ( $Project->user_id(), $Project->docket(), $Project->reference() );
	$info{'ProjectIndex'} = $project_index;

	my $Order = new openprint::Order( $order_id );
	@info{'CustomerFirstName','CustomerLastName','CustomerEmail'} = ( $Order->first_name(), $Order->last_name(), $Order->email() );

	my $User = new openprint::User( $openprint::session{'user_id'} );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $User->firstname(), $User->lastname(), $User->email(), $User->extension() );

	$info{'CompletionDate'} = Date::Format::time2str( $openprint::config{'DateTimeFormat'}, time );

	$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/proofs_complete.html' );
	$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );

	$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
	$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, \$_, \%info ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');
	my %mail = (
			SMTP    => $openprint::config{'Mail Server'},
			FROM    => sprintf( "%s %s <%s>", @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
			TO      => sprintf( "%s %s <%s>", @info{'CustomerFirstName','CustomerLastName','CustomerEmail'}),
			SUBJECT => "Proofs Complete",
			);

#misc::send_email_with_attachment( $log, \%mail, @body );

# Send email to sales rep
#$_ = "SELECT strFirstName, strLastName, strEmail FROM Users WHERE Index=(SELECT lngEmployeeID FROM Orders WHERE LngOrderID='$order_id')";
#my $sales_person_email = sprintf( "%s %s <%s>", sql::execute( $log, $dbh, $_ ) );
#if ( $sales_person_email ne '  <>' ) {
#$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/proofs_complete-sales_rep.html\"-->";
#$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, $email_template, \%info ) );
#my @body = ('', $_, 'text/html', 'quoted-printable');
#my %mail = (
#SMTP    => $openprint::config{'Mail Server'},
#FROM    => sprintf( "%s %s <%s>", @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#TO      => $sales_person_email,
#SUBJECT => "Docket $info{'DocketNumber'} Proofs Complete",
#);
#misc::send_email_with_attachment( $log, \%mail, @body );
#} # end if
} # end sub send_proofs_complete_email

sub send_proofs_approved_email {
	my ( $r, $log, $dbh, $variable, $project_index, $order_id ) = @_;

# Send email to sales rep
	my %info;
	$info{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
	$info{'siteURL'} = $r->dir_config('ExternalSiteURL');

	my $Project = new openprint::Project( $project_index );
	( my $user_index, @info{'DocketNumber','ProjectReference'} ) = ( $Project->user_id(), $Project->docket(), $Project->reference() );
	$info{'ProjectIndex'} = $project_index;
	$info{'OrderID'} = $order_id;

	@info{'DueDate'} = Date::Format::time2str( $openprint::config{'DateFormat'}, Date::Parse::str2time( $Project->due_date() ) );

	my $Order = new openprint::Order( $order_id );
	@info{'CustomerFirstName','CustomerLastName','CustomerEmail'} = ( $Order->first_name(), $Order->last_name(), $Order->email() );

	my $User = new openprint::User( $openprint::session{'user_id'} );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $User->firstname(), $User->lastname(), $User->email(), $User->extension() );

	$info{'CompletionDate'} = Date::Format::time2str( $openprint::config{'DateTimeFormat'}, time );

	my $CSR = new openprint::User( $Order->salesrep_id() );
	my $sales_person_email = sprintf( "%s %s <%s>", $CSR->firstname(), $CSR->lastname(), $CSR->email() );
	if ( $sales_person_email ne '  <>' ) {
		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/proofs_approved-sales_rep.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
		$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
		$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, \$_, \%info ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $openprint::config{'Mail Server'},
				FROM    => sprintf( "%s %s <%s>", @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
				TO      => $sales_person_email,
				SUBJECT => "Docket $info{'DocketNumber'} Proofs Approved",
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end if
} # end sub send_proofs_approved_email

sub send_duedate_change_notification {
	my ( $r, $log, $dbh, $variable, $project_index, $order_id ) = @_;

# Send email to sales rep
	my %info;

	$info{'ProjectIndex'} = $project_index;
	$info{'OrderID'} = $order_id;
	my $Order = new openprint::Order( $order_id );

	my $Project = new openprint::Project( $project_index );
	@info{'DueDate'} = Date::Format::time2str( $openprint::config{'DateFormat'}, Date::Parse::str2time( $Project->due_date() ) );

	my $User = new openprint::User( $openprint::session{'user_id'} );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $User->firstname(), $User->lastname(), $User->email(), $User->extension() );
	my $CSR = new openprint::User( $Order->salesrep_id() );
	if ( $CSR->email() ) {
		my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
		$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/proofs_duedate_change-sales_rep.html\"-->";
		$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $openprint::config{'Mail Server'},
				FROM    => sprintf( "%s %s <%s>", @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#TO      => 'iconnor@point-one.com',
				TO      => sprintf( '"%s %s" <%s>', $CSR->firstname(), $CSR->lastname(), $CSR->email() ),
				SUBJECT => "Docket $info{'DocketNumber'} DueDate Changed",
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end if
} # end sub send_duedate_change_notification

sub load_press_use {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	$$variable{'Project'} = new openprint::Project( $project_index );

	#@{$$variable{'Presses'}} = openprint::Equipment::find( 'category'=>'Printing', 'order'=>'lower(strName)' );

	my $duedatedays = 0;
	foreach my $signature_service_index ( $$variable{'Project'}->signatures() ) {
		my %printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $signature_service_index );
		push @{$$variable{'Signatures'}}, @printing_specs{'SignatureIndex','txtServiceDescription'};
		if ( ! $printing_specs{'UsePress'} ) {
			$printing_specs{'UsePress'} = $printing_specs{'ddmPress'.$$variable{'Project'}->ordered_quantity_index()};
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $signature_service_index, 'UsePress', $printing_specs{'UsePress'} );
		} # end if
		$$variable{"UsePress-$signature_service_index"} = $printing_specs{"UsePress"};
# Lookup how many days to add to due date
		if ( my @Equipment = openprint::Equipment::find( 'strid'=>$printing_specs{'UsePress'} ) ) {
			( $_ ) = $Equipment[0]->specification('DueDateDays');
			if ( $_ > $duedatedays ) {
				$duedatedays = int $_;
			} # end if
		} # end if
	} # end foreach signature_service_index
	return $duedatedays;
} # end sub load_press_use


sub load_press_completion {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	$$variable{'Project'} = new openprint::Project( $project_index );

	foreach my $signature_service_index ( $$variable{'Project'}->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		push @{$$variable{'Signatures'}}, @$specs{'SignatureIndex','txtServiceDescription'};

		@$variable{
			"txtEmployeeName-$$specs{'SignatureIndex'}",
				"txtEmployeeComments-$$specs{'SignatureIndex'}",
				"UsedStockType-$$specs{'SignatureIndex'}",
				"UsedStockBrand-$$specs{'SignatureIndex'}",
				"UsedStockFinish-$$specs{'SignatureIndex'}",
				"UsedStockColour-$$specs{'SignatureIndex'}",
				"UsedStockWeight-$$specs{'SignatureIndex'}",
				"UsedStockSheetSize-$$specs{'SignatureIndex'}",
				"UsedStockQuantity-$$specs{'SignatureIndex'}",
				"ddmPressCompletionDateMonth-$$specs{'SignatureIndex'}",
				"ddmPressCompletionDateDay-$$specs{'SignatureIndex'}",
				"ddmPressCompletionDateYear-$$specs{'SignatureIndex'}",
				"rdbPressComplete-$$specs{'SignatureIndex'}",
				"UsePress-$$specs{'SignatureIndex'}",
				"UsedImposition-$$specs{'SignatureIndex'}",
				"UsedColumns-$$specs{'SignatureIndex'}",
				"UsedRows-$$specs{'SignatureIndex'}",
				"UsedDutchColumns-$$specs{'SignatureIndex'}",
				"UsedDutchRows-$$specs{'SignatureIndex'}",
				"UsedRunStyle-$$specs{'SignatureIndex'}",
		} = @$specs{
			"txtEmployeeName",
				"txtEmployeeComments",
				"UsedStockType",
				"UsedStockBrand",
				"UsedStockFinish",
				"UsedStockColour",
				"UsedStockWeight",
				"UsedStockSheetSize",
				"UsedStockQuantity",
				"ddmPressCompletionDateMonth",
				"ddmPressCompletionDateDay",
				"ddmPressCompletionDateYear",
				"rdbPressComplete",
				'UsePress',
				'UsedImposition',
				'UsedColumns',
				'UsedRows',
				'UsedDutchColumns',
				'UsedDutchRows',
				'UsedRunStyle',
		};
		$$variable{"UsedStockQuantity-$$specs{'SignatureIndex'}"} = $$specs{'txtPressSheetQty'.$$variable{'Project'}->ordered_quantity_index()} if ! $$variable{"UsedStockQuantity-$$specs{'SignatureIndex'}"};
		$$variable{"UsedStockType-$$specs{'SignatureIndex'}"} = $$specs{'StockType'.$$variable{'Project'}->ordered_quantity_index()} if ! $$variable{"UsedStockType-$$specs{'SignatureIndex'}"};
		$$variable{"UsedImposition-$$specs{'SignatureIndex'}"} = $$specs{'txtImposition'.$$variable{'Project'}->ordered_quantity_index()} if ! $$variable{"UsedImposition-$$specs{'SignatureIndex'}"};
		$$variable{"UsedColumns-$$specs{'SignatureIndex'}"} = $$specs{'hdnImpositionColumns'.$$variable{'Project'}->ordered_quantity_index()} if ! $$variable{"UsedColumns-$$specs{'SignatureIndex'}"};
		$$variable{"UsedRows-$$specs{'SignatureIndex'}"} = $$specs{'hdnImpositionRows'.$$variable{'Project'}->ordered_quantity_index()} if ! $$variable{"UsedRows-$$specs{'SignatureIndex'}"};
		$$variable{"UsedDutchColumns-$$specs{'SignatureIndex'}"} = $$specs{'hdnImpositionDutchColumns'.$$variable{'Project'}->ordered_quantity_index()} if ! $$variable{"UsedDutchColumns-$$specs{'SignatureIndex'}"};
		$$variable{"UsedDutchRows-$$specs{'SignatureIndex'}"} = $$specs{'hdnImpositionDutchRows'.$$variable{'Project'}->ordered_quantity_index()} if ! $$variable{"UsedDutchRows-$$specs{'SignatureIndex'}"};
		$$variable{"UsedRunStyle-$$specs{'SignatureIndex'}"} = $$specs{'ddmRunStyle'.$$variable{'Project'}->ordered_quantity_index()} if ! $$variable{"UsedRunStyle-$$specs{'SignatureIndex'}"};

		@$variable{"UsePress-$$specs{'SignatureIndex'}"} = $$specs{'ddmPress'.$$variable{'Project'}->ordered_quantity_index()} if ! $$variable{"ddmPress-$$specs{'SignatureIndex'}"};
		if ( ! $$variable{"UsedStockSheetSize-$$specs{'SignatureIndex'}"} ) {
			if ( $$specs{'StockType'.$$variable{'Project'}->ordered_quantity_index()} eq 'Roll' ) {
				$$variable{"UsedStockSheetSize-$$specs{'SignatureIndex'}"} = $$specs{'StockWidth'.$$variable{'Project'}->ordered_quantity_index()};
			} else {
				$$variable{"UsedStockSheetSize-$$specs{'SignatureIndex'}"} = $$specs{'StockWidth'.$$variable{'Project'}->ordered_quantity_index()} .'x'.$$specs{'StockHeight'.$$variable{'Project'}->ordered_quantity_index()};
			} # end if
		} # end if

		@$variable{"PressName-$$specs{'SignatureIndex'}"} = sql::execute( $log, $dbh, 'SELECT strName FROM tbl_Equipment WHERE strID=?', $$specs{'UsePress'} );
	} # end foreach signature_service_index

} # end sub load_press_completion

sub is_sig_complete {
	my ( $r, $log, $dbh, $project_index, $signature_service_index ) = @_;

	my %printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $signature_service_index );
	if ( $r->param("rdbPressComplete-$printing_specs{'SignatureIndex'}") ne 'Yes' ) {
		sql::update( $log, $dbh, 'tbl_Project_Contents', "lngServiceIndex=$signature_service_index", 'strStatus','Ordered' );
		return 0;
	} # end if
	sql::update( $log, $dbh, 'tbl_Project_Contents', "lngServiceIndex=$signature_service_index", 'strStatus','Complete' );

# Remove jobs from the Schedule when marked complete.
	sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, $project_index, $signature_service_index );

	return 1;
} # end sub is_sig_complete

sub barcode {
	my ( $r, $log, $dbh, $variable ) = @_;

	foreach my $param ( 'Project', 'Action', 'Operator','Order' ) {
		$openprint::param{$param} =~ s/\D//g;
	} # end foreach param

	@openprint::param{'Order'} = sql::execute( $log, $dbh, q{SELECT  MAX(OrderIndex) FROM Order_Contents WHERE lngProjectIndex=?}, $openprint::param{'Project'} ) if ( ! $openprint::param{'Order'} ) and $openprint::param{'Project'};
	my %operators = sql::execute( $log, $dbh, q{SELECT Index, strFirstName || ' ' || strLastName FROM Users WHERE chrType IN ('E','A')} );

	if ( $openprint::param{'Project'} or $openprint::param{'Action'} or $openprint::param{'Operator'} ) {
		if ( ! $openprint::param{'Project'} ) {
			$$variable{'Error'} = 'No Project ID given.';
			return;
		} # end if
		if ( ! $openprint::param{'Action'} ) {
			$$variable{'Error'} .= 'No Action given.';
			return;
		} # end if
		if ( ! $openprint::param{'Operator'} ) {
			$$variable{'Error'} .= 'No Operator given';
			return;
		} # end if
		if ( ! $operators{$openprint::param{'Operator'}} ) {
			$$variable{'Error'} = 'Invalid Operator specified.  Please try again';
			return;
		} # end if
	} else {
		return;
	} # end if

	my $Project = new openprint::Project( $openprint::param{'Project'} );

	my %services = $Project->get_services();

	my $message;
	my $docket_id = $Project->docket();

	if ( $openprint::param{'Action'} == 1 ) { # Assign Prepress Operator

		my ( $service_index, $old_operator_id ) = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, operator_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $Project->id(), $services{'Proofs'} ? $services{'Proofs'} : $services{'FilmStripping'} );

		if ( ! $service_index ) {
			$$variable{'Error'} = "Could not locate Proofs or FilmStripping Service for docket $docket_id";
			$message = "Could not locate Proofs or FilmStripping Service for docket $docket_id";
			return;
		} # end if

		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $Project->id(), $service_index],
				'operator_id', $openprint::param{'Operator'},
				'starttime',    'NOW()',
				);
		if ( ! $old_operator_id ) {
			$message .= "Assigning Prepress Operator for project $openprint::param{'Project'} to $operators{$openprint::param{'Operator'}}";
		} elsif ( $openprint::param{'Operator'} != $old_operator_id ) {
			$message .= "Assigning Prepress Operator for project $openprint::param{'Project'} from $operators{$old_operator_id} to $operators{$openprint::param{'operator'}}";
		} else {
			$message .= "Setting Prepress Operator for project $openprint::param{'Project'} to $operators{$openprint::param{'Operator'}}";
		} # end if
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, $message );
	} elsif ( $openprint::param{'Action'} == 2 ) { # Proofs Out
		my ( $service_index, $old_operator_id, $status ) = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, operator_id, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $Project->id(), ( $services{'Proofs'} ? $services{'Proofs'} : $services{'FilmStripping'} ) );

		if ( ! $service_index ) {
			$$variable{'Error'} = "Could not locate Proofs or FilmStripping Service for docket $docket_id";
			return;
		} # end if

		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_index, 'rdbComplete', 'Yes' );
		$Project->add_to_log( $openprint::session{'company_id'}, $openprint::param{'Operator'}, "Marked Proofs Proofs Out from $status via barcode" );
		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $Project->id(), $service_index], 'strStatus', 'Proofs Out' );
		$message = sprintf( 'Marked project %d Proofs Out from %s', $Project->id(), $status );

#send_proofs_complete_email( $r, $log, $dbh, $variable, $project_index, $order_id );
	} elsif ( $openprint::param{'Action'} == 3 ) { # Proofs Approved
		my ( $service_index, $old_operator_id, $status ) = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, operator_id, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $Project->id(), ( $services{'Proofs'} ? $services{'Proofs'} : $services{'FilmStripping'} ) );

		if ( ! $service_index ) {
			$$variable{'Error'} = "Could not locate Proofs or FilmStripping Service for docket $docket_id";
			return;
		} # end if
		$message = sprintf('Marked project %d Approved from %s<br/>Notified CSR', $Project->id(), $status );
		my ( $year, $month, $day ) = get_due_date( $log, $dbh, $Project->id() );
		$Project->due_date( join('-', $year, $month, $day ) );
		$Project->save();
		mark_proofs_approved( $log, $dbh, $variable, $Project->id(), $service_index, $status );
		send_proofs_approved_email( $r, $log, $dbh, $variable, $Project->id(), $openprint::param{'Order'} );
	} elsif ( $openprint::param{'Action'} == 4 ) { # Unassign Operator
		my ( $service_index, $old_operator_id ) = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, operator_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $Project->id(), $services{'Proofs'} ? $services{'Proofs'} : $services{'FilmStripping'} );

		if ( ! $service_index ) {
			$$variable{'Error'} = 'Could not locate Proofs or FilmStripping Service';
			return;
		} # end if

		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $Project->id(), $service_index],
				'operator_id',  undef,
				'starttime',    'NOW()',
				);
		if ( ! $old_operator_id ) {
			$message = sprintf('Un-Assigning Prepress Operator for project %d', $Project->id());
		} else {
			$message = sprintf('Un-Assigning Prepress Operator for project %d from %s', $Project->id(), $operators{$old_operator_id});
		} # end if
		$Project->add_to_log( $openprint::session{'company_id'}, $openprint::param{'Operator'}, $message );
	} elsif ( $openprint::param{'Action'} == 20 ) { # Project Printed
		$Project->status_change( $openprint::session{'company_id'}, $openprint::param{'Operator'}, 'Complete' );
		$message = sprintf('Project %d marked Printed', $Project->id() );
	} elsif ( $openprint::param{'Action'} == 30 ) { # Project Complete
		$Project->status_change( $openprint::session{'company_id'}, $openprint::param{'Operator'}, 'Complete' );
		$message = sprintf('Project %d marked Complete', $Project->id() );
	} elsif ( $openprint::param{'Action'} == 40 ) { # Project Shipped
		$Project->status_change( $openprint::session{'company_id'}, $openprint::param{'Operator'}, 'Shipped' );
		$message = sprintf('Project %d marked Shipped', $Project->id() );
	} elsif ( $openprint::param{'Action'} == 50 ) { # Project Picked Up
		$Project->status_change( $openprint::session{'company_id'}, $openprint::param{'Operator'}, 'Picked Up' );
		$message = sprintf('Marked project %d as Picked Up', $Project->id() );
	} elsif ( $openprint::param{'Action'} == 60 ) { # Project Bindery Complete
		$Project->status_change( $openprint::session{'company_id'}, $openprint::param{'Operator'}, 'Bindery Complete' );
		$message = sprintf('Marked project %d as Bindery Complete', $Project->id() );
	} elsif ( $openprint::param{'Action'} == 70 ) { # Project Out For Outside Finishing
		$message = sprintf('Marked project %d as Out For Finishing', $Project->id() );
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Marked Out For Finishing' );
	} elsif ( $openprint::param{'Action'} == 80 ) { # Project Returned From Outside Finishing
		$message = sprintf('Marked project %d as Returned From Finishing', $Project->id() );
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Marked Returned From Finishing' );
	} else {
		$$variable{'Error'} = "Unimplemented action code $openprint::param{'Action'}";
	} # end if
	if ( $openprint::param{'Action'} ) {
		add_to_barcode_log( $log, $dbh, $variable, $Project->id(), $docket_id, $openprint::param{'Operator'}, $message );
#$$variable{'Results'} = sprintf('<tr><td>%.4d-%.2d-%.2d %.2d:%.2d:%.2d</td><td>%s</td><td><a href="project_view.html?ProjectIndex=%d&OrderID=%d">%d</a></td><td>%s</td></tr>', Date::Calc::Today_and_Now(), $operators{$operator}, $project_index, $order_id, $docket_id, $message ) . $$variable{'Results'};
		$Project->update_status();
		openprint::order::update_order_status( $r, $log, $dbh, $openprint::param{'Order'} );
	} # end if

} # end sub barcode

sub mark_proofs_approved {
	my ( $log, $dbh, $variable, $project_index, $service_index, $old_status ) = @_;

	my $Project = new openprint::Project( $project_index );
	if ( ! $service_index ) {
		my %services = $Project->get_services();
		$service_index = $services{'Proofs'} ? $services{'Proofs'}[0] : $services{'FilmStripping'}[0];
	} # end if
	if ( ! $service_index ) {
		$log->error("Project $project_index has no Proofs service in mark_proofs_approved.");
	} # en dif

	$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Proofs Approved from $old_status" );
	$$variable{'Project'} = $Project;
# Mark Service as Approved
	sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], 'strStatus', 'Approved' );

	my $approval_date = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', Date::Calc::Today_and_Now() );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'ApprovalDate', $approval_date );

	if ( $openprint::config{'Smart Schedule'} eq 'Y' ) {
		foreach my $signature_service_index ( $Project->signatures() ) {
			my %specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $signature_service_index );
			$specs{'UsePress'} = $specs{'ddmPress'.$$variable{'Project'}->ordered_quantity_index()} if ! $specs{'UsePress'};
			my @Equipment = openprint::Equipment::find('strid'=>$specs{'UsePress'});
			if ( @Equipment ) {
				openprint::employee_schedule::remove( $log, $dbh, $project_index, $signature_service_index );
				openprint::employee_schedule::insert( $log, $dbh, $project_index, $signature_service_index, $Equipment[0]->id() );
			} # end if
		} # end foreach signature_service_index
	} # end if

} # end sub mark_proofs_approved


sub get_due_date {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );

	my $duedatedays = 0;
	foreach my $signature_service_index ( $Project->signatures() ) {
		my %printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $signature_service_index );
		if ( ! exists $printing_specs{'UsePress'} ) {
			$printing_specs{'UsePress'} = $printing_specs{'ddmPress'.$Project->ordered_quantity_index()};
		} # end if
		if ( my @Equipment = openprint::Equipment::find( 'strid'=>$printing_specs{'UsePress'} ) ) {
			# Lookup how many days to add to due date
			( $_ ) = $Equipment[0]->specification('DueDate Days');
			if ( $_ > $duedatedays ) {
				$duedatedays = int $_;
			} # end if
		} # end if
	} # end foreach signature_service_index

	if ( ! $duedatedays ) {
		$duedatedays = 5;
	} # end if
# Make sure that it is a business day!
	my ( $year, $month, $day ) = Date::Calc::Today();
	while ($duedatedays) {
		( $year, $month, $day ) = Add_Delta_Days( $year, $month, $day, 1 );
		while ( 6 <= Date::Calc::Day_of_Week( $year, $month, $day ) ) {
			( $year, $month, $day ) = Add_Delta_Days( $year, $month, $day, 1 );
		} # end while
		$duedatedays -= 1;
	} # end while
	return ( $year, $month, $day );
} # end sub get_due_date


sub add_to_barcode_log {
	my ( $log, $dbh, $variable, $project_id, $docket, $operator_id, $desc ) = @_;

	sql::insert( $log, $dbh, 'Barcode_Log',
			'project_id',   $project_id,
			'docketnumber', $docket,
			'user_id',      $openprint::session{'user_id'},
			'operator_id',  $operator_id,
			'dtmTimestamp', 'NOW()',
			'Description',  $desc,
			);
} # end sub add_to_barcode_log

sub complete_signature {
	my ( $log, $dbh, $variable, $project_id, $service_id ) = @_;

	my $ac = sql::start_transaction( $dbh );
	my %specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_id, $service_id );
	my $Project = new openprint::Project( $project_id );

	sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_id AND lngServiceIndex=$service_id", 'strStatus', 'Complete' );
# Remove from Print Schedule
	sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, $project_id, $service_id );
# Update Bindery Schedule
	sql::update( $log, $dbh, 'Bindery_Schedule', "ProjectIndex=$project_id", 'starttime', 
			sql::execute( $log, $dbh, q{SELECT NOW() + '2 hours'::interval} )
			);
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Form $specs{'SignatureIndex'} Completed" );
	sql::end_transaction( $dbh, $ac );
} # end sub complete_signature

sub docket_sheet {
	openprint::print_project::summary( @_ );
} # end sub docket_shet

1;

__END__
~	   
