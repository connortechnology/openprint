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
require openprint::LabelType;
require openprint::Label;
require openprint::PurchaseOrder;
require openprint::PurchaseOrder_Content;
require openprint::PaperInventory;
require openprint::RFIDTag;
require openprint::ScheduledJob;
require openprint::ServiceType_Category;


use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub view {

	my $project_index = $param{'ProjectIndex'};
	$project_index = $param{'project_id'} if ! $project_index;
	$project_index =~ s/\D//g;
	if ( ! $project_index ) {
		if ( $param{'Docket'} ) {
			$param{'Docket'} =~ s/\D//g;
			if ( $param{'Docket'} ) {
				if ( my @Projects = openprint::Project::find('docket'=>$param{'Docket'}) ) {
					$project_index = $Projects[0]->id();
				} # end if
			} # end if
		} elsif ( $param{'docket'} ) {
			$param{'docket'} =~ s/\D//g;
			if ( $param{'docket'} ) {
				if ( my @Projects = openprint::Project::find('docket'=>$param{'docket'}) ) {
					$project_index = $Projects[0]->id();
				} # end if
			} # end if
		} elsif ( $param{'order_id'} ) {
			$param{'order_id'} =~ s/\D//g;
			if ( $param{'order_id'} ) {
				if ( my @Projects = openprint::Project::find('order_id'=>$param{'order_id'}) ) {
					$project_index = $Projects[0]->id();
				} # end if
			} # end if
		} # end if
	} # end if

	my $Project = new openprint::Project( $project_index );
	my $order_id = $param{'OrderID'};
	$order_id = $Project->order_id() if ! $order_id;
	if ( $project_index and ( ! $order_id ) and $param{'Docket'} ) {
		( $order_id ) = sql::execute( $log, $dbh, q{SELECT Index FROM Orders WHERE Index IN ( SELECT DISTINCT OrderIndex FROM Order_Contents WHERE lngProjectIndex=? ) AND lngDocketNumber=?}, $project_index, $param{'Docket'} );
	} # end if
	$variable{'OrderID'} = $order_id;

	if ( ( $param{'btnFunction'} eq 'Rush' ) and ! $Project->rush() ) {
		$Project->rush( 1 );
		$variable{'error'} .= $Project->save();
		if ( ! $variable{'error'} ) {
			$Project->add_to_log( @session{'company_id','user_id'}, "Project marked as a rush job." );
			my %info;
			$info{'Project'} = $Project;
			$info{'Docket'} = $Project->docket();
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/rush_job_notification.html' );
			$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
			$_ = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
			$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( $r, $log, $dbh, \$_, \%info ) ) );
			my @body = ('', $_, 'text/html', 'quoted-printable');
			my $From = new openprint::User( $session{'user_id'} );
			my @To = openprint::User::find('usergroup'=>'Production');
			if ( ! sets::isin( $Project->Order()->salesrep_id(), map { $_->id() } @To ) ) {
				push @To, new openprint::User( $Project->Order()->salesrep_id() );
			} # end if

			foreach my $To ( @To ) {
				my %mail = (
						SMTP    => $config{'Mail Server'},
						FROM    => sprintf( '"%s %s" <%s>', $From->get( 'firstname','lastname','email') ),
						To		=> sprintf( '"%s %s" <%s>', $To->get( 'firstname','lastname','email') ),
						SUBJECT => "Docket $info{'Docket'} Rushed!",
						);
				misc::send_email_with_attachment( $log, \%mail, @body );
			} # end foreach To
		} # end if
	} elsif ( $param{'btnFunction'} eq 'No Rush' ) {
		$Project->rush( 0 );
		$variable{'error'} .= $Project->save();
		$Project->add_to_log( @session{'company_id','user_id'}, "Project marked as a non-rush job." );
	} elsif ( $param{'btnFunction'} eq 'Export JDF' ) {
		misc::export( $r, $log, \%variable, 'Docket-'.$Project->docket().'.jdf', [$Project->jdf(1.2)->toString()] );
	} elsif ( $param{'btnFunction'} eq 'Export MXML' ) {
		my $MXML = new openprint::MXML($Project);
		misc::export( $r, $log, \%variable, 'Docket-'.$Project->docket().'-Metrix.mxml', [$MXML->toString()] );
		return;
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		my $service_index = $param{'ServiceIndex'};
		my $status = openprint::service::status( $project_index, $service_index );

		my ( $service_type ) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'ServiceType' );
		if ( $service_type eq 'AdditionalSignature' ) {
			my $complete = is_sig_complete( $project_index, $service_index );
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
					$Project->add_to_log( @session{'company_id','user_id'}, 'All signatures complete - marking printing complete.' );
					foreach my $PA ( openprint::PaperAllocation::find('project_id'=>$project_index) ) {
						next if $PA->Paper()->type() ne 'Roll';
						$PA->delete();
						$Project->add_to_log( @session{'company_id','user_id'}, 'Freeing allocated paper: ' . $PA->quantity() . $PA->units() );
					} # end foreach
				} else {
					sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $$services{''}[0]], 'strStatus', 'Ordered' );	
				} # end if
			} # end if

		} elsif ( sets::isin( $service_type,[ 'Proofs', 'FilmStripping' ] ) ) {

			# Store Usepress
			foreach my $signature_service_index ( $Project->signatures() ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
				next if ! $param{'UsePress-'.$$sig_specs{'SignatureIndex'}};
				next if $param{'UsePress-'.$$sig_specs{'SignatureIndex'}} eq $$sig_specs{'UsePress'};
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $signature_service_index, 'UsePress', $param{"UsePress-$$sig_specs{'SignatureIndex'}"} );
				my $runtime = openprint::service::get_runtime( $Project, $signature_service_index );

				my $Equipment = openprint::Equipment::find_one('strid'=>$param{"UsePress-$$sig_specs{'SignatureIndex'}"} );
				next if ! $Equipment;

				foreach my $Job ( openprint::ScheduledJob::find( 'service_id'	=> $signature_service_index ) ) {
					$Job->save({ 'equipment_id'	=> $Equipment->id(), 'runtime'		=> "$runtime minutes", });
				} # end foreach Job
			} # end foreach signature_service_index

			if ( $service_type eq 'FilmStripping' ) {
				if ( $param{'rdbComplete'} eq 'Yes' ) {
					if ( ! Date::Calc::check_date( @param{'duedate_year','duedate_month','duedate_day'} ) ) {
						my @ServiceTypes = openprint::ServiceType::find('name'=>$service_type);
						if ( @ServiceTypes ) {
							$variable{'Redirect'} = '/employee/proj/'.$ServiceTypes[0]->url();
							$variable{'ErrorMessage'} = 'There was an error saving the DueDate.  Please check that a real date was selected.';
						} else {
							$variable{'error'} = 'There was an error saving the DueDate.  Please check that a real date was selected.';
						} # end if
						$param{'rdbComplete'} = 'No';
					} else {
						if ( $param{'duedate_year'} ) {
							my $duedate = join('-', @param{'duedate_year','duedate_month','duedate_day'} );
							$Project->due_date( $duedate );
							if ( ! $Project->save() ) {
								$Project->add_to_log( @session{'company_id','user_id'}, "Duedate changed to $duedate" );
							} else {
								$variable{'error'} .= 'Error saving duedate.';
							} # end if
						} # end if

						openprint::service::status( $project_index, $service_index, 'Approved' );
					} # end if
				} else { # Not Complete
					if ( $status ne 'Ordered' ) {
# Make sure we don't get approved without complete, because they can't unapprove
						$Project->add_to_log( @session{'company_id','user_id'}, "Marked Filmstripping Ordered from $status" );
						openprint::service::status( $project_index, $service_index, 'Ordered' );
					} # end if
				} # end if Complete or NOT
			} elsif ( $service_type eq 'Proofs' ) {
				if ( $param{'rdbComplete'} ne 'Yes' ) {
	# Make sure we don't get approved without complete, because they can't unapprove
					$param{'rdbApproved'} = 'N';
					$param{'rdbClientApproved'} = 'N';
					if ( $status ne 'Ordered' ) {
						$Project->add_to_log( @session{'company_id','user_id'}, "Marked Proofs Ordered from $status" );
						openprint::service::status( $project_index, $service_index, 'Ordered' );
					} # end if
				} elsif ( $param{'rdbApproved'} eq 'Y' ) {
					if ( $param{'duedate_year'} ) {
						if ( ! Date::Calc::check_date( @param{'duedate_year','duedate_month','duedate_day'} ) ) {
							my @ServiceTypes = openprint::ServiceType::find('name'=>$service_type);
							if ( @ServiceTypes ) {
								$variable{'Redirect'} = '/employee/proj/'.$ServiceTypes[0]->url();
								$variable{'ErrorMessage'} = 'There was an error saving the DueDate.  Please check that a real date was selected.';
							} else {
								$variable{'error'} = 'There was an error saving the due date.  Please check that a real date was selected.';
							} # end if
							$param{'rdbApproved'} = 'N';
						} else {
							# It's a valid duedate
							my $duedate = sprintf('%.4d-%.2d-%.2d', @param{'duedate_year','duedate_month','duedate_day'} );

							if ( $duedate ne $Project->due_date() ) {
								$Project->due_date( $duedate );
								if ( ! $Project->save() ) {
									$Project->add_to_log( @session{'company_id','user_id'}, "Duedate changed to $duedate" );
									send_duedate_change_notification( $project_index, $order_id );
								} else {
									$variable{'error'} .= 'Error saving duedate.';
								} # end if
							} # end if
						} # end if valid due date
					} # end if due date is specified

					if ( (!$variable{'error'}) and ($status ne 'Approved') ) {
						openprint::employee_production::mark_proofs_approved( $log, $dbh, \%variable, $project_index, $service_index, $status );
						send_proofs_approved_email( $project_index, $order_id );
					} # end if
				} elsif ( $param{'rdbClientApproved'} eq 'Y' ) {
					if ( $status ne 'Waiting For QA Approval' ) {
						$param{'ClientApprovalDate'} = Date::Format::time2str( $config{'DateTimeFormat'}, time );
						if ( $status ne 'Waiting For QA Approval' ) {
							$Project->add_to_log( @session{'company_id','user_id'}, "Marked Proofs Waiting for QA Approval from $status" );
							openprint::service::status( $project_index, $service_index, 'Waiting For QA Approval' );
						} # end if
					} # end if
					$param{'rdbApproved'} = 'N';
				} else { # Just complete
					if ( $status ne 'Waiting For Customer Approval' ) {
						$param{'CompleteDate'} = Date::Format::time2str( $config{'DateTimeFormat'}, time );
						if ( $status ne 'Waiting For Customer Approval' ) {
							$Project->add_to_log( @session{'company_id','user_id'}, "Marked Proofs Waiting for Customer Approval from $status" );
							openprint::service::status( $project_index, $service_index, 'Waiting For Customer Approval' );
						} # end if
					} # end if
					# Only send if completion date has changed
					my ( $c_date, $complete ) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'CompletionDate','rdbComplete' );
					if ( $complete ne $param{'rdbComplete'} and $c_date ne $param{'CompletionDate'} ) {
						send_proofs_complete_email( $project_index, $order_id );
					} # end if completion date has changed
					$param{'rdbApproved'} = 'N';
					$param{'rdbClientApproved'} = 'N';
				} # end if Complete Or NOT
			} # end if Proofs or FilmStrippign
		} else { # A Service, But Not Film Stripping or Proofs
			if ( $param{'rdbComplete'} eq 'Yes' ) {
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
				openprint::service::status( $project_index, $service_index, 'Ordered' );
			} # end if Complete or NOT
		} # end if FilmStripping, Proofs or other

		if ( $param{'TakeOver'} ) {
# Take Over
			$Project->add_to_log( @session{'company_id','user_id'}, 'Taken Over by '. $param{'txtEmployeeName'} );
			if ( $param{'PickupDate'} ) {
				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], ['starttime', $param{'PickupDate'}, 'operator_id', $session{'user_id'} ] );
			} else {
				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], ['starttime', 'NOW()', 'operator_id', $session{'user_id'} ] );
			} # end if
		} # end if

