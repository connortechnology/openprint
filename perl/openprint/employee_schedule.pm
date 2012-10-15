package openprint::employee_schedule;
use strict;

use Date::Calc qw(Add_Delta_Days);
use openprint ();
use vars qw( $log $dbh %variable %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*config = \%openprint::config;

require sql;
require openprint::Equipment;
require openprint::service;
require openprint::ScheduledJob;

sub update_late_jobs {
	# Make sure that we don't lose any jobs to the past.
	foreach my $Job ( openprint::ScheduledJob::find('endtime'=>Date::Format::time2str('%Y-%m-%d %H:%M:%S', time ),'order'=>'starttime' ) ) {
		$Job->save({'starttime_seconds'=>time});
	} # end while
} # end sub update_late_jobs

sub set_duedate {
	my ( $r, $log, $dbh, $variable, $schedule_id, $date ) = @_;
	my $Job = new openprint::ScheduledJob( $schedule_id );
	if ( ! $$Job{id} ) {
		$log->error("Job $schedule_id not found in set_duedate");
		return;
	} # end if	
	if ( $$Job{'project_id'} ) {
		my $Project = $Job->Project();
		if ( ! $$Project{id} ) {
			$log->error("Project $$Project{id} not found in set_duedate");
			return;
		} # end if

		if ( $Project->due_date() ne $date ) {
			$Project->due_date( $date );
			$Project->save();
			$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Duedate changed to $date" );

			my $Me = new openprint::User($openprint::session{user_id});
			my $CSR = $Project->Company()->CSR();
			if ( $CSR->id() ) {
				my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
				my $body = ssi::variable_substitution( $r, $log, $dbh, \$email_template,
						{ ReplacementText => $Me->name() . qq` has changed the due date for Docket <a href="$config{InternalSiteURL}/employee/project/view.html?docket=$$Project{docket}">$$Project{docket}</a>.`}
						);
				my $Mail = new openprint::Email();

				$_ = $Mail->send(
						FROM		=>	$Me,
						TO      => $CSR,
						#TO			=>  'iconnor@penultima.org',
						SUBJECT		=>	'Due Date for Docket '. $Project->docket() . ' has been changed.',
						ATTACHMENTS =>  [ '', MIME::QuotedPrint::encode_qp(Encode::encode('utf-8',$body)), 'text/html', 'quoted-printable' ],
						);
			} # end if email to CSR


		} # end if date has changed
	} # end if project_id
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
			'pertains_id'		=>	[ $service_index ],
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
