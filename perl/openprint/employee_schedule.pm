package openprint::employee_schedule;

use Date::Calc qw(Add_Delta_Days);


require sql;
require openprint::Equipment;
require openprint::service;
require openprint::press_schedule;

use strict;

sub add_missing_jobs_to_schedule {
	my ( $log, $dbh, $variable ) = @_;
	if ( $openprint::config{'Smart Schedule'} ne 'Y') {
		$log->debug("Not add lost jobs due to Smart Scheduling being turned off.");
		return;
	} # end if
	my @missing_jobs = sql::execute( $log, $dbh, q{SELECT Index FROM tbl_Projects WHERE strStatus='Approved' AND Index NOT IN (SELECT ProjectIndex FROM Schedule)} );
	foreach my $project_id ( @missing_jobs ) {
		my $Project = new openprint::Project( $project_id );
		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $project_id, $signature_service_index );
			if ( ! $$sig_specs{'UsePress'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $project_id, $signature_service_index, 'UsePress', $$sig_specs{'ddmPress'.$Project->ordered_quantity_index()} );
			} # end if
			if ( my @equipment = openprint::Equipment::find('strid'=>$$sig_specs{'UsePress'} ) ) {
				openprint::employee_schedule::insert( $log, $dbh, $project_id, $signature_service_index, $equipment[0]->id() );
			} # end if
		} # end foreach signature
	} # end foreach
} # end sub add_missing_jobs_to_schedule

sub update_late_jobs {
	# Make sure that we don't lose any jobs to the past.
	my @late_jobs = sql::execute( undef, undef, q{SELECT ProjectIndex, ServiceIndex FROM Schedule WHERE date(starttime+runtime) < date(NOW()) ORDER BY Starttime } );
	while ( my ( $project_index, $service_index ) = splice @late_jobs, 0, 2 ) {
		sql::update( undef, undef, 'Schedule', ['ProjectIndex=? AND ServiceIndex=?', $project_index, $service_index], 'starttime', 'date(NOW())' );
	} # end while
} # end sub update_late_jobs

sub drop_project {
	my ( $r, $log, $dbh, $variable, $id, $services ) = @_;
	$services =~ s/$id\[\]=//g;
	my @order = split( '&', $services );

	return if ! @order;

	$id =~ /^(\d*)-(\d\d\d\d)-(\d\d)-(\d\d)-(\w*)$/;
	my ( $equipment_id, $year, $month, $day, $shift ) = ( $1, $2, $3, $4, $5 );
	my ( $start_time, $end_time, $operator_id );

	if ( $shift ) {
		if ( ( $start_time, $end_time ) = sql::execute( $log, $dbh, q{SELECT starttime, starttime+duration-'1 second'::interval FROM Shifts WHERE equipment_id=? AND name=?}, $equipment_id, $shift ) ) {
			$start_time = sprintf('%.4d-%.2d-%.2d %s', $year, $month, $day, $start_time );
			$end_time = sprintf('%.4d-%.2d-%.2d %s', $year, $month, $day, $end_time );

			( $operator_id ) = sql::execute( $log, $dbh, q{SELECT operator_id FROM tbl_Project_Contents, Schedule WHERE Schedule.ProjectIndex=tbl_Project_Contents.lngProjectIndex AND Schedule.ServiceIndex=tbl_Project_Contents.lngServiceIndex AND equipment_id=? AND ( Schedule.starttime BETWEEN ? AND ? )}, $equipment_id, $start_time, $end_time );
		} else {
# Must be Approved or Pending
		} # end if
	} # end if

	my $Equipment = new openprint::Equipment( $equipment_id );

	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE Schedule' ) or $log->error( DBI->errstr );
	while ( @order ) {
		my $id = shift @order;
		$id =~ s/\D//g;
		next if ! $id;

		my @rows = openprint::press_schedule::find('id'=>$id);
		next if ! @rows;
		my $row = shift @rows;
		if ( $start_time and ! $$row{starttime} ) {
			new openprint::Project( $$row{projectindex} )->add_to_log( @openprint::session{'company_id','user_id'}, "Scheduled to print on " . $Equipment->strid() . " at $start_time" );
		} # end if

		sql::update( $log, $dbh, 'Schedule', ['id=?', $id], 'StartTime', $start_time, 'equipment_id', $equipment_id );
		if ( $$row{operator_id} != $operator_id ) {
			sql::update( $log, $dbh, 'tbl_Project_Contents',  ['lngprojectindex=? and lngserviceindex=?', @$row{'projectindex','serviceindex'}], 'operator_id', $operator_id );
		} # end if

		if ( @order ) {
			if ( $openprint::config{'Smart Schedule'} eq 'Y' or ($equipment_id == 28)) {
				( $start_time ) = sql::execute( $log, $dbh, q{SELECT StartTime+RunTime FROM Schedule WHERE id=?}, $id );
			} else {
				( $start_time ) = sql::execute( $log, $dbh, q{SELECT StartTime + '1 second'::interval FROM Schedule WHERE id=?}, $id );
			} # end if
		} # end if
	} # end foreach
	sql::end_transaction( $dbh, $ac );
} # end sub drop_project

