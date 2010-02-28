package openprint::employee_schedule;

use Date::Calc qw(Add_Delta_Days);
use openprint ();
use vars qw( $log $dbh %variable %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*config = \%config;

require sql;
require openprint::Equipment;
require openprint::service;
require openprint::Shift;
require openprint::ScheduledJob;

use strict;

sub add_missing_jobs_to_schedule {
	if ( $config{'Smart Schedule'} ne 'Y') {
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

	my $Shift = openprint::Shift::get_from_ul_id( $id );
	$log->debug("Shift: " . $Shift->to_string() );

	my ( $start_time, $end_time, $operator_id ) = ( $Shift->starttime(), $Shift->endtime(), $Shift->operator_id() );

	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE Schedule IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
	while ( @order ) {
		my $row_id = shift @order;
		$row_id =~ s/\D//g;
		next if ! $row_id;

		my $Job = new openprint::ScheduledJob( $row_id );
		next if ! $Job->id(); # due to coalescing, a job could be deleted

		my %sql;
		$sql{'operator_id'} = $operator_id if $operator_id != $Job->operator_id();
		if ( $$Job{'starttime'} ne $start_time or $$Job{'equipment_id'} != $Shift->equipment_id() ) {
			$sql{'starttime'} = $start_time;
			$sql{'equipment_id'} = $Shift->equipment_id();
		} # end if

		if ( keys %sql ) {
			$Job->save(\%sql);
			if ( $Job->project_id() ) {
				my $Project = $Job->Project();
				$Project->save({'due_date'=>$Project->get_due_date()}) if ! $Project->due_date();
				my @forms = map { my $sig_specs = openprint::service::get_specs_ref( $Job->Project(), $_ ); return $$sig_specs{'SignatureIndex'}; } @{$Job->service_id()};
				$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Scheduled form' . ( @forms == 1 ? ' ' : 's ' ) . join(',',@forms).' to print on ' . $Shift->Equipment()->strid() . ' ' . ( $start_time ? "at $start_time" : $Shift->name() ) );
			} # end if
		} # end if

		# Starttime is empty when moving to pending
        if ( @order and $start_time ) {
			( $start_time ) = sql::execute( $log, $dbh, q{SELECT StartTime + '1 second'::interval FROM Schedule WHERE id=?}, $row_id );
        } # end if
    } # end foreach
    sql::end_transaction( $dbh, $ac );
} # end sub drop_project

sub set_duedate {
	my ( $r, $log, $dbh, $variable, $schedule_id, $date ) = @_;
	my $Job = new openprint::ScheduledJob( $schedule_id );
	if ( $$Job{'project_id'} ) {
		my $Project = $Job->Project();
		$Project->due_date( $date );
		$Project->save();
		$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Duedate changed to $date" );
	} # end if
} # end sub set_duedate

sub insert {
	my ( $log, $dbh, $project_index, $service_index, $equipment_id ) = @_;

	my $ac = sql::start_transaction( $dbh );
	my ( $start_time ) = sql::execute( $log, $dbh, q{SELECT MAX(StartTime+RunTime) FROM Schedule, tbl_Projects WHERE Index=ProjectIndex AND strStatus='Approved' AND Equipment_ID=?}, $equipment_id );
	( $start_time ) = sql::execute( $log, $dbh, 'SELECT NOW()' ) if ! $start_time;
	sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ServiceIndex=?}, $service_index );
	my $runtime = openprint::service::get_runtime( new openprint::Project( $project_index ), $service_index );

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