# Save info
		my $ac = sql::start_transaction( $dbh );
		my $service_specs = openprint::service::get_specs_ref( $Project, $service_index );
		if ( $$service_specs{'ProjectType'} ) {
			my $complete = 1;

			foreach my $signature_service_index ( $Project->signatures() ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );

				foreach my $param ( qw/txtEmployeeName txtEmployeeComments UsedStockBrand UsedStockFinish UsedStockColour UsedStockWeight UsedStockSheetSize UsedSheetQuantity ddmPressCompletionDateMonth ddmPressCompletionDateDay ddmPressCompletionDateYear rdbPressComplete UsedImposition UsedColumns UsedRows UsedDutchColumns UsedDutchRows UsedRunStyle UsePress/ ) {
					next if $$sig_specs{$param} eq $param{"$param-$$sig_specs{'SignatureIndex'}"};
					openprint::service::insert_service_spec( $log, $dbh, $project_index, $signature_service_index, $param, $param{"$param-$$sig_specs{'SignatureIndex'}"} );
				} # end foreach

				if ( ! is_sig_complete( $project_index, $signature_service_index ) ) {
					$complete = 0;
				} else {
					foreach my $Job ( openprint::ScheduledJob::find('project_id'=>$project_index, 'service_id'=>$signature_service_index ) ) {
						$Job->delete();
					} # end foreach
					if ( my $Equipment = openprint::Equipment::find_one('strid'=>$$sig_specs{'UsePress'}) ) {
						$Equipment->update_schedule();
					} # end if
				} # end if
			} # end foreach signature_service_index

