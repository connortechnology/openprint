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
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
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
	foreach my $Job ( openprint::ScheduledJob::find('endtime'=>Date::Format::time2str('%Y-%m-%d %H:%M:%S', time ),'order'=>'starttime' ) ) {
		$Job->save({'starttime_seconds'=>time});
	} # end while
} # end sub update_late_jobs

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
	foreach my $Job ( openprint::ScheduledJob::find('service_id'=>$service_index) ) {
		$Job->delete();
	} # end foreach Job
	my $runtime = openprint::service::get_runtime( new openprint::Project( $project_index ), $service_index );

	my $Job = new openprint::ScheduledJob();
	$Job->save({
			'project_id'		=>	$project_index,
			'service_id'		=>	[ $service_index ],
			'equipment_id'		=>	$equipment_id,
			'starttime'			=>	$start_time,
			'runtime_seconds'	=>	$runtime,
			});
	sql::end_transaction( $dbh, $ac );
} # end sub insert

# Removes a form from the press schedule
sub remove {
	my ( $log, $dbh, $project_index, $service_index ) = @_;
	my $ac = sql::start_transaction( $dbh );

	my @equipment_ids = ();
	foreach my $Job ( openprint::ScheduledJob::find('project_id'=>$project_index, 'service_id'=>$service_index) ) {
		push @equipment_ids, $Job->equipment_id();
		$Job->delete();
	} # end foreach Job
	foreach my $equipment_id ( sets::union( @equipment_ids ) ) {
		new openprint::Equipment( $equipment_id )->update_schedule();
	} # end foreach
	sql::end_transaction( $dbh, $ac );
} # end sub remove

1;
__END__
