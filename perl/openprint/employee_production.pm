package openprint::employee_production;
use strict;
use Date::Calc qw(Add_Delta_Days Date_to_Days check_date );
use MIME::QuotedPrint;

use openprint ();

require openprint::Project;
require openprint::order;
require openprint::service;
require openprint::Equipment;
require openprint::employee_project;
require openprint::employee_schedule;
require openprint::bindery_schedule;
require openprint::press_schedule;
require openprint::employee_project;

require sql;
require openprint::LabelType;
require openprint::Label;
require openprint::PurchaseOrder;
require openprint::PurchaseOrder_Content;
require openprint::PaperInventory;
require openprint::ProductionFeedback;
require openprint::Shift;
require openprint::Equipment_Shift;
require openprint::ScheduledJob;
require openprint::Project_Service;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub print_overview {
	if ( %param ) {
		if ( $param{'btnFunction'} eq 'Reset' ) {
			foreach my $param ( 'Equipment','schedule_start_year','schedule_start_month','schedule_start_day','schedule_end_year','schedule_end_month','schedule_end_day','pending','pending_approved', 'scale' ) {
				delete $session{'/employee/production/print_overview.html?'.$param};
			} # end if
		} else {
			ssi::save_params( '/employee/production/print_overview.html', ( 'Equipment','schedule_start_year','schedule_start_month','schedule_start_day','schedule_end_year','schedule_end_month','schedule_end_day', 'scale' ) );
		} # end if
	} elsif ( ( time - $session{'/employee/production/print_overview.html?lastupdated'} ) > 24*60*60 ) {
		foreach my $param ( 'Equipment','schedule_start_year','schedule_start_month','schedule_start_day','schedule_end_year','schedule_end_month','schedule_end_day','pending','pending_approved', 'scale' ) {
			delete $session{'/employee/production/print_overview.html?'.$param};
		} # end if
	} # end if
	$session{'/employee/production/print_overview.html?lastupdated'} = time;
	$variable{'referer'} = '/employee/production/print_overview.html';

	press_schedule();
} # end sub print_overview

sub press_schedule {

	if ( $param{'btnFunction'} eq 'Reflow' ) {
		my $Equipment = new openprint::Equipment( $param{'Equipment'} );
		if ( $Equipment->smartscheduling() ) {
			my @Jobs = openprint::ScheduledJob->find( 'starttime_null'=>0, 'equipment_id'=>$param{'Equipment'},'order'=>'starttime' );
			if ( @Jobs ) {
				reorder_jobs( @Jobs );
			} else {
				$variable{'error'} .= 'There are no jobs scheduled to reflow.';
			} # end if
		} else {
			$variable{'error'} .= 'Press does not support auto-scheduling.';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Add Docket' ) {
		my $Job = new openprint::ScheduledJob();

		if ( $param{'company_id'} ) {
			my $Project = new openprint::Project();
			$Project->save();
			$Project->company_id( $param{'company_id'} );
			$Project->reference( 'Dummy Docket' );
			$Project->status( 'Approved' );
			$Project->design( 'ElectronicFile' );
			$Project->save();
			openprint::print_project::insert_project_type( $r, $log, $dbh, $Project->id(), 'Custom' );
			my $project_id = $Project->id();
			my @services;
			foreach my $signature_count ( 1 .. $param{'forms'} ) {
				my $service_id = openprint::print_project::insert_service( $log, $dbh, $project_id, 'Signature' );
				push @services, $service_id;
				openprint::service::insert_service_spec( $log, $dbh, $project_id, $service_id, 'txtSignatureType', 'Signature' );
				openprint::service::insert_service_spec( $log, $dbh, $project_id, $service_id, 'txtServiceDescription', 'Additional Signature' );
				openprint::service::insert_service_spec( $log, $dbh, $project_id, $service_id, 'SignatureIndex', $signature_count );
				openprint::service::insert_service_spec( $log, $dbh, $project_id, $service_id, 'ImpressionQuantity', $param{'impressions'} );

				my $Equipment = new openprint::Equipment( $param{'press_id'} );
				openprint::service::insert_service_spec( $log, $dbh, $project_id, $service_id, 'UsePress', $Equipment->strid() );

				$Project->add_to_log( @session{'company_id','user_id'}, sprintf( 'Added Service: %s', 'Signature' ) );
			} # end foreach
			$Job->project_id( $Project->id() );
			$Job->service_id( \@services );
		} # end if

		if ( $param{'starttime_year'} ) {
			$Job->starttime( sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', @param{'starttime_year','starttime_month','starttime_day','starttime_hour','starttime_minute','starttime_second'} ) );
		} # end if
		my ( $h, $m, $s ) = split ':', $param{'runtime'};
		$h =~ s/\D//g;
		$m =~ s/\D//g;
		$s =~ s/\D//g;
		$s = 59 if ( $s > 59 );
		$m = 59 if ( $m > 59 );
		$variable{'error'} .= $Job->save({
				'equipment_id'	=> $param{'press_id'},
				'comment'		=> $param{'comment'},
				'locked'		=> $param{'locked'},
				'runtime'		=> $param{'runtime'} ? join(':', $h, $m, $s ) : undef,
				});

		%param = ();
	} elsif ( $param{'btnFunction'} eq 'ApproveJob' ) {
		my $Job = new openprint::ScheduledJob( $param{'schedule_id'} );
		my $Project = $Job->Project();
		if ( ! $Project->id() ) {
			$variable{'error'} .= "Invalid project specified for approve job";
			return;
		} # end if
		my $services = $Project->services();
		if ( ! ( $$services{'Proofs'} or $$services{'FilmStripping'} ) ) {
			$log->error("No proofs in project $$Project{id} adding them back");
			$variable{'error'} .= "no proofs in project.  Adding them back ";
			push @{$$services{'Proofs'}}, openprint::print_project::insert_service( $log, $dbh, $Project->id(), 'Proofs' );
		} # end if
		mark_proofs_approved( $log, $dbh, \%variable, $Project->id() );
		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $Project->id(), 'Waiting For Customer Approval'], 'strStatus', 'Complete' );
		$Project->add_to_log( @session{'company_id','user_id'}, 'Approved from print overview' );
		$Project->update_status();
	} elsif ( $param{'btnFunction'} eq 'RemoveJob' ) {
		if ( $param{'schedule_id'} ) {
			my $Job = new openprint::ScheduledJob( $param{'schedule_id'} );
			my @forms = map { my $sig_specs = openprint::service::get_specs_ref( $Job->Project(), $_ ); $$sig_specs{'SignatureIndex'}; } @{$Job->service_id()};
			if ( ( ! $Job->delete() ) and $$Job{'project_id'} ) {
				$Job->Project()->add_to_log( @session{'company_id','user_id'}, 'Form'. (@forms != 1 ? 's' : '') . join(',',@forms). ' removed from print schedule.' );
			} # end if
		} else {
			$variable{'error'} .= 'No job given to delete...';
		} # end if
	} # end if
	openprint::employee_schedule::add_missing_jobs_to_schedule( $log, $dbh );
} # end sub press_schedule