# There is now a set of press completion buttons for each signature
			if ( $complete ) {
				$Project->status_change( @session{'company_id','user_id'}, 'Printed' );
			} else {
				openprint::service::status( $project_index, $service_index, 'Ordered' );
				$Project->add_to_log( @session{'company_id','user_id'}, "Marked Ordered from $status" );
			} #nd if
		} elsif ( $service_type eq 'AdditionalSignature' ) {
			foreach my $param ( qw/txtEmployeeName txtEmployeeComments UsedStockBrand UsedStockFinish UsedStockColour UsedStockWeight UsedStockSheetSize UsedSheetQuantity ddmPressCompletionDateMonth ddmPressCompletionDateDay ddmPressCompletionDateYear rdbPressComplete UsedImposition UsedColumns UsedRows UsedDutchColumns UsedDutchRows UsedRunStyle UsePress/ ) {
				next if $$service_specs{"$param-$$service_specs{'SignatureIndex'}"} eq $param{"$param-$$service_specs{'SignatureIndex'}"};
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, $param, $param{"$param-$$service_specs{'SignatureIndex'}"} );
			} # end foreach

			if ( my $Equipment = openprint::Equipment::find_one( 'strid'=>$$service_specs{'UsePress'} ) ) {
				$Equipment->update_schedule();
			} # end if
		} else {
			my @do_not_save = ( 'btnFunction','ProjectIndex','ServiceIndex','order_id', 'duedate_day','duedate_month','duedate_year','Docket','TakeOver', 'OrderID' );
			foreach my $param ( keys %param ) {
				next if ( sets::isin_regx( $param, @do_not_save ) );
				next if $$service_specs{$param} eq $param{$param};
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, $param, $param{$param} );
			} # end foreach
		} # end if

		$Project->update_status();
		$order_id = $Project->order_id() if ! $order_id;
		openprint::order::update_order_status( $r, $log, $dbh, $order_id );
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{'btnFunction'} eq 'Shipped' ) {
		$Project->status_change( undef, undef, 'Shipped' );
	} elsif ( $param{'btnFunction'} eq 'Picked Up' ) {
		$Project->status_change( undef, undef, 'Picked Up' );
	} elsif ( $param{'btnFunction'} eq 'Complete Printing' ) {
		$Project->status_change( undef, undef, 'Printed' );
	} elsif ( $param{'btnFunction'} eq 'BinderyComplete' ) {
		$Project->status_change( undef, undef, 'Bindery Complete' );
	} elsif ( $param{'btnFunction'} eq 'Complete' ) {
		$Project->status_change( undef, undef, 'Complete' );
	} elsif ( $param{'btnFunction'} eq 'AddToBinderySchedule' ) {
		openprint::bindery_schedule::add_project( $Project );
	} elsif ( $param{'btnFunction'} eq 'AddToPressSchedule' ) {
		$variable{'error'} .= openprint::press_schedule::add_project_to_press_schedule( $Project, $param{'ServiceIndex'} );
	} elsif ( $param{'btnFunction'} eq 'RemoveFromPressSchedule' ) {
		foreach my $Job ( openprint::ScheduledJob::find( 'project_id'=>$Project->id() ) ) {
			$Job->delete();
		} # end foreach Job
	} elsif ( $param{'btnFunction'} eq 'Add Service' ) {

		if ( $param{'NewServiceType'} ) {
			my $ServiceType = new openprint::ServiceType( $param{'NewServiceType'} );
			my $new_service_index = openprint::print_project::insert_service( $log, $dbh, $project_index, $ServiceType->name() );

			if ( $ServiceType->name() eq 'AdditionalSignature' ) {
				$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
				my ( $signature_count ) = sql::execute( $log, $dbh, $_, $project_index );
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'txtSignatureType', 'AdditionalSignature' );
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'txtServiceDescription', 'Additional Signature' );
				openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'SignatureIndex', ++$signature_count );
			} # end if
			$Project->add_to_log( @session{'company_id','user_id'}, sprintf( 'Added Service: %s', $ServiceType->name() ) );
		} elsif ( $param{'txtServiceName'} ) {
			
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
						'strValue',         misc::moneyfilter($param{'txtPrice'}) ]);
			sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
						'lngProjectIndex',  $project_index,
						'lngServiceIndex',  $service_index,
						'strName',          'txtPrice2',
						'strValue',         misc::moneyfilter($param{'txtPrice'}) ]);
			sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
						'lngProjectIndex',  $project_index,
						'lngServiceIndex',  $service_index,
						'strName',          'txtPrice3',
						'strValue',         misc::moneyfilter($param{'txtPrice'}) ]);
			sql::insert( $log, $dbh, 'tbl_Service_Specifications',[
					'lngProjectIndex',  $project_index,
					'lngServiceIndex',  $service_index,
					'strName',          'ServiceName',
					'strValue',         $param{'txtServiceName'}
					] );

			$Project->add_to_log( @session{'company_id','user_id'}, sprintf( 'Added Custom Line: %s, (%.2f)', @param{'txtServiceName','txtPrice'} ) );
			$Project->update_status( );
			openprint::order::update_order_status( $r, $log, $dbh, $order_id );

			sql::end_transaction( $dbh, $ac );
			} # end if
		} # end if NewServiceType or txtServiceName
