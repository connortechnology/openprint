package openprint::employee_project;
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
require openprint::JDF;
require openprint::PaperAllocation;

sub view {
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

	if ( ( $openprint::param{'btnFunction'} eq 'Rush' ) and ! $Project->rush() ) {
		$Project->rush( 1 );
		$$variable{'error'} .= $Project->save();
		if ( ! $$variable{'error'} ) {
			$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Project marked as a rush job." );
			my %info;
			$info{'Project'} = $Project;
			$info{'Docket'} = $Project->docket();
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/rush_job_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
			$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
			$_ = encode_qp( ssi::variable_substitution( \$_, \%info ) );
			my @body = ('', $_, 'text/html', 'quoted-printable');
			my $From = new openprint::User( $openprint::session{'user_id'} );
			my @To = openprint::User::find('usergroup'=>'Production');
			if ( ! sets::isin( $Project->Order()->salesrep_id(), map { $_->id() } @To ) ) {
				push @To, new openprint::User( $Project->Order()->salesrep_id() );
			} # end if

			foreach my $To ( @To ) {
				my %mail = (
						SMTP    => $openprint::config{'Mail Server'},
						FROM    => sprintf( '"%s %s" <%s>', $From->get( 'firstname','lastname','email') ),
						To		=> sprintf( '"%s %s" <%s>', $To->get( 'firstname','lastname','email') ),
						SUBJECT => "Docket $info{'Docket'} Rushed!",
						);
				misc::send_email_with_attachment( $log, \%mail, @body );
			} # end foreach To
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'No Rush' ) {
		$Project->rush( 0 );
		$$variable{'error'} .= $Project->save();
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Project marked as a non-rush job." );
	} elsif ( $openprint::param{'btnFunction'} eq 'Export JDF' ) {
		misc::export( $r, $log, $variable, 'Docket-'.$Project->docket().'.jdf', [$Project->jdf(1.2)->toString()] );
	} elsif ( $openprint::param{'btnFunction'} eq 'Export MXML' ) {
		my $MXML = new openprint::MXML($Project);
		misc::export( $r, $log, $variable, 'Docket-'.$Project->docket().'-Metrix.mxml', [$MXML->toString()] );
		return;
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		my $service_index = $openprint::param{'ServiceIndex'};
		my $status = openprint::service::status( $project_index, $service_index );

		my ( $service_type ) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'ServiceType' );
		if ( $service_type eq 'AdditionalSignature' ) {
			my $complete = is_sig_complete( $r, $log, $dbh, $project_index, $service_index );
			if ( $complete ) {
# Run through each of the signatures and if everyone is complete, then set the printing service to complete
				foreach my $signature_service_index ( $Project->signatures() ) {
					next if $signature_service_index == $service_index;
					my $status = openprint::service::status( $project_index, $signature_service_index );
					if ( $status ne 'Complete' ) {
						$complete = 0;
					} # end if
				} # end foreach
			} # end if

			my $services = $Project->services();
			if ( $$services{''} ) {
				if ( $complete ) {
					sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $$services{''}[0]], 'strStatus', 'Complete' );	
					$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'All signatures complete - marking printing complete.' );
					foreach my $PA ( openprint::PaperAllocation::find('project_id'=>$project_index) ) {
						next if $PA->Paper()->type() ne 'Roll';
						$PA->delete();
						$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Freeing allocated paper: ' . $PA->quantity() . $PA->units() );
					} # end foreach
				} else {
					sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $$services{''}[0]], 'strStatus', 'Ordered' );	
				} # end if
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
						my @ServiceTypes = openprint::ServiceType::find('name'=>$service_type);
						if ( @ServiceTypes ) {
							$$variable{'Redirect'} = '/employee/proj/'.$ServiceTypes[0]->url();
							$$variable{'ErrorMessage'} = 'There was an error saving the DueDate.  Please check that a real date was selected.';
						} else {
							$$variable{'error'} = 'There was an error saving the DueDate.  Please check that a real date was selected.';
						} # end if
						$openprint::param{'rdbComplete'} = 'No';
					} elsif ( 0 < Date::Calc::Delta_Days( @openprint::param{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'}, Date::Calc::Today() ) ) {
						my @ServiceTypes = openprint::ServiceType::find('name'=>$service_type);
						if ( @ServiceTypes ) {
							$$variable{'Redirect'} = '/employee/proj/'.$ServiceTypes[0]->url();
							$$variable{'ErrorMessage'} = 'You cannot select a date in the past. Please try again.';
						} else {
							$$variable{'error'} = 'You cannot select a duedate in the past. Please try again.';
						} # end if
						$openprint::param{'rdbComplete'} = 'No';
					} else {
						my $duedate = join('-', @openprint::param{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'} );
						$Project->due_date( $duedate );
						if ( ! $Project->save() ) {
							$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Duedate changed to $duedate" );
						} else {
							$$variable{'error'} .= 'Error saving duedate.';
						} # end if

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
						$$variable{'error'} .= openprint::press_schedule::add_project_to_press_schedule( $Project );
					} # end if

					if ( (! exists $openprint::param{'rdbApproved'} ) or ($openprint::param{'rdbApproved'}  eq 'Y') ) {
						if ( ! Date::Calc::check_date( @openprint::param{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'} ) ) {
							my @ServiceTypes = openprint::ServiceType::find('name'=>$service_type);
							if ( @ServiceTypes ) {
								$$variable{'Redirect'} = '/employee/proj/'.$ServiceTypes[0]->url();
								$$variable{'ErrorMessage'} = 'There was an error saving the DueDate.  Please check that a real date was selected.';
							} else {
								$$variable{'error'} = 'There was an error saving the DueDate.  Please check that a real date was selected.';
							} # end if
							$openprint::param{'rdbApproved'} = 'N';
						} elsif ( 0 < Date::Calc::Delta_Days( @openprint::param{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'}, Date::Calc::Today() ) ) {
							my @ServiceTypes = openprint::ServiceType::find('name'=>$service_type);
							if ( @ServiceTypes ) {
								$$variable{'Redirect'} = '/employee/proj/'.$ServiceTypes[0]->url();
								$$variable{'ErrorMessage'} = 'You cannot select a date in the past. Please try again.';
							} else {
								$$variable{'error'} = 'You cannot select a duedate in the past. Please try again.';
							} # end if
							$openprint::param{'rdbApproved'} = 'N';
						} else {
# It's a valid duedate
							my $duedate = sprintf('%.4d-%.2d-%.2d', @openprint::param{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'} );

							if ( $status ne 'Approved' ) {
								openprint::employee_production::mark_proofs_approved( $log, $dbh, $variable, $project_index, $service_index, $status );
								send_proofs_approved_email( $r, $log, $dbh, $variable, $project_index, $order_id );
							} # end if
							if ( $duedate ne $Project->due_date() ) {
								$Project->due_date( $duedate );
								if ( ! $Project->save() ) {
									$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Duedate changed to $duedate" );
									send_duedate_change_notification( $r, $log, $dbh, $variable, $project_index, $order_id );
								} else {
									$$variable{'error'} .= 'Error saving duedate.';
								} # end if
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
				openprint::service::status( $project_index, $service_index, 'Complete' );
				$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Printed from $status" );
				foreach my $PA ( openprint::PaperAllocation::find('project_id'=>$project_index) ) {
					next if $PA->Paper()->type() ne 'Roll';
					$PA->delete();
					$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Freeing allocated paper: ' . $PA->quantity() . $PA->units() );
				} # end foreach
# shuffle jobs on the print schedule

			} else {
				openprint::service::status( $project_index, $service_index, 'Ordered' );
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

		$Project->update_status();
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
	} elsif ( $openprint::param{'btnFunction'} eq 'AddToPressSchedule' ) {
		$$variable{'error'} = openprint::press_schedule::add_project_to_press_schedule( $Project );
	} elsif ( $openprint::param{'btnFunction'} eq 'Add Service' ) {

		if ( $openprint::param{'NewServiceType'} ) {
			my $ServiceType = new openprint::ServiceType( $openprint::param{'NewServiceType'} );
			my $new_service_index = openprint::print_project::insert_service( $log, $dbh, $project_index, $ServiceType->name() );

			if ( $ServiceType->name() eq 'AdditionalSignature' ) {
				$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
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

	my $email_template = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );

#$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/additional_charges_csr_notification.html\"-->";
#$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
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
	$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
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
	$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

	$_ = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );
	$_ = encode_qp( ssi::variable_substitution( \$_, \%info ) );
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
#$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
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
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		$_ = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );
		$_ = encode_qp( ssi::variable_substitution( \$_, \%info ) );
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
		my $email_template = misc::load_file( $log, $openprint::config{'SkinPath'}. '/email_template.html' );
		$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/proofs_duedate_change-sales_rep.html\"-->";
		$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
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

sub is_sig_complete {
	my ( $r, $log, $dbh, $project_index, $signature_service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
	if ( $r->param("rdbPressComplete-$$sig_specs{'SignatureIndex'}") ne 'Yes' ) {
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marking form $$sig_specs{'SignatureIndex'} incomplete." );
		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $signature_service_index], 'strStatus','Ordered' );
		return 0;
	} # end if
	if ( $openprint::session{'user_id'} != $openprint::param{"operator_id-$$sig_specs{'SignatureIndex'}"} ) {
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marking form $$sig_specs{'SignatureIndex'} complete for " . new openprint::User( $openprint::param{"operator_id-$$sig_specs{'SignatureIndex'}"} )->name() );
	} else {
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Marking form $$sig_specs{'SignatureIndex'} complete." );
	} # end if
	sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $signature_service_index], 'strStatus','Complete' );

# Remove jobs from the Schedule when marked complete.
	sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, $project_index, $signature_service_index );

	return 1;
} # end sub is_sig_complete

sub docket_sheet {
	openprint::print_project::summary( @_ );
} # end sub docket_sheet
sub summary {
	openprint::print_project::summary( @_ );
} # end sub summary

1;

__END__
~	   