sub bindery_overview {

	my @time = localtime(time);
	my ( $start_year, $start_month, $start_day ) = Date::Calc::Add_Delta_Days( $time[5], $time[4]+1, $time[3], -6 );
	my ( $end_year, $end_month, $end_day ) = Date::Calc::Add_Delta_Days( $time[5], $time[4]+1, $time[3], 14 );
	$variable{'Today'} = sprintf('%.4d-%.2d-%.2d', $time[5]+1900, $time[4]+1, $time[3] );
	ssi::get_start_end_dates( $log, $dbh, \%variable,
			( defined $r->param('ddmStartYear') ? $r->param('ddmStartYear') : $start_year+1900 ),
			( defined $r->param('ddmStartMonth') ? $r->param('ddmStartMonth') : $start_month ),
			( defined $r->param('ddmStartDay') ? $r->param('ddmStartDay') : $start_day ),
			( defined $r->param('ddmEndYear') ? $r->param('ddmEndYear') : $end_year+1900 ),
			( defined $r->param('ddmEndMonth') ? $r->param('ddmEndMonth') : $end_month ),
			( defined $r->param('ddmEndDay') ?$r->param('ddmEndDay') : $end_day ),
			);

	my @possible_statuses = ( 'Approved','Printed','Complete' );
	my @statuses = $r->param('Status') ? sets::intersection( @possible_statuses , $r->param('Status') ) : ( 'Printed' );
	$variable{'Status'} = ssi::make_drop_down( [ map { $_, $_ } @possible_statuses ], [@statuses] );

	my %services = (
			'Cut'               => [ 'Cutting' ],
			'Fold, Perf, Score' => [ 'Folding', 'Perforating', 'Scoring' ],
			'Stitch'            => [ 'SaddleStitching', 'LoopStitching' ],
			'Drill'             => [ 'Drilling' ],
			'No Bindery'        => [ 'NoBindery' ],
			);
	my @Services;
	@{$variable{'DisplayServices'}} = sort keys %services;

	foreach my $service ( keys %services ) {
		if ( ! defined $r->param('btnFunction') or $r->param('chkViewServices'.$service) eq 'checked' ) {
			$variable{'chkViewServices'.$service} = 'checked';
			push @{$variable{'Services'}}, $service;
			push @Services, @{$services{$service}};
		} # end if
	} # end foreach

	$_ = "SELECT Projects.id, Orders.id, Projects.lngDocketNumber, Projects.company_id";
	$_ .= ", intQuantityIndex, due_date, Projects.strStatus\n";
	$_ .=" FROM Projects, Order_Contents, Orders";
	$_ .= " WHERE Projects.strStatus IN ( '". join("','", @statuses ) ."' )";
	$_ .= " AND Orders.id=Order_Contents.OrderIndex AND Orders.strStatus='In Production'";
	$_ .= " AND Projects.id = Order_Contents.lngProjectIndex";
	$_ .= " AND due_date BETWEEN '$variable{'StartDate'}' AND '$variable{'EndDate'}'";
	$_ .= " AND Orders.lngEmployeeID=".$r->param('ddmSalesRep') if $r->param('ddmSalesRep');
	$_ .= " ORDER BY due_date";
	my @projects = sql::execute( $log, $dbh, $_ );

	@{$variable{'Projects'}} = ();
	while ( my ( $project_index, $order_id, $docket, $company_id, $qty_index, $date_required, $status ) = splice @projects, 0, 7 ) {
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
						my ($runtime) = openprint::service::get_specifications( $log, $dbh, $project_index, $service_index, 'txtRunTime'.$qty_index );
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

		my $services = $Project->services();
#my %printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $service_indices{''} );
		my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

		my @BinderyServices = ();
		if ( my %bindery_services = openprint::print_project::get_services_in_category( $log, $dbh, $project_index, 'Bindery' ) ) {
			$_ = 'SELECT name FROM Service_Types WHERE id IN ( ' . join(',', @bindery_services{keys %bindery_services} ) . ')';
			@BinderyServices = sql::execute( $log, $dbh, $_ );
		} # end if

		if ( ! $$printing_specs{'txtQuantity'.$qty_index} ) {
			$$printing_specs{'txtQuantity'.$qty_index} = $Project->quantity( $qty_index );
		} # end if
		my $description = $$printing_specs{'txtQuantity'.$qty_index};

		if ( ! @BinderyServices ) {
			$description .= ' Ship Flat';
		} elsif ( sets::isin( 'No Bindery', \@BinderyServices ) ) {
			$description .= ' Ship Flat';
		} else {
			if ( ! @service_indices{'SaddleStitching','Loop Stitching'} ) {
				if ( $service_indices{'Cutting'} and ! $service_indices{'Folding'} ) {
					$description .= ', ' . $$printing_specs{'txtFinalWidth'} . 'x'  . $$printing_specs{'txtFinalHeight'};
				} # end if
				if ( $service_indices{'Folding'} ) {
					$description .= ', '. $$printing_specs{'txtWidth'} . 'x' . $$printing_specs{'txtHeight'} . ' > ' . $$printing_specs{'txtFinalWidth'} . 'x'  . $$printing_specs{'txtFinalHeight'};
				} # end if
			} # end if

			if ( $$printing_specs{'txtTotalPageQuantity'} ) {
				$description .= ', ';
				if ( $$printing_specs{'rdbCover'} eq 'DifferentCover' ) {
					$description .= $$printing_specs{'txtTotalPageQuantity'} -4 . 'pp+C';
				} else {
					$description .= $$printing_specs{'txtTotalPageQuantity'} . 'pp';
				} # end if
				$description .= ', ' . $$printing_specs{'txtFinalWidth'} . 'x' . $$printing_specs{'txtFinalHeight'};

				if ( $$printing_specs{'txtInsertQuantity'} ) {
					$description .= ' with ' . $$printing_specs{'txtInsertQuantity'} . ' Inserts Page ' . $$printing_specs{'Page1'} . ' and page ' . $$printing_specs{'Page2'};
				} # end if
			} # end if
		} # end if

		if ( $$printing_specs{'txtSignatureQuantity'} ) {
			$description .= $$printing_specs{'txtSignatureQuantity'} . '-';

			if ( $$printing_specs{'txtSignatureQty2Page'} ) { $description .= '2pp' };
			if ( $$printing_specs{'txtSignatureQty4Page'} ) { $description .= '4pp' };
			if ( $$printing_specs{'txtSignatureQty8Page'} ) { $description .= '8pp' };
			if ( $$printing_specs{'txtSignatureQty12Page'} ) { $description .= '12pp' };
			if ( $$printing_specs{'txtSignatureQty16Page'} ) { $description .= '16pp' };
			if ( $$printing_specs{'txtSignatureQty20Page'} ) { $description .= '20pp' };
			if ( $$printing_specs{'txtSignatureQty24Page'} ) { $description .= '24pp' };
			if ( $$printing_specs{'txtSignatureQty32Page'} ) { $description .= '32pp' };
			if ( $$printing_specs{'txtSignatureQtySingleGateFolded'} ) { $description .= 'Single Gate Folded' };
			if ( $$printing_specs{'txtSignatureQtyDoubleGateFolded'} ) { $description .= 'Double Gate Folded' };
		} # end if

		if ( sets::intersection( @Services, keys %service_indices ) ) {
			push @{$variable{'Projects'}}, $project_index, $order_id, $docket, new openprint::Company( $company_id )->name(), $description,$date_required;
			foreach my $service_type ( @{$variable{'Services'}} ) {
				if ( defined $times{$service_type} ) {
					if ( $times{$service_type} ne 'done' ) {
						$times{$service_type} = int($times{$service_type}/360) . ':' . int(($times{$service_type}%360)/60);
					} # end if
				} else {
					$times{$service_type} = 'n/a';
				} # end if
				push @{$variable{'Projects'}}, $times{$service_type};
			} # end foreach
		} # end if
	} # end while

	if ( $r->param('btnFunction') eq 'Download in CSV format' ) {
		my @header = ('Docket #','Company Name', 'Description', 'Date Required');
		foreach my $service_type ( @{$variable{'Services'}} ) {
			push @header, $service_type;
		} # end foreach
		my @data;
		while ( @{$variable{'Projects'}} ) {
			my ( $project_index, $order_id, $docket, $company, $description, $date_required ) = splice @{$variable{'Projects'}}, 0, 6;
			push @data, $docket, $company, $description, $date_required;
			foreach my $service_type ( @{$variable{'Services'}} ) {
				push @data, shift @{$variable{'Projects'}};
			} # end foreach
		} # end while
		misc::export_csv( $r, $log, \%variable, 'bindery_overview.csv', \@header, \@data );
	} # end if
} # end sub bindery_overview

sub projects {

	ssi::save_params( '/employee/production/projects.html', 'DueDateStartYear','DueDateStartMonth','DueDateStartDay', 'DueDateEndYear','DueDateEndMonth','DueDateEndDay', 'ProjectStatus', 'ddmSalesRep', 'ddmEmployee', 'ddmCustomer', 'ddmPress' );
	my @projects;

	my $startdocket = $param{'StartDocket'};
	my $enddocket = $param{'EndDocket'};
	my $project_index = $param{'Project'};
	my $order_id = $param{'OrderID'};

	$startdocket =~ s/\D//g;
	$enddocket =~ s/\D//g;
	$project_index =~ s/\D//g;
	$order_id =~ s/\D//g;

	if ( $param{'btnFunction'} eq 'Go' ) {
		if ( $project_index ) {
			@projects = ( new openprint::Project( $project_index ) );
		} elsif ( $order_id ) {
			my $Order = new openprint::Order( $order_id );
			@projects = $Order->Projects();
		} elsif ( $startdocket and $enddocket ) {
			@projects = openprint::Project->find( 'docket_start'=>$startdocket, 'docket_end' => $enddocket );
		} elsif ( $startdocket ) {
			@projects = openprint::Project->find( 'docket'=>$startdocket );
		} elsif ( $enddocket ) {
			@projects = openprint::Project->find( 'docket'=>$enddocket );
		} # end if
		if ( @projects == 1 ) {
			$order_id = $projects[0]->order_id();
			$variable{'Redirect'} = '/employee/project/view.html';
			$param{'OrderID'} = $order_id;
			$param{'ProjectIndex'} = @projects[0]->id();
			return;
		} # end if
	} elsif ( $param{'order_id'} ) {
		$param{'order_id'} =~ s/\D//g;
		if ( $param{'order_id'} ) {
			my $Order = new openprint::Order( $param{'order_id'} );
			@projects = $Order->Projects();
		} # end if
		if ( @projects == 1 ) {
			$order_id = $projects[0]->order_id();
			$variable{'Redirect'} = '/employee/project/view.html';
			$param{'OrderID'} = $order_id;
			$param{'ProjectIndex'} = @projects[0]->id();
			return;
		} # end if
	} # end if

	$variable{'txtDocket'} = $param{'txtDocket'};

} # end sub projects