#openprint::service::auto_calculate( $r, $log, $dbh, \%variable, $project_index );
## needs approval
#        # email CSR
	} elsif ( $param{'btnFunction'} eq 'AdditionalChargeNotify' ) {
		send_additional_charges_notifications( @param{'OrderID','ProjectIndex'} );
		$variable{'information'} = 'Additional Charges Email sent.';
	} elsif ( $param{'btnFunction'} eq 'DeleteServices' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $key ( keys %param ) {
			if ( $key =~ /chkDelete-(\d*)/ ) {
				my $sid = $1;
				my $specs = openprint::service::get_specs_ref( $Project, $sid );
				openprint::print_project::delete_service( $log, $dbh, $project_index, $sid );
				openprint::press_schedule::remove( $project_index, $sid );
				openprint::bindery_schedule::remove( $project_index, $sid );
				$Project->add_to_log( @session{'company_id','user_id'}, "Deleted service $$specs{'ServiceType'} $$specs{'ServiceName'}." );
			} # end if
		} # end foreach
		$Project->update_status();
		openprint::order::update_order_status( $r, $log, $dbh, $param{'OrderID'} );
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{'btnFunction'} eq 'Approve' ) {
		my $Order = new openprint::Order( $param{'OrderID'} );
		$Order->approve();
		$Project->update_status();
		openprint::order::update_order_status( $r, $log, $dbh, $order_id );
	} # end if

	if ( $project_index ) {
		openprint::project::view( $log, $dbh, \%variable, $project_index, $order_id );
	} # end if
	$variable{'Project'} = $Project if ! $variable{'Project'};

} # end sub view_project