sub set_operator {
	my ( $r, $log, $dbh, $variable, $period, $operator ) = @_;
	$period =~ /(\d*)-(\d\d\d\d)-(\d\d)-(\d\d)-(\w\w)/;
	my ( $press_index, $year, $month, $day, $shift ) = ( $1, $2, $3, $4, $5 );
	my $ac = sql::start_transaction( $dbh );
	my ( $st, $dt ) = sql::execute( $log, $dbh, q{SELECT starttime,duration-'1 second'::interval FROM Shifts WHERE equipment_id=? AND name=?}, $press_index, $shift );
	my ( $sh, $sm, $ss ) = split(':', $st );
	my $start_time = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', $year, $month, $day, $sh, $sm, $ss );
	my ( $dh, $dm, $ds ) = split( ':', $dt );
	my $end_time = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', Date::Calc::Add_Delta_DHMS( $year, $month, $day, $sh, $sm, $ss, 0, $dh, $dm, $ds ) );
	my @schedule = openprint::press_schedule::find( 'starttime_start'=>$start_time, 'starttime_end'=>$end_time, 'equipment_id'=>$press_index );
	foreach my $row ( @schedule ) {
		sql::update( $log, $dbh, 'tbl_Project_Contents',  ['lngProjectIndex=? AND lngServiceIndex=?', @$row{'projectindex','serviceindex'}], 'operator_id', $operator ? $operator : undef );
	} # end foreach

	sql::end_transaction( $dbh, $ac );
} # end sub set_operator

sub set_impressions {
	my ( $r, $log, $dbh, $variable, $project_index, $service_index, $impressions ) = @_;
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'ImpressionQuantity', $impressions );
} # end sub set_impressions
sub set_forms {
	my ( $r, $log, $dbh, $variable, $project_index, $service_index, $forms ) = @_;
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'SignatureQuantity', $forms );
} # end sub set_impressions
sub set_comment {
	my ( $r, $log, $dbh, $variable, $project_index, $service_index, $comment ) = @_;
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'txtEmployeeComments', $comment );
} # end sub set_comment
sub set_duedate {
	my ( $r, $log, $dbh, $variable, $service_index, $date ) = @_;
	my ( $project_index ) = sql::execute( $log, $dbh, q{SELECT ProjectIndex FROM Schedule WHERE ServiceIndex=?}, $service_index );
	if ( ! $project_index ) {
		( $project_index ) = sql::execute( $log, $dbh, q{SELECT lngProjectIndex FROM tbl_Project_Contents WHERE lngServiceIndex=?}, $service_index );
	} # end if
	if ( $project_index ) {
		my $Project = new openprint::Project( $project_index );
		$Project->due_date( $date );
		$Project->save();
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Duedate changed to $date" );
	} else {
		$log->error("Unable to find Project for service index $service_index on Schedule");
	}  # end if
} # end sub set_duedate

sub insert {
	my ( $log, $dbh, $project_index, $service_index, $equipment_id ) = @_;

	my $ac = sql::start_transaction( $dbh );
	my ( $start_time ) = sql::execute( $log, $dbh, q{SELECT MAX(StartTime+RunTime) FROM Schedule, tbl_Projects WHERE Index=ProjectIndex AND strStatus='Approved' AND Equipment_ID=?}, $equipment_id );
	( $start_time ) = sql::execute( $log, $dbh, 'SELECT NOW()' ) if ! $start_time;
	sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ServiceIndex=?}, $service_index );
	my $runtime = openprint::service::get_runtime( $log, $dbh, $project_index, $service_index );

	sql::insert( $log, $dbh, 'Schedule', 'ProjectIndex', $project_index, 'ServiceIndex', $service_index, 'Equipment_id', $equipment_id,'StartTime', $start_time, 'RunTime', "$runtime minutes" );
	sql::end_transaction( $dbh, $ac );
} # end sub insert

# Removes a form from the press schedule
sub remove {
	my ( $log, $dbh, $project_index, $service_index ) = @_;
	my $ac = sql::start_transaction( $dbh );
	my @data = sql::execute( $log, $dbh, q{SELECT DISTINCT Equipment_ID FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, $project_index, $service_index);
	foreach my $equipment_id ( @data ) {
		sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=? AND Equipment_ID=?}, $project_index, $service_index, $equipment_id );
		new openprint::Equipment( $equipment_id )->update_schedule();
	} # end foreach
	sql::end_transaction( $dbh, $ac );
} # end sub remove


1;

__END__