sub _project_list {
	ssi::save_params( '/employee/production/projects.html', 'DueDateStartYear','DueDateStartMonth','DueDateStartDay', 'DueDateEndYear','DueDateEndMonth','DueDateEndDay', 'ProjectStatus', 'ddmSalesRep', 'ddmEmployee', 'ddmCustomer', 'ddmPress' );
}

sub send_additional_charges_notifications {
	my ( $r, $log, $dbh, $order_id, $project_index ) = @_;
# Email CSR
	my %info;
	$info{'ProjectIndex'} = $project_index;
	$info{'OrderID'} = $order_id;

	my $Order = new openprint::Order( $order_id );
	my $CSR = new openprint::User( $Order->salesrep_id() );
	my $Operator = new openprint::User( $session{'user_id'} );

	@info{'CSRFirstName','CSRLastName','CSREmail'} = ( $CSR->firstname(), $CSR->lastname(), $CSR->email() );

	@info{'CustomerFirstName','CustomerLastName','CustomerEmail'} = ( $Order->firstname(), $Order->lastname(), $Order->email() );
	@info{'OperatorFirstName','OperatorLastName','OperatorEmail'} = ( $Operator->firstname(), $Operator->lastname(), $Operator->email() );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $Operator->firstname(), $Operator->lastname(), $Operator->email(), $Operator->extension() );

	$info{'CompletionDate'} = Date::Format::time2str( $config{'DateTimeFormat'}, time );
	$info{'SecureSiteURL'} = $r->dir_config('ExternalSecureSiteURL');
	$info{'siteURL'} = $r->dir_config('ExternalSiteURL');

	my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );

#$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/additional_charges_csr_notification.html\"-->";
#$_ = encode_qp( ssi::variable_substitution( $email_template, \%info ) );
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
	$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
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
	my $Project = new openprint::Project( $project_index );
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
							'strDescription',   $param{'txtDescription'.$index}
							] );
				} else {
					sql::update( $log, $dbh, 'tbl_Project_PDFs', ['lngProjectIndex=? AND strFileName=?', $project_index, $filename ],
							'strDescription',   $param{'txtDescription'.$index}
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
	@info{'CustomerFirstName','CustomerLastName','CustomerEmail'} = ( $Order->firstname(), $Order->lastname(), $Order->email() );

	my $User = new openprint::User( $session{'user_id'} );
	@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = ( $User->firstname(), $User->lastname(), $User->email(), $User->extension() );

	$info{'CompletionDate'} = Date::Format::time2str( $config{'DateTimeFormat'}, time );

	$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/proofs_complete.html' );
	$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

	$_ = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
	$_ = encode_qp( ssi::variable_substitution( \$_, \%info ) );
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
#$_ = encode_qp( ssi::variable_substitution( $email_template, \%info ) );
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

sub send_duedate_change_notification {
	my ( $r, $log, $dbh, $variable, $project_index, $order_id ) = @_;

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
		my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
		$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/proofs_duedate_change-sales_rep.html\"-->";
		$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
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

sub load_press_completion {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	$variable{'Project'} = new openprint::Project( $project_index );

	foreach my $signature_service_index ( $variable{'Project'}->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $variable{'Project'}, $signature_service_index );
		push @{$variable{'Signatures'}}, @$specs{'SignatureIndex','txtServiceDescription'};

		$variable{"txtEmployeeName-$$specs{'SignatureIndex'}"} = new openprint::User( sql::execute( undef, undef, 'SELECT operator_id FROM tbl_Project_COntents WHERE lngProjectIndex=? AND lngServiceIndex=?', $project_index, $signature_service_index ) )->name();

		@variable{
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
		$variable{"UsedStockQuantity-$$specs{'SignatureIndex'}"} = $$specs{'txtPressSheetQty'.$variable{'Project'}->ordered_quantity_index()} if ! $variable{"UsedStockQuantity-$$specs{'SignatureIndex'}"};
		$variable{"UsedStockType-$$specs{'SignatureIndex'}"} = $$specs{'StockType'.$variable{'Project'}->ordered_quantity_index()} if ! $variable{"UsedStockType-$$specs{'SignatureIndex'}"};
		$variable{"UsedImposition-$$specs{'SignatureIndex'}"} = $$specs{'txtImposition'.$variable{'Project'}->ordered_quantity_index()} if ! $variable{"UsedImposition-$$specs{'SignatureIndex'}"};
		$variable{"UsedColumns-$$specs{'SignatureIndex'}"} = $$specs{'hdnImpositionColumns'.$variable{'Project'}->ordered_quantity_index()} if ! $variable{"UsedColumns-$$specs{'SignatureIndex'}"};
		$variable{"UsedRows-$$specs{'SignatureIndex'}"} = $$specs{'hdnImpositionRows'.$variable{'Project'}->ordered_quantity_index()} if ! $variable{"UsedRows-$$specs{'SignatureIndex'}"};
		$variable{"UsedDutchColumns-$$specs{'SignatureIndex'}"} = $$specs{'hdnImpositionDutchColumns'.$variable{'Project'}->ordered_quantity_index()} if ! $variable{"UsedDutchColumns-$$specs{'SignatureIndex'}"};
		$variable{"UsedDutchRows-$$specs{'SignatureIndex'}"} = $$specs{'hdnImpositionDutchRows'.$variable{'Project'}->ordered_quantity_index()} if ! $variable{"UsedDutchRows-$$specs{'SignatureIndex'}"};
		$variable{"UsedRunStyle-$$specs{'SignatureIndex'}"} = $$specs{'ddmRunStyle'.$variable{'Project'}->ordered_quantity_index()} if ! $variable{"UsedRunStyle-$$specs{'SignatureIndex'}"};

		$variable{"UsePress-$$specs{'SignatureIndex'}"} = $$specs{'ddmPress'.$variable{'Project'}->ordered_quantity_index()} if ! $variable{"UsePress-$$specs{'SignatureIndex'}"};
		if ( ! $variable{"UsedStockSheetSize-$$specs{'SignatureIndex'}"} ) {
			if ( $$specs{'StockType'.$variable{'Project'}->ordered_quantity_index()} eq 'Roll' ) {
				$variable{"UsedStockSheetSize-$$specs{'SignatureIndex'}"} = $$specs{'StockWidth'.$variable{'Project'}->ordered_quantity_index()};
			} else {
				$variable{"UsedStockSheetSize-$$specs{'SignatureIndex'}"} = $$specs{'StockWidth'.$variable{'Project'}->ordered_quantity_index()} .'x'.$$specs{'StockHeight'.$variable{'Project'}->ordered_quantity_index()};
			} # end if
		} # end if
	} # end foreach signature_service_index

} # end sub load_press_completion

sub is_sig_complete {
	my ( $r, $log, $dbh, $project_index, $signature_service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $printing_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
	if ( $r->param("rdbPressComplete-$$printing_specs{'SignatureIndex'}") ne 'Yes' ) {
		$Project->add_to_log( @session{'company_id','user_id'}, "Marking form $$printing_specs{'SignatureIndex'} incomplete." );
		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $signature_service_index], 'strStatus','Ordered' );
		return 0;
	} # end if
	$Project->add_to_log( @session{'company_id','user_id'}, "Marking form $$printing_specs{'SignatureIndex'} complete." );
	sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $signature_service_index], 'strStatus','Complete' );

# Remove jobs from the Schedule when marked complete.
	foreach my $Job ( openprint::ScheduledJob->find( 'project_id'=>$project_index, 'service_id'=>$signature_service_index ) ) {
		$Job->delete();
	} # end foreach Job

	return 1;
} # end sub is_sig_complete