sub send_additional_charges_notifications {
	my ( $order_id, $project_index ) = @_;
# Email CSR
	my %info;
	$info{'ProjectIndex'} = $project_index;
	$info{'OrderID'} = $order_id;

	my $Order = new openprint::Order( $order_id );
	my $CSR = new openprint::User( $Order->salesrep_id() );
	my $Operator = new openprint::User( $session{'user_id'} );

	@info{'CSRFirstName','CSRLastName','CSREmail'} = ( $CSR->firstname(), $CSR->lastname(), $CSR->email() );

	@info{'CustomerFirstName','CustomerLastName','CustomerEmail'} = ( $Order->first_name(), $Order->last_name(), $Order->email() );
	@info{'OperatorFirstName','OperatorLastName','OperatorEmail'} = ( $Operator->firstname(), $Operator->lastname(), $Operator->email() );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $Operator->firstname(), $Operator->lastname(), $Operator->email(), $Operator->extension() );

	$info{'CompletionDate'} = Date::Format::time2str( $config{'DateTimeFormat'}, time );
	$info{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
	$info{'siteURL'} = $r->dir_config('ExternalSiteURL');
	my $Project = new openprint::Project( $project_index );
	$info{'Project'} = $Project;

	openprint::project::get_header( $log, $dbh, \%info, $project_index );

	my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );

#$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/additional_charges_csr_notification.html\"-->";
#$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, $email_template, \%info ) );
#my @body = ('', $_, 'text/html', 'quoted-printable');
#my %mail = (
#SMTP    => $config{'Mail Server'},
#FROM    => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#'Return-receipt-to'    => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#'Disposition-Notification-To' => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
##TO      => 'iconnor@point-one.com, rick@point-one.com',
#TO      => 'iconnor@point-one.com',
#SUBJECT => "Additional Charges required for project $project_index",
#);
#misc::send_email_with_attachment( $log, \%mail, @body );

	$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/additional_charges_client_notification.html\"-->";
	$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ) ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');
	my %mail = (
			SMTP    => $config{'Mail Server'},
			FROM    => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#TO      => 'iconnor@point-one.com, rick@point-one.com',
			'Return-receipt-to' => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
			'Disposition-Notification-To' => sprintf( '"%s %s" <%s>', @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#TO      => 'iconnor@point-one.com',
			TO      => join(',', sprintf( "%s %s <%s>", @info{'CustomerFirstName','CustomerLastName','CustomerEmail'}), $param{'AdditionalEmailRecipients'}),
			CC      => sprintf( '"%s %s" <%s>', @info{'CSRFirstName','CSRLastName','CSREmail'}),
			SUBJECT => 'Additional Charges required',
			);
	misc::send_email_with_attachment( $log, \%mail, @body );
	$Project->add_to_log( @session{'company_id','user_id'}, "Additional charges notification sent to : $mail{TO}." );

} # End sub send_additional_charges_notifications