sub barcode {
	foreach my $param ( 'Project', 'Action', 'Operator','Order' ) {
		$param{$param} =~ s/\D//g;
	} # end foreach param

	@param{'Order'} = sql::execute( $log, $dbh, q{SELECT  MAX(OrderIndex) FROM Order_Contents WHERE lngProjectIndex=?}, $param{'Project'} ) if ( ! $param{'Order'} ) and $param{'Project'};
	my %operators = map { $_->id(), $_->name() } openprint::User->find('type'=>['E','A']);

	if ( $param{'Project'} or $param{'Action'} or $param{'Operator'} ) {
		if ( ! $param{'Project'} ) {
			$variable{'Error'} = 'No Project ID given.';
			return;
		} # end if
		if ( ! $param{'Action'} ) {
			$variable{'Error'} .= 'No Action given.';
			return;
		} # end if
		if ( ! $param{'Operator'} ) {
			$variable{'Error'} .= 'No Operator given';
			return;
		} # end if
		if ( ! $operators{$param{'Operator'}} ) {
			$variable{'Error'} = 'Invalid Operator specified.  Please try again';
			return;
		} # end if
	} else {
		return;
	} # end if

	my $Project = new openprint::Project( $param{'Project'} );

	my %services = $Project->get_services();

	my $message;
	my $docket_id = $Project->docket();

	if ( $param{'Action'} == 1 ) { # Assign Prepress Operator

		my ( $service_index, $old_operator_id ) = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, operator_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $Project->id(), $services{'Proofs'} ? $services{'Proofs'} : $services{'FilmStripping'} );

		if ( ! $service_index ) {
			$variable{'Error'} = "Could not locate Proofs or FilmStripping Service for docket $docket_id";
			$message = "Could not locate Proofs or FilmStripping Service for docket $docket_id";
			return;
		} # end if

		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $Project->id(), $service_index],
				'operator_id', $param{'Operator'},
				'starttime',    'NOW()',
				);
		if ( ! $old_operator_id ) {
			$message .= "Assigning Prepress Operator for project $param{'Project'} to $operators{$param{'Operator'}}";
		} elsif ( $param{'Operator'} != $old_operator_id ) {
			$message .= "Assigning Prepress Operator for project $param{'Project'} from $operators{$old_operator_id} to $operators{$param{'operator'}}";
		} else {
			$message .= "Setting Prepress Operator for project $param{'Project'} to $operators{$param{'Operator'}}";
		} # end if
		$Project->add_to_log( @session{'company_id','user_id'}, $message );
	} elsif ( $param{'Action'} == 2 ) { # Proofs Out
		my ( $service_index, $old_operator_id, $status ) = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, operator_id, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $Project->id(), ( $services{'Proofs'} ? $services{'Proofs'} : $services{'FilmStripping'} ) );

		if ( ! $service_index ) {
			$variable{'Error'} = "Could not locate Proofs or FilmStripping Service for docket $docket_id";
			return;
		} # end if

		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_index, 'rdbComplete', 'Yes' );
		$Project->add_to_log( $session{'company_id'}, $param{'Operator'}, "Marked Proofs Proofs Out from $status via barcode" );
		openprint::service::status( $Project->id(), $service_index, 'Proofs Out' );
		$message = sprintf( 'Marked project %d Proofs Out from %s', $Project->id(), $status );

#send_proofs_complete_email( $project_index, $order_id );
	} elsif ( $param{'Action'} == 3 ) { # Proofs Approved
		my ( $service_index, $old_operator_id, $status ) = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, operator_id, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $Project->id(), ( $services{'Proofs'} ? $services{'Proofs'} : $services{'FilmStripping'} ) );

		if ( ! $service_index ) {
			$variable{'Error'} = "Could not locate Proofs or FilmStripping Service for docket $docket_id";
			return;
		} # end if
		$message = sprintf('Marked project %d Approved from %s<br/>Notified CSR', $Project->id(), $status );
		$Project->due_date( $Project->get_due_date() );
		$Project->save();
		mark_proofs_approved( $log, $dbh, \%variable, $Project->id(), $service_index, $status );
		openprint::employee_project::send_proofs_approved_email( $Project->id(), $param{'Order'} );
	} elsif ( $param{'Action'} == 4 ) { # Unassign Operator
		my ( $service_index, $old_operator_id ) = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, operator_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $Project->id(), $services{'Proofs'} ? $services{'Proofs'} : $services{'FilmStripping'} );

		if ( ! $service_index ) {
			$variable{'Error'} = 'Could not locate Proofs or FilmStripping Service';
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
		$Project->add_to_log( $session{'company_id'}, $param{'Operator'}, $message );
	} elsif ( $param{'Action'} == 20 ) { # Project Printed
		$Project->status_change( $session{'company_id'}, $param{'Operator'}, 'Complete' );
		$message = sprintf('Project %d marked Printed', $Project->id() );
	} elsif ( $param{'Action'} == 30 ) { # Project Complete
		$Project->status_change( $session{'company_id'}, $param{'Operator'}, 'Complete' );
		$message = sprintf('Project %d marked Complete', $Project->id() );
	} elsif ( $param{'Action'} == 40 ) { # Project Shipped
		$Project->status_change( $session{'company_id'}, $param{'Operator'}, 'Shipped' );
		$message = sprintf('Project %d marked Shipped', $Project->id() );
	} elsif ( $param{'Action'} == 50 ) { # Project Picked Up
		$Project->status_change( $session{'company_id'}, $param{'Operator'}, 'Picked Up' );
		$message = sprintf('Marked project %d as Picked Up', $Project->id() );
	} elsif ( $param{'Action'} == 60 ) { # Project Bindery Complete
		$Project->status_change( $session{'company_id'}, $param{'Operator'}, 'Bindery Complete' );
		$message = sprintf('Marked project %d as Bindery Complete', $Project->id() );
	} elsif ( $param{'Action'} == 70 ) { # Project Out For Outside Finishing
		$message = sprintf('Marked project %d as Out For Finishing', $Project->id() );
		$Project->add_to_log( @session{'company_id','user_id'}, 'Marked Out For Finishing' );
	} elsif ( $param{'Action'} == 80 ) { # Project Returned From Outside Finishing
		$message = sprintf('Marked project %d as Returned From Finishing', $Project->id() );
		$Project->add_to_log( @session{'company_id','user_id'}, 'Marked Returned From Finishing' );
	} else {
		$variable{'Error'} = "Unimplemented action code $param{'Action'}";
	} # end if
	if ( $param{'Action'} ) {
		add_to_barcode_log( $log, $dbh, \%variable, $Project->id(), $docket_id, $param{'Operator'}, $message );
#$variable{'Results'} = sprintf('<tr><td>%.4d-%.2d-%.2d %.2d:%.2d:%.2d</td><td>%s</td><td><a href="/employee/project/view.html?ProjectIndex=%d&OrderID=%d">%d</a></td><td>%s</td></tr>', Date::Calc::Today_and_Now(), $operators{$operator}, $project_index, $order_id, $docket_id, $message ) . $variable{'Results'};
		$Project->update_status();
		my $Order = new openprint::Order( $param{'Order'} );
		$Order->update_status();
	} # end if

} # end sub barcode

sub mark_proofs_approved {
	my ( $log, $dbh, $variable, $project_index, $service_index, $old_status ) = @_;

	my $Project = new openprint::Project( $project_index );
	if ( ! $service_index ) {
		my $services = $Project->services();
		$service_index = $$services{'Proofs'} ? $$services{'Proofs'}[0] : $$services{'FilmStripping'}[0];
	} # end if
	if ( ! $service_index ) {
		$log->error("Project $project_index has no Proofs service in mark_proofs_approved.");
	} # end if

	$Project->add_to_log( @session{'company_id','user_id'}, "Marked Proofs Approved from $old_status" );
	$variable{'Project'} = $Project;
# Mark Service as Approved
	sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], 'strStatus', 'Approved' );

	my $approval_date = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', Date::Calc::Today_and_Now() );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'ApprovalDate', $approval_date );
} # end sub mark_proofs_approved


sub add_to_barcode_log {
	my ( $log, $dbh, $variable, $project_id, $docket, $operator_id, $desc ) = @_;

	sql::insert( $log, $dbh, 'Barcode_Log',
			'project_id',   $project_id,
			'docketnumber', $docket,
			'user_id',      $session{'user_id'},
			'operator_id',  $operator_id,
			'dtmTimestamp', 'NOW()',
			'Description',  $desc,
			);
} # end sub add_to_barcode_log

sub complete_signature {
	my ( $log, $dbh, $variable, $project_id, $service_id ) = @_;

	my $ac = sql::start_transaction( $dbh );
	my $Project = new openprint::Project( $project_id );
	my $Service = $Project->Service( $service_id );
	$Service->save({'status'=>'Complete'});
	my $specs = $Service->specs();

	sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_id, $service_id], 'strStatus', 'Complete' );
# Remove from Print Schedule
	foreach my $Job ( openprint::ScheduledJob->find( 'project_id'=>$project_id, 'service_id'=>$service_id ) ) {
		$Job->delete();
	} # end foreach Job
# Update Bindery Schedule
	sql::update( $log, $dbh, 'Bindery_Schedule', ['ProjectIndex=?', $project_id], 'starttime', 
			sql::execute( $log, $dbh, q{SELECT NOW() + '2 hours'::interval} )
			);
	$Project->add_to_log( @session{'company_id','user_id'}, "Form $$specs{'SignatureIndex'} Completed". ( $Service->operator_id() != $session{user_id} ? ' for ' . $Service->Operator()->name() : '' ) );
	sql::end_transaction( $dbh, $ac );
} # end sub complete_signature

sub docket_sheet {
	openprint::print_project::summary( @_ );
} # end sub docket_sheet
sub summary {
	openprint::print_project::summary( @_ );
} # end sub summary

sub monthly_schedule {

	if ( $param{'btnFunction'} eq 'MakeReservation' ) {
		my $Job = new openprint::ScheduledJob();
		$variable{'error'} .= $Job->save( {
				'starttime'		=>	sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'StartYear','StartMonth','StartDay'}),
				'equipment_id'	=>	$param{'Press'},
				'runtime'		=>	sprintf('%.2d:%.2d:%.2d', $param{'hours'}, 0, 0),
				} );
	} # end if
} # end sub monthly_schedule