sub upload_pdfs {
	my $project_index = $param{'ProjectIndex'};
	my $Project = new openprint::Project( $project_index );

	my $Company = new openprint::Company( $session{'company_id'} );
	$variable{'CompanyName'} = $Company->name();

	$variable{'Docket'} = $Project->docket();
	my $destdir = $config{'PDFS Path'} . "/$variable{'CompanyName'}";
	if ( ! -e $destdir  ) {
		if ( ! mkdir $destdir ) {
			$log->error("Cannot create company PDFs dir $destdir : Reason: $!" );
		} # end if
	} # end if
	$destdir .= "/$variable{'Docket'}";
	if ( ! -e $destdir  ) {
		if ( ! mkdir $destdir ) {
			$log->error("Cannot create PDFs dir $destdir : Reason: $!" );
		} # end if
	} # end if

	if ( $param{'btnFunction'} eq 'Delete' ) {
		my $destdir = $ENV{DOCUMENT_ROOT} . "/pdfs/$project_index";
		foreach my $filename ( $param{'chkFiles'} ) {
			sql::execute( $log, $dbh, 'DELETE FROM tbl_Project_PDFs WHERE lngProjectIndex=? AND strFileName=?', $project_index, $filename );
			if ( ! unlink "$destdir/$filename" ) {
				$log->debug( "Error deleting file $destdir/$filename");
			} # end if
		} # end foreach

	} elsif ( $param{'btnFunction'} eq 'Upload Files' ) {
		foreach my $index ( 1 .. 5 ) {

			if ( $r->param('fileUpload'.$index) ) {
				my $filename = $r->param('fileUpload'.$index);
				$filename =~ s/.*[\/\\](.*)/$1/;
				$filename =~ s/ /_/g;
				$log->debug("Filename: $filename");
				if ( ! -e $destdir  ) {
					if ( ! mkdir $destdir ) {
						$log->error("Cannot create dir $destdir : Reason: $!" );
						return misc::error( $log, $dbh, \%variable, "Error creating directory", "I was unable to create a directory to hold the pdf files.   Please contact the administrator" );
					} # end if  
				} elsif ( ! -d $destdir ) {
					$log->error("$destdir exists but is not a directory.");
					return misc::error( $log, $dbh, \%variable, "Error creating directory", "I was unable to create a directory to hold the pdf files.   Please contact the administrator" );
				} # end if

				my $upload = $r->upload('fileUpload'.$index);

				if ( ! $upload->link( "$destdir/$filename" ) ) {
					return misc::error( $log, $dbh, \%variable, 'Error uploading file.', "$!<br/>Please contact the administrator" );
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

	@{$variable{'PDFS'}} = sql::execute( $log, $dbh, 'SELECT strFileName, strDescription FROM tbl_Project_PDFs WHERE lngProjectIndex=?', $project_index );

	$variable{'ProjectIndex'} = $project_index; 
} # end sub upload_pdfs

sub send_proofs_complete_email {
	my ( $project_index, $order_id ) = @_;
# Do proofs specific stuff, which for now is send an email.
#Look up Employee info
	my %info;

	my $Project = new openprint::Project( $project_index );
	( my $user_index, @info{'DocketNumber','ProjectReference'} ) = ( $Project->user_id(), $Project->docket(), $Project->reference() );
	$info{'ProjectIndex'} = $project_index;

	my $Order = new openprint::Order( $order_id );
	@info{'CustomerFirstName','CustomerLastName','CustomerEmail'} = ( $Order->first_name(), $Order->last_name(), $Order->email() );

	my $User = new openprint::User( $session{'user_id'} );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $User->firstname(), $User->lastname(), $User->email(), $User->extension() );

	$info{'CompletionDate'} = Date::Format::time2str( $config{'DateTimeFormat'}, time );

	$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/proofs_complete.html' );
	$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );

	$_ = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
	$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( $r, $log, $dbh, \$_, \%info ) ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');
	my %mail = (
			SMTP    => $config{'Mail Server'},
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
#SMTP    => $config{'Mail Server'},
#FROM    => sprintf( "%s %s <%s>", @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#TO      => $sales_person_email,
#SUBJECT => "Docket $info{'DocketNumber'} Proofs Complete",
#);
#misc::send_email_with_attachment( $log, \%mail, @body );
#} # end if
} # end sub send_proofs_complete_email

sub send_proofs_approved_email {
	my ( $project_index, $order_id ) = @_;

# Send email to sales rep
	my %info;
	$info{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
	$info{'siteURL'} = $r->dir_config('ExternalSiteURL');

	my $Project = new openprint::Project( $project_index );
	@info{'DocketNumber','ProjectReference'} = ( $Project->docket(), $Project->reference() );
	$info{'ProjectIndex'} = $project_index;
	$info{'OrderID'} = $order_id;

	@info{'DueDate'} = Date::Format::time2str( $config{'DateFormat'}, Date::Parse::str2time( $Project->due_date() ) );

	my $Order = new openprint::Order( $order_id );
	@info{'CustomerFirstName','CustomerLastName','CustomerEmail'} = ( $Order->first_name(), $Order->last_name(), $Order->email() );

	my $User = new openprint::User( $session{'user_id'} );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $User->firstname(), $User->lastname(), $User->email(), $User->extension() );

	$info{'CompletionDate'} = Date::Format::time2str( $config{'DateTimeFormat'}, time );

	my $CSR = new openprint::User( $Order->salesrep_id() );
	my $sales_person_email = sprintf( "%s %s <%s>", $CSR->firstname(), $CSR->lastname(), $CSR->email() );
	if ( $sales_person_email ne '  <>' ) {
		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/proofs_approved-sales_rep.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
		$_ = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
		$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( $r, $log, $dbh, \$_, \%info ) ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $config{'Mail Server'},
				FROM    => sprintf( "%s %s <%s>", @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
				TO      => $sales_person_email,
				SUBJECT => "Docket $info{'DocketNumber'} $$Order{'company_name'} - Proofs Approved",
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end if
} # end sub send_proofs_approved_email

sub send_duedate_change_notification {
	my ( $project_index, $order_id ) = @_;

# Send email to sales rep
	my %info;

	$info{'ProjectIndex'} = $project_index;
	$info{'OrderID'} = $order_id;
	my $Order = new openprint::Order( $order_id );

	my $Project = new openprint::Project( $project_index );
	@info{'DueDate'} = Date::Format::time2str( $config{'DateFormat'}, Date::Parse::str2time( $Project->due_date() ) );

	my $User = new openprint::User( $session{'user_id'} );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $User->firstname(), $User->lastname(), $User->email(), $User->extension() );
	my $CSR = new openprint::User( $Order->salesrep_id() );
	if ( $CSR->email() ) {
		my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
		$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/proofs_duedate_change-sales_rep.html\"-->";
		$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ) ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $config{'Mail Server'},
				FROM    => sprintf( "%s %s <%s>", @info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail'}),
#TO      => 'iconnor@point-one.com',
				TO      => sprintf( '"%s %s" <%s>', $CSR->firstname(), $CSR->lastname(), $CSR->email() ),
				SUBJECT => "Docket $info{'DocketNumber'} DueDate Changed",
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end if
} # end sub send_duedate_change_notification

sub is_sig_complete {
	my ( $project_index, $signature_service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
	if ( $param{"rdbPressComplete-$$sig_specs{'SignatureIndex'}"} ne 'Yes' ) {
		$Project->add_to_log( @session{'company_id','user_id'}, "Marking form $$sig_specs{'SignatureIndex'} incomplete." );
		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $signature_service_index], 'strStatus','Ordered' );
		return 0;
	} # end if
	if ( $session{'user_id'} != $param{"operator_id-$$sig_specs{'SignatureIndex'}"} ) {
		$Project->add_to_log( @session{'company_id','user_id'}, "Marking form $$sig_specs{'SignatureIndex'} complete for " . new openprint::User( $param{"operator_id-$$sig_specs{'SignatureIndex'}"} )->name() );
	} else {
		$Project->add_to_log( @session{'company_id','user_id'}, "Marking form $$sig_specs{'SignatureIndex'} complete." );
	} # end if
	sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $signature_service_index], 'strStatus','Complete' );

# Remove jobs from the Schedule when marked complete.
	foreach my $Job ( openprint::ScheduledJob::find( 'project_id' => $project_index, 'service_id' => $signature_service_index ) ) {
		$Job->delete();
	} # end foreach

	return 1;
} # end sub is_sig_complete

sub docket_sheet {
	openprint::print_project::summary( @_ );
} # end sub docket_sheet
sub summary {
	openprint::print_project::summary( @_ );
} # end sub summary

sub _stock_checkout {
	my $Project;
	if ( $param{'project_id'} ) {
		$Project = new openprint::Project( $param{'project_id'} );
	} elsif ( $param{'docket'} ) {
		my @Projects = openprint::Project::find('docket'=>$param{'docket'});
		if ( ! @Projects ) {
			$variable{'error'} .= 'Invalid docket.<br/>';
			return;
		} # end if
		$Project = $Projects[0];
	} # end if
	$variable{'Project'} = $Project;

	if ( $param{'action'} eq 'Add' ) {
		$param{'skid_id'} =~ s/\D//g;
		$param{'rfidtag_id'} =~ s/[^a-zA-Z0-9]//g;
		my $Skid;
		if ( $param{'skid_id'} ) {
			$Skid = new openprint::Skid( $param{'skid_id'} );
		} elsif ( $param{'rfidtag_id'} ) {
			my $RFIDTag = new openprint::RFIDTag( $param{'rfidtag_id'} );
			if ( ! $RFIDTag->id() ) {
				my @Tags = openprint::RFIDTag::find( 'id_like'=>'%'.$param{'rfidtag_id'} );
				if ( @Tags == 1 ) {
					$RFIDTag = $Tags[0];
				} # end if
			} # end if
			if ( ! $RFIDTag->id() ) {
				$variable{'error'} .= 'RFID Tag ' .  $param{'rfidtag_id'} . ' is not in the system.<br/>';
			} else {
				$Skid = $RFIDTag->Skid();
			} # end if
		} else {
			$variable{'error'} .='Please scan the barcode on the skid label or rfid tag.<br/>';
		} # end if
		if ( ! $Skid->id() ) {
			$variable{'error'} .= 'Unknown skid scanned.<br/>';
			return;
		} # end if

		my $add_entry = 1;

		if ( $Skid->is_empty() ) {
			my @PI = openprint::PaperInventory::find('skid_id'=>$Skid->id(), 'comment_like'=>'Checked out%','order'=>'updated_on desc');
			if ( @PI ) {
				$variable{'error'} .= sprintf( '%1$s %2$d has already been checked out', ($PI[0]->Paper()->type() eq 'Roll' ? 'Roll' : 'Skid'), $Skid->id() );
				if ( $PI[0]->docket() ) {
					$variable{'error'} .= sprintf(' to docket <a href="/employee/project/view.html?ProjectIndex=%1$d">%2$d</a>', $PI[0]->Project()->id(), $PI[0]->docket() );
				} # end if
				$variable{'error'} .= '.<br/>';
			} # end if

			foreach my $PI ( @PI ) {
				if ( ! $PI->docket() ) {
					$PI->save({'docket'=>$Project->docket()});
					# only update the most recent entry
					last;
				} else {
					if ( $PI->docket() == $Project->docket() ) {
						$add_entry = 0;
						last;
					} # end if	
				} # end if
			} # end foreach PI
		} # end if

		if ( $add_entry ) {
			my @C = $Skid->Contents();
			if ( @C ) {
				foreach my $C ( $Skid->Contents() ) {
					my $PI = new openprint::PaperInventory();
					$PI->save({
							'docket'	=>	$param{'docket'},
							'paper_id'	=>	$C->paper_id(),
							'user_id'	=>	$session{'user_id'},
							'delta'		=>	-1*$C->quantity(),
							'comment'	=>	sprintf('Checked out for docket <a href="/employee/project/view.html?ProjectIndex=%1$d">%2$d</a> by %3$s', $Project->id(), $Project->docket(), new openprint::User( $session{'user_id'} )->name() ),
							'skid_id'	=>	$Skid->id(),
							'units'		=>	$C->units(),
							});
					$C->quantity( 0 );
					$C->save();
					#Remove any allocations
					foreach my $PA ( openprint::PaperAllocation::find('skid_id'=>$Skid->id(),'paper_id'=>$C->paper_id(), 'docket'=>$Project->docket() ) ) {
						$PA->save({'skid_ids'=>[ sets::exclude( [ $Skid->id() ], $PA->skid_ids() ) ] });
						if ( ! $PA->Skids() ) {
							$PA->delete();
						} # end if
					} # end foreach
				} # end foreach C
			} else {
				my $PI = new openprint::PaperInventory();
				$PI->save({
						'docket'	=>	$Project->docket(),
						'paper_id'	=>	undef,,
						'user_id'	=>	$session{'user_id'},
						'delta'		=>	0,
						'comment'	=>	sprintf('Checked out for docket <a href="/employee/project/view.html?ProjectIndex=%1$d">%2$d</a> by %3$s', $Project->id(), $Project->docket(), new openprint::User( $session{'user_id'} )->name() ),
						'skid_id'	=>	$Skid->id(),
						'units'		=>	undef,
						});
			} # end if skid has contents
		} # end if add_entry
	} # end if
} # end sub _stock_checkout

sub _production_feedback {
	if ( $param{'action'} eq 'add' ) {
		my $PF= new openprint::ProductionFeedback();
		$variable{'error'} .= $PF->save({
				'project_id'	=>	$param{'project_id'},
				'service_id'	=>	$param{'service_id'},
				'user_id'		=>	$session{'user_id'},
				'starting_on'	=>	$param{'starting_on'},
				'ending_on'		=>	$param{'ending_on'},
				'comment'		=>	$param{'comment'},
			});
	} # end if
	$variable{'project_id'} = $param{'project_id'};
	$variable{'Project'} = new openprint::Project( $param{'project_id'} );
	$variable{'service_id'} = $param{'service_id'};
} # end sub _production_feedback
sub _stock_allocations {
	$variable{'Project'} = new openprint::Project( $param{'project_id'} );
}


1;

__END__
~	   