sub _labels {
	my $Label = new openprint::Label( $param{'id'} );
	if ( $param{'action'} eq 'delete' ) {
		$Label->delete();
	} elsif ( $param{'action'} eq 'copy' ) {
		$Label = $Label->copy();
		$Label->save();
	} # end if
	$variable{'Project'} = new openprint::Project( $param{'project_id'} );
} # end sub _labels

sub _stock_popup {
	$variable{'Job'} = new openprint::ScheduledJob( $param{'schedule_id'} );
	$variable{'Project'} = $variable{'Job'}->Project();
} # end sub _stock_popup

sub _stock_details {
	$variable{'Project'} = new openprint::Project( $param{'project_id'} );
} # end sub _stock_details

sub _stock_checkout {
	openprint::employee_project::_stock_checkout();
} # end sub _stock_checkout

sub _bump_job {
	$variable{'Job'} = new openprint::ScheduledJob( $param{'schedule_id'} );
} # end sub _bump_job

sub _pending_approved {
	my ( $referer ) = $ENV{'HTTP_REFERER'} =~ /^https?:\/\/[^\/:]+([^?]*).*$/;
	$variable{'referer'} = $referer;
$log->debug("REFERRER ($referer)");

	$session{$referer.'?pending_approved'} = $session{$referer.'?pending_approved'} ? 0 : 1;
    @{$variable{'Equipment'}} = ();
	if ( $session{$referer.'?pending_approved'} ) {
		foreach my $equipment_id ( split(';', $session{$referer.'?Equipment'} ) ) {
			my $E = new openprint::Equipment( $equipment_id );
			push @{$variable{'Equipment'}}, $E if $E->id();
		} # end foreach
	} # end if
$log->debug("Equipment: @{$variable{'Equipment'}}");
} # end sub _pending_approved

sub _pending {
	my ( $referer ) = $ENV{'HTTP_REFERER'} =~ /^https?:\/\/[^\/:]+([^?]*).*$/;
	$variable{'referer'} = $referer;
$log->debug("REFERRER ($ENV{'HTTP_REFERER'}) ($referer)");
	$session{$referer.'?pending'} = $session{$referer.'?pending'} ? 0 : 1;
    @{$variable{'Equipment'}} = ();
	if ( $session{$referer.'?pending'} ) {
		foreach my $equipment_id ( split(';', $session{$referer.'?Equipment'} ) ) {
			my $E = new openprint::Equipment( $equipment_id );
			push @{$variable{'Equipment'}}, $E if $E->id();
		} # end foreach
	} # end if
} # end sub _pending

sub _ul {
	if ( $param{'action'} eq 'split' ) {
		my $Job = new openprint::ScheduledJob( $param{'schedule_id'} );
		$Job->split( $param{'new_form_count'} );
		$variable{'Shift'} = $Job->Shift();
	} # end if
	if ( $param{'shift_id'} ) {
		$variable{'Shift'} = new openprint::Shift( $param{'shift_id'} );
	} elsif ( $param{'ul_id'} ) {
		$variable{'Shift'} = openprint::Shift::get_from_ul_id( $param{'ul_id'} );
		if ( ! $variable{'Shift'} ) {
			$variable{'error'} .= "Unable to find shift for $param{'ul_id'}";
		} # end if
	} else {
$log->debug("No Shift specified!");
	} # end if
	if ( $variable{'Shift'} ) {
		$log->debug("_ul for: $variable{'Shift'}{id} " . $variable{'Shift'}->to_string() );
	} else {
		$variable{'Shift'} = new openprint::Shift();
	} # en dif
} # end sub _ul

sub _drop {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do( 'LOCK TABLE Schedule IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
	my $Shift = openprint::Shift::get_from_ul_id( $param{'ul_id'} );
	my $Equipment = $Shift->Equipment(); # For efficiency

	# Force it to redraw the changed UL, since the runtimes are likely to have changed.
	@{$variable{'changed'}} = ( $Shift->ul_id() );

if ( 0 ) {
	if ( $Shift->starttime() and ! $Shift->operator_id() ) {
		$variable{'alert'} .= 'Shifts must have an operator in order to schedule jobs in them.';
		reorder_jobs(openprint::ScheduledJob->find( 'equipment_id'=>$Shift->equipment_id(),'starttime_null'=>0,'order'=>'starttime' ));
		return;
	} # end if
} # end if

	if ( exists $param{'services'} ) {
		my $services = $param{'services'};
		$services =~ s/$param{ul_id}\[\]=//g;
		my @order = split( '&', $services );
		return if ! @order;


		# Coalesce Jobs
$log->debug("Order before coalesce: @order");
		my $previous;
		for ( my $i = 0; $i < @order; $i += 1 ) {
			my $row_id = $order[$i];
			my $Job = new openprint::ScheduledJob( $row_id );
			if ( ( $Equipment->category() eq 'Bindery' ) and ! sets::isin( $Job->servicetype_id(), $Equipment->servicetype_id() ) ) {
$log->debug("Bindery:, servicetypes different");
				my $Project = $Job->Project();
				my $services = $Project->services();
				my @Jobs;
				foreach my $servicetype_id ( @{$Equipment->servicetype_id()} ) {
					my $ST = new openprint::ServiceType( $servicetype_id );
					next if ( ! $$services{$ST->name()} ) or ! @{$$services{$ST->name()}};
$log->debug("Dong Job for $servicetype_id : " . $ST->name() );
					# Get all already existing jobs for this servicetype
					foreach my $service_id ( @{$$services{$ST->name()}} ) {
						my @J = openprint::ScheduledJob::find('project_id'=>$Project->id(),'service_id'=>$service_id);
						if ( ! @J ) {
							# Create a new Job
							my $J = new openprint::ScheduledJob();
							$J->save({
									'project_id'	=>	$Project->id(),
									'service_id'	=>	[ $service_id ],
									'servicetype_id'	=>	$servicetype_id,
									'equipment_id'		=>	$Equipment->id(),
									'pertains_id'		=>	[ $Job->Project()->signatures() ],
									});
							push @Jobs, $J;
						} else {
							push @Jobs, @J;
						} # end found a job or not
					} # end foreach service_id
				} # end foreach servicetype_id
				if ( ! @Jobs ) {
					$variable{'alert'} .= 'Docket ' . $Project->docket() . ' is not appropriate for ' . $Equipment->name() . '\n';
					splice @order, $i, 1;
					$i -= 1;
					next;
				} # end if
				my @job_ids = sets::union( map { $_->id() } @Jobs );

#$log->debug("Jobs for  " . join(',',@job_ids ) );
				# If any of these jobs were in the list, remove them so they move up instead of getting duplicated.
				@order = sets::exclude( \@job_ids, \@order ); 
				if ( @order ) {
#$log->debug("Order @order");
					while ( $i and $order[$i] != $row_id ) {
						$i -= 1;
#$log->debug("Decreasing i to $i");
					} # end while
					splice @order, $i, 1, @job_ids;
				} else {
					push @order, @job_ids;
				} # end if
				$i -= 1;
				next;
			} # end if different servicetype
#$log->debug("Order before coalesce: @order : " . join(',', map { new openprint::ScheduledJob($_)->Project()->docket() } @order ) );
			if ( $previous and $previous->project_id() and $Job->project_id() and ( $previous->project_id() == $Job->project_id() ) ) {
				my $sig_specs1 = openprint::service::get_specs_ref( $previous->Project(), $$previous{'service_id'}[0] );
				my $sig_specs2 = openprint::service::get_specs_ref( $Job->Project(), $$Job{'service_id'}[0] );
				if ( eval 'openprint::Estimating::'.$Job->ServiceType()->name().'::compare_signatures( $sig_specs1, $sig_specs2, $Job->Project()->ordered_quantity_index() )' ) {
#$log->debug("Sigs are the same, coalescing ");
					$_ = $previous->save({
							'runtime'		=>	Date::Format::time2str( '%H:%M:%S', $previous->runtime_seconds() + $Job->runtime_seconds() ),
							'service_id'	=>	[ @{$$previous{'service_id'}}, @{$$Job{'service_id'}} ],	
							});
					if ( $_ ) {
						$log->error($_);
					} else {
						$Job->delete();
						@order = sets::exclude( [ $row_id ], \@order );
					} # end if
				} # end if
				$previous = undef;
			} else {
$log->debug("Sigs are the not same, " . $Job->Project()->ordered_quantity_index() );
				$previous = $Job;
			} # end if
		} # end foreach row_id

$log->debug("Order after coalesce: @order : " . join(',', map { new openprint::ScheduledJob($_)->Project()->docket() } @order ) );

		if ( ! $Equipment->smartscheduling() ) {
	sql::end_transaction( $dbh, $ac );
$log->debug("Old");
			return openprint::employee_schedule::drop_project( $r, $log, $dbh, \%variable, $param{'ul_id'}, $param{'services'} );
$log->debug("Old2");
		} else {
			$dbh->do( 'LOCK TABLE Shifts IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );

			if ( $Shift->starttime() ) {
				my @final_order;
# Get jobs before the shift, leave them in order.
				foreach my $row ( openprint::ScheduledJob->find( 'equipment_id'=>$Shift->equipment_id(),'starttime_<'=>$Shift->starttime(),'servicetype_id'=>$Equipment->servicetype_id(), 'order'=>'starttime' ) ) {
					push @final_order, $row if ! sets::isin( $$row{'id'}, \@order );
				} # end foreach row

# Get the rest of the jobs on this equipment
				my @jobs = openprint::ScheduledJob->find( 'equipment_id'=>$Shift->equipment_id(),'starttime_start'=>$Shift->starttime(),'servicetype_id'=>$Equipment->servicetype_id(), 'order'=>'starttime' );

# Search for each job in the list of remaining jobs.  If we don't find it, it might be on another press.
				foreach my $row_id ( @order ) {
					my $found = 0;
					for ( my $j = 0; $j < @jobs; $j += 1 ) {
						my $row = $jobs[$j];
						if ( $$row{'id'} == $row_id ) {
							push @final_order, $row;
							splice @jobs, $j, 1;
							$found = 1;
							last;
						} # end if
					} # end foreach job
					if ( ! $found ) {
# Must be on another press.
						my $Job = new openprint::ScheduledJob( $row_id );
						$Job->equipment_id( $Shift->equipment_id() );
						push @final_order, $Job;
					} # end if
				} # end foreach row_id
				reorder_jobs( @final_order, @jobs );
			} else { # has starttime
# Pending or Approved
				my $was_scheduled = 0;
				foreach my $row_id ( @order ) {
					my $Job = new openprint::ScheduledJob( $row_id );
					$was_scheduled = 1 if $$Job{'starttime'};
					$Job->save({starttime=>undef,equipment_id=>$Shift->equipment_id()}) if $Job->starttime() or ( $Job->equipment_id() != $Shift->equipment_id() );
				} # end foreach row_id
# If it was a formerly scheduled job, then shuffle
				reorder_jobs(openprint::ScheduledJob->find( 'equipment_id'=>$Shift->equipment_id(),'starttime_null'=>0,'servicetype_id'=>$Equipment->servicetype_id(), 'order'=>'starttime' )) if $was_scheduled;
			} # end if	has starttime
	sql::end_transaction( $dbh, $ac );
		} # end if

	} # end if services

	# If there is a changed ul that is newer than our filter, it won't be shown, but a redraw will happen.... so we should adjust the filter to show it.
	my $filter_seconds = Date::Parse::str2time( sprintf('%.4d-%.2d-%.2d', @session{
				'/employee/production/print_overview.html?schedule_end_year',
				'/employee/production/print_overview.html?schedule_end_month',
				'/employee/production/print_overview.html?schedule_end_day',
				} ) );
	foreach ( @{$variable{'changed'}} ) {
		my $Shift = openprint::Shift::get_from_ul_id( $_ );
		my $time = $Shift->starttime_seconds();
		if ( $time > $filter_seconds ) {
			@session{
				'/employee/production/print_overview.html?schedule_end_year',
				'/employee/production/print_overview.html?schedule_end_month',
				'/employee/production/print_overview.html?schedule_end_day',
			} = Date::Calc::Time_to_Date( $time );
			$filter_seconds = $time;
		} # end if
	} # end foreach
} # end sub _drop.json

sub reorder_jobs {
	my ( @order ) = @_;

	if ( ! @order ) {
		$log->warn("No Jobs");
		return;
	} # end if

	foreach my $Job ( @order ) {
		my $Project = $Job->Project();
		$log->debug($Job->id() .' ' . $Job->Project()->docket() . ' ' . $Job->Project()->Company()->name() . ' Due: (' . $Project->due_date().')' );
		if ( ! $Project->due_date() ) {
			$log->debug("Saving project");
			if ( $_ = $Project->save({'due_date'=>$Project->get_due_date()}) ) {
			$log->error("Error Saving project") if $_;
			} # end if
			$log->debug("DOne Saving project");
		} # end if
	} # end foreach Job

	my $start_time = time;
	my $row = $order[0];
	push @{$variable{'changed'}}, $$row->Shift()->ul_id();

	# This is if there is a job currently running, then use it's start time as the beginning of the schedule
	if ( $row->locked() and ( $row->starttime_seconds() < $start_time ) ) {
$log->debug("Running job,moving up starttime");
		$start_time = $row->starttime_seconds();
	} # end if

	# Grab all shifts.  We will only add a shift at the end
	my @Shifts = openprint::Shift->find(
			'equipment_id'	=>	$$row{'equipment_id'},
			'endtime_start'	=>	Date::Format::time2str('%Y-%m-%d %H:%M%z', $start_time ),
			'order'			=>	'starttime',
			);
foreach my $S ( @Shifts ) {
$log->debug("Shifts: " . $S->to_string() );
last;
} # end foreach S
	if ( ! @Shifts ) {
		# First, grab most recent shift, this will give us the last equipment shift.
		my $NextES;

		# This is neccessary, because it happens because we have no shifts in teh array
		my $PreviousShift = openprint::Shift->find_one( 'equipment_id' => $$row{'equipment_id'}, 'order'=>'starttime DESC' );
		if ( $PreviousShift ) {
			# The logic here should be, grab the ES from the last shift, and then get the next ES.  It should not be based on time
			$NextES = openprint::Equipment_Shift->find_one( 
					'equipment_id'	=>	$$row{'equipment_id'}, 
					'starttime_>='	=>	$PreviousShift->Equipment_Shift()->endtime(),
					'order'			=>	'starttime',
					);
		} # end if
		if ( ! $NextES ) {
			$NextES = openprint::Equipment_Shift->find_one( 
					'equipment_id'		=>	$$row{'equipment_id'}, 
					'order'				=>	'starttime',
					);
		} # end if ! NextES
$log->debug("ES: " . $NextES->name() );
		if ( ! $NextES ) {
			$variable{'alert'} .= 'There are no shifts to schedule on.';
			return;
		} # end if ! NextES
		push @Shifts, $NextES->emanantise( $start_time );
	} # end if
	my $Shift = shift @Shifts;
	push @{$variable{'changed'}}, $Shift->ul_id();
	
	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE Schedule IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );

	my @fixed_jobs = ();
	for ( my $i = 0; $i < @order; $i += 1 ) {
		if ( $order[$i]{'starttime'} and $order[$i]{'locked'} ) {
			push @fixed_jobs, splice @order, $i, 1;
			$i -= 1;
		} # end if
	} # end for

	while ( @order ) {
		my $row = shift @order;
		my $run_time = $row->runtime_seconds();
		my $old_start_time = $start_time - $run_time;

		while ( @fixed_jobs and ( $fixed_jobs[0]->starttime_seconds() < ($start_time+$run_time) ) ) {
			# Have fixed_jobs.  They do not move.
			$start_time = $fixed_jobs[0]->endtime_seconds() + 1;
			shift @fixed_jobs;
		} # end while

# Time to move on to next shift
		while ( ( ! $Shift->operator_id() ) or ( $start_time > $Shift->endtime_seconds() ) ) {
			if ( ! @Shifts ) {
				my $NextES = openprint::Equipment_Shift->find_one( 
						'equipment_id'	=>	$$row{'equipment_id'}, 
						'starttime_>='	=>	$Shift->Equipment_Shift()->endtime(),
						'order'			=>	'starttime',
						);
$log->debug("ES: " . $Shift->Equipment_Shift()->name() );
$log->debug("ES: " . $NextES->name() );
				if ( ! $NextES ) {
					$NextES = openprint::Equipment_Shift->find_one( 
							'equipment_id'		=>	$$row{'equipment_id'}, 
							'order'				=>	'starttime',
							);
				} # end if ! NextES
				$Shift = $NextES->emanantise( $start_time );
				$start_time = $Shift->starttime_seconds();
				if ( ! $Shift->operator_id() ) {
					$start_time = undef;
					$variable{'alert'} .= 'Not enough shifts to fit all jobs. Please assign an operator to another shift.';
					last;
				} # end if
			} else {
				$Shift = shift @Shifts;
				$start_time = $Shift->starttime_seconds() if $start_time < $Shift->starttime_seconds();
			} # end if
			push @{$variable{'changed'}}, $Shift->ul_id();
		} # end while

		$row->operator_id( $Shift->operator_id() );
		last if $row->save({
				'starttime'	=> $start_time ? Date::Format::time2str('%Y-%m-%d %H:%M:%S%z', $start_time ) : undef,
				'equipment_id'	=>	$$Shift{'equipment_id'},
				} );
		if ( ! $start_time ) {
			last;
        } elsif ( ! $$row{starttime} ) {
            $row->Project()->add_to_log( @session{'company_id','user_id'}, "Scheduled on " . $row->Equipment()->strid() . ' at ' . Date::Format::time2str( $config{'DateTimeFormat'}, $start_time) );
        } # end if

        $start_time += $run_time;

    } # end while @order
	while ( @order ) {
		my $row = shift @order;
		last if $row->save({
				'starttime'	=> undef,
				} );
	} # end while @order
    sql::end_transaction( $dbh, $ac );
} # end sub reorder_jobs

sub _li_change {
	my $Job = new openprint::ScheduledJob($param{'schedule_id'});
	if ( ! $Job->id() ) {
		$variable{'alert'} .= 'Unable to load job.  It must have been removed from the schedule.';
		return;
	} # end if
	my $Equipment = $Job->Equipment();

	if ( $param{'action'} eq 'start' ) {

		# Stop any currently running jobs, which will be the first job on the schedule, right?
		foreach my $J ( openprint::ScheduledJob->find('equipment_id'=>$Job->equipment_id(),'order'=>'starttime','starttime_null'=>0,'limit'=>1) ) {
			if ( $J->status() eq 'In Production' ) {
				$variable{'error'} .= $J->stop();
				$variable{'alert'} .= 'Stopped previous running job docket ' . $J->Project()->docket();
				push @{$variable{'changed'}}, $J->Shift()->ul_id();
			} # end if
		} # end foreach

		push @{$variable{'changed'}}, $Job->Shift()->ul_id();
		$variable{'error'} .= $Job->start();
		if ( $Equipment->smartscheduling() ) {
			reorder_jobs(
					openprint::ScheduledJob->find( 'starttime_null'=>0, 'equipment_id'=>$$Job{'equipment_id'},'order'=>'starttime' ) );
		} else {
			push @{$variable{'changed'}}, $Job->Shift()->ul_id();
		} # end if
	} elsif ( $param{'action'} eq 'stop' ) {
		push @{$variable{'changed'}}, $Job->Shift()->ul_id();
		$variable{'error'} .= $Job->stop();
		if ( $Equipment->smartscheduling() ) {
			reorder_jobs(
					openprint::ScheduledJob->find( 'starttime_null'=>0, 'equipment_id'=>$$Job{'equipment_id'},'order'=>'starttime' ) );
		} else {
			push @{$variable{'changed'}}, $Job->Shift()->ul_id();
		} # end if
	} elsif ( $param{'action'} eq 'SaveJob' ) {

		my %sql;

		if ( (exists $param{'forms'}) and ( $param{'forms'} != $Job->forms() ) ) {
			my @service_ids = @{$$Job{'service_id'}};
			if ( $Job->forms() > $param{'forms'} ) {
				my @new_service_ids = splice @service_ids, 0, $param{'forms'};
				$sql{'service_id'} = \@new_service_ids;
				$Job->Project()->add_to_log(@session{'company_id','user_id'}, 'Removed form ' . join(',', sort map {
					my $sig_specs = openprint::service::get_specs_ref( $Job->Project(), $_ );	
					$$sig_specs{'SignatureIndex'};
					} @service_ids ) . ' from press schedule.' );
			} elsif ( $Job->forms() < $param{'forms'} ) {
				my $sig_specs = openprint::service::get_specs_ref( $Job->Project(), $service_ids[0] );
				while ( @service_ids < $param{'forms'} ) {
					$Job->Project()->add_to_log(@session{'company_id','user_id'}, "Duplicating form $$sig_specs{SignatureIndex} for press schedule");
					push @service_ids, $Job->Project()->copy_signature( $sig_specs, { 
							'txtPrice'.$Job->Project()->ordered_quantity_index()   => 0,
							}, 'Ordered' );
				} # end while	
				$sql{'service_id'} = \@service_ids;
			} # end if
		} # end if
		if ( $param{'runtime'} ne $Job->runtime() ) {
			$param{'runtime'} =~ s/[^\d:]//g;
			my ( $h, $m, $s );
			if ( $param{'runtime'} =~ /(\d+):(\d+):(\d+)/ ) {
				( $h, $m, $s ) = ( $1, $2, $3 );
			} elsif ( $param{'runtime'} =~ /(\d+):(\d+)/ ) {
				( $h, $m ) = ( $1, $2 );
			} elsif ( $param{'runtime'} =~ /(\d+)/ ) {
				( $h ) = ( $1 );
			} # end if
			if ( $h or $m or $s ) {
				$param{'runtime'} = sprintf('%.2d:%.2d:%.2d', $h, $m, $s );
			} else {
				$param{'runtime'} = undef;
			} # end if
			$sql{'runtime'} = $param{'runtime'};
		} # end if
		if ( exists $param{'starttime_year'} ) {
			my $old_starttime = $Job->starttime_seconds();
			my $new_starttime = Date::Parse::str2time( sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'starttime_year','starttime_month','starttime_day','starttime_hour','starttime_minute'} ) );
			if ( $old_starttime != $new_starttime ) {
				$sql{'starttime_seconds'} = $new_starttime;
			} # end if
		} # end if
		$sql{'locked'} = $param{'locked'} if exists $param{'locked'} and $param{'locked'} != $$Job{'locked'};
		$sql{'comment'} = $param{'comment'} if $param{'comment'} ne $Job->comment();
		$sql{'impressions'} = $param{'impressions'} if ( exists $param{'impressions'} ) and ( $Job->impressions() != $param{'impressions'} );
		$sql{'speed'} = $param{'speed'} if ( exists $param{'speed'} ) and ( $Job->speed() != $param{'speed'} );
		$sql{'stock_verified'} = $param{'stock_verified'} if exists $param{'stock_verified'} and $param{'stock_verified'} != $$Job{'stock_verified'};
		$sql{'stock'} = $param{'stock'} if exists $param{'stock'} and $param{'stock'} ne $$Job{'stock'};

		if ( keys %sql ) {
			push @{$variable{'changed'}}, $Job->Shift()->ul_id();
			$variable{'error'} .= $Job->save(\%sql);
			push @{$variable{'changed'}}, $Job->Shift()->ul_id();
		} # end if

		if ( $Equipment->smartscheduling() ) {
			reorder_jobs(
					openprint::ScheduledJob->find( 'starttime_null'=>0, 'equipment_id'=>$$Job{'equipment_id'},'order'=>'starttime' ) );
		} # end if smartscheduling
	} elsif ( $param{'btnFunction'} eq 'BumpJob' ) {
		$variable{'error'} .= $Job->bump( $param{'equipment_id'} );
	} elsif ( $param{'action'} eq 'RemoveJob' ) {
		push @{$variable{'changed'}}, $Job->Shift()->ul_id();
		$variable{'error'} .= $Job->delete();
		if ( $Equipment->smartscheduling() ) {
			reorder_jobs(
					openprint::ScheduledJob->find( 'starttime_null'=>0, 'equipment_id'=>$$Job{'equipment_id'},'order'=>'starttime' ) );
		} # end if smartscheduling
	} elsif ( $param{'action'} eq 'SetForms' ) {
		push @{$variable{'changed'}}, $Job->Shift()->ul_id();
	} elsif ( $param{'btnFunction'} eq 'CompleteJob' ) {
		# Actually this is complete Signature
		foreach my $sig_id ( @{$$Job{'service_id'}} ) {
			my $sig_specs = openprint::service::get_specs_ref( $Job->Project(), $sig_id );
			complete_signature( $log, $dbh, \%variable, $Job->project_id(), $sig_id );
		} # end foreach
		$Job->Project()->update_status();
		push @{$variable{'changed'}}, $Job->Shift()->ul_id();
		$Job->delete();
		if ( $Equipment->smartscheduling() ) {
			reorder_jobs(
					openprint::ScheduledJob->find( 'starttime_null'=>0, 'equipment_id'=>$$Job{'equipment_id'},'order'=>'starttime' ) );
		} # end if smartscheduling
		
		
	} # end if param{action}
} # end sub _li_change

sub _shift_popup {
	$variable{'Shift'} = new openprint::Shift( $param{'shift_id'} );
} # end sub _shift_popup

sub _shift_change {
	my $Shift = new openprint::Shift( $param{'shift_id'} );
	if ( $param{'action'} eq 'delete' ) {
		$variable{'error'} .= $Shift->delete();
	} else {
		my $new_starttime = Date::Parse::str2time( sprintf('%.4d-%.2d-%.2d %.2d:%.2d', @param{'starttime_year','starttime_month','starttime_day','starttime_hour','starttime_minute'} ) );
		my $new_endtime = Date::Parse::str2time( sprintf('%.4d-%.2d-%.2d %.2d:%.2d', @param{'endtime_year','endtime_month','endtime_day','endtime_hour','endtime_minute'} ) );

		if ( $new_starttime > $new_endtime ) {
			$variable{'error'} .= 'Invalid end time. The end of the shift must occur after the start of the shift.  No changes made.<br/>';
			return;
		} # end if

		# Prevent starttime changing from excluding jobs
		foreach my $J ( $Shift->Schedule() ) {
			next if ! $J->locked();
			if ( $J->starttime_seconds() > $new_starttime ) {
				$new_starttime = $J->starttime_seconds();
				$variable{'alert'} .= 'Start time has been adjusted to include docket ' . $J->Project()->docket().'.<br/>';
			} # end if
			if ( $J->starttime_seconds() > $new_endtime ) {
				$new_endtime = $J->starttime_seconds();
				$variable{'alert'} .= 'Ending time has been adjusted to include docket ' . $J->Project()->docket().'.<br/>';
			} # end if
		} # end foreach J

		# Prevent overlapping shifts
		foreach my $S ( openprint::Shift->find(
					'starttime_<='	=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S%z', $new_starttime ), 
					'endtime_>'	=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S%z', $new_starttime ),
					'equipment_id'	=>	$Shift->equipment_id(), 'order'=>'starttime DESC' ) ) {
			next if $S->id() == $Shift->id();
			$new_starttime = $S->endtime_seconds();
			$new_endtime = $new_starttime if $new_starttime > $new_endtime;
			$variable{'alert'} .= 'Start time has been adjusted to not overlap shift ' . $S->ul_id() . '<br/>';
			last;
		} # end foreach
		foreach my $S ( openprint::Shift->find(
					'starttime_>='	=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S%z', $new_starttime ), 
					'starttime_<'	=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S%z', $new_endtime ),
					'equipment_id'	=>	$Shift->equipment_id(), 'order'=>'starttime' ) ) {
			next if $S->id() == $Shift->id();
			$new_endtime = $S->starttime_seconds();
			$new_starttime = $new_endtime if $new_starttime > $new_endtime;
			$variable{'alert'} .= 'Ending time has been adjusted to not overlap shift ' . $S->to_string() . '<br/>';
			last;
		} # end foreach

		push @{$variable{'changed'}}, $Shift->ul_id();
		$variable{'error'} .= $Shift->save({
				'starttime_seconds'	=>	$new_starttime,
				'endtime_seconds'	=>	$new_endtime,
				'operator_id'		=>	$param{'operator_id'},
				'shift_id'			=>	$param{'equipmentshift_id'},
				});

	} # end if

	if ( $Shift->Equipment()->smartscheduling() ) {
		reorder_jobs(
				openprint::ScheduledJob->find( 'starttime_null'=>0, 'equipment_id'=>$$Shift{'equipment_id'},'order'=>'starttime' ) );
	} else {
		push @{$variable{'changed'}}, $Shift->ul_id();
	} # end if smartscheduling
} # end sub _shift_change

sub operator_schedule {
    if ( %param ) {
        if ( $param{'btnFunction'} eq 'Reset' ) {
            foreach my $param ( 'category', 'Equipment' ) {
                delete $session{$r->uri().'?'.$param};
            } # end if
		} elsif ( $param{'action'} eq 'save' ) {
			my $Shift = new openprint::Equipment_Shift( $param{'shift_id'} );
			$variable{'error'} .= $Shift->save(\%param);
		} elsif ( $param{'action'} eq 'delete' ) {
			my $Shift = new openprint::Equipment_Shift( $param{'shift_id'} );
			$variable{'error'} .= $Shift->delete();
        } else {
            ssi::save_params( $r->uri(), ( 'category', 'Equipment' ) );
        } # end if
    } elsif ( ( time - $session{$r->uri().'lastupdated'} ) > 24*60*60 ) {
        foreach my $param ( 'category', 'Equipment') {
            delete $session{$r->uri().'?'.$param};
        } # end if
    } # end if
    $session{$r->uri().'?lastupdated'} = time;
	if ( $param{'btnFunction'} eq 'Add Shift' ) {
		my @Equipment = map { new openprint::Equipment( $_ ) } ( ref $param{'Equipment'} eq 'ARRAY' ? @{$param{'Equipment'}} : ( $param{'Equipment'} ) );
		foreach my $Equipment ( @Equipment ) {
			next if ! $Equipment->id();

			my $time = 0;
			my @days_worth;
			my @Shifts = openprint::Equipment_Shift->find('equipment_id'=>$Equipment->id(), 'order'=>'starttime DESC');
			if ( @Shifts ) {
				foreach my $Shift ( @Shifts ) {
					$time += $Shift->duration_seconds();
					unshift @days_worth, $Shift;
					last if $time >= ( 60*60*24 );
				} # end foreach Shift
				my $LastShift = $Shifts[0];
				foreach my $Shift ( @days_worth ) {
					my $NewShift = $Shift->copy();
					$NewShift->duration( $Equipment->specification('Default Shift Duration') ) if ! $NewShift->duration();
					$NewShift->duration( '07:00:00' ) if ! $NewShift->duration();
					$NewShift->starttime_seconds( $LastShift->endtime_seconds() );
					$variable{'error'} .= $NewShift->save();
					$LastShift = $NewShift;
				} # end foreach Shift
			} else {
				my $NewShift = new openprint::Equipment_Shift();
				$NewShift->equipment_id( $Equipment->id() );
				$NewShift->duration( $Equipment->specification('Default Shift Duration') ) if ! $NewShift->duration();
				$NewShift->duration( '07:00:00' ) if ! $NewShift->duration();
				$variable{'error'} .= $NewShift->save();
			} # end if
		} # end foreach Equipment
	} # end if

} # end sub operator_schedule

sub _job_popup {
	$variable{'Job'} = new openprint::ScheduledJob( $param{'schedule_id'} );
} # end sub _job_popup

sub _signature_completion_popup {
	$variable{'Job'} = new openprint::ScheduledJob( $param{'schedule_id'} );
}

sub _operators {
} # end 

sub _operator_shift_li {
	my $Shift = new openprint::Equipment_Shift( $param{'shift_id'} );
	$Shift->save(\%param);
	$variable{'Shift'} = $Shift;
} # end sub operator_shift_li

sub _operator_shift_popup {
	my $Shift = new openprint::Equipment_Shift( $param{'shift_id'} );
	$variable{'Shift'} = $Shift;
} # end sub operator_shift_li

sub _check_for_skid {

} # end sub _check_for_skid

sub prepress_schedule {
	if ( %param ) {
		if ( $param{'btnFunction'} eq 'Reset' ) {
			foreach my $param ( 'Presses','statuses','takenover_on_start_year','takenover_on_start_month','takenover_on_start_day','takenover_on_end_year','takenover_on_end_month','takenover_on_end_day' ) {
				delete $session{'/employee/production/prepress_schedule.html?'.$param};
			} # end if
		} else {
			ssi::save_params( '/employee/production/prepress_schedule.html', ( 'Presses','scale','statuses','takenover_on_start_year','takenover_on_start_month','takenover_on_start_day','takenover_on_end_year','takenover_on_end_month','takenover_on_end_day' ) );
		} # end if
	} elsif ( ( time - $session{'/employee/production/prepress_schedule.html?lastupdated'} ) > 24*60*60 ) {
		foreach my $param ( 'Presses', 'statuses','scale','takenover_on_start_year','takenover_on_start_month','takenover_on_start_day','takenover_on_end_year','takenover_on_end_month','takenover_on_end_day' ) {
			delete $session{'/employee/production/prepress_schedule.html?'.$param};
		} # end if
	} # end if
	$session{'/employee/production/prepress_schedule.html?lastupdated'} = time;
} # end sub prepress_schedule

sub _split_popup {
	$variable{'Job'} = new openprint::ScheduledJob( $param{'schedule_id'} );
} # end sub _split_popup

sub bindery_schedule2 {
	if ( %param ) {
		if ( $param{'btnFunction'} eq 'Reset' ) {
			foreach my $param ( 'Equipment','schedule_start_year','schedule_start_month','schedule_start_day','schedule_end_year','schedule_end_month','schedule_end_day','pending','pending_approved', 'scale','equipment' ) {
				delete $session{'/employee/production/bindery_schedule2.html?'.$param};
			} # end if
		} else {
			ssi::save_params( '/employee/production/bindery_schedule2.html', ( 'Equipment','schedule_start_year','schedule_start_month','schedule_start_day','schedule_end_year','schedule_end_month','schedule_end_day', 'scale','equipment' ) );
		} # end if
	} elsif ( ( time - $session{'/employee/production/bindery_schedule2.html?lastupdated'} ) > 24*60*60 ) {
		foreach my $param ( 'Equipment','schedule_start_year','schedule_start_month','schedule_start_day','schedule_end_year','schedule_end_month','schedule_end_day','pending','pending_approved', 'scale','equipment' ) {
			delete $session{'/employee/production/bindery_schedule2.html?'.$param};
		} # end if
	} # end if
	$session{'/employee/production/bindery_schedule2.html?lastupdated'} = time;
	$variable{'referer'} = '/employee/production/bindery_schedule2.html';
} # end sub bindery_schedule2

1;
__END__
