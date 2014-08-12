use strict;
package openprint::Shift;
our @ISA = qw(openprint::Object);
require openprint::Object;

use openprint ();
use vars qw(%variable $log $dbh %config %session $debug $table $serial %fields %find_fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

require Date::Parse;
require openprint::Equipment_Shift;
require openprint::User;
require openprint::ScheduledJob;

$debug = 0;

$table = 'shifts';
$serial = 'shifts_id_seq';

%fields = (
	'id'				=>	'id',
	'starttime'			=>	'starttime',
	'endtime'			=>	'endtime',
	'operator_id'		=>	'operator_id',
	'shift_id'			=>	'shift_id',
	'equipment_id'		=>	'equipment_id',
	'starttime_seconds'	=>	undef,
	'endtime_seconds'	=>	undef,
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
);
%find_fields = (
	'name'		=>	'(SELECT name FROM equipment_shifts WHERE shift_id=equipment_shifts.id)',
	'startdate'	=>	'date(starttime)',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'operator_id'	=>	[ 's/\D//g' ],
);

%defaults = (
	'operator_id'		=>	undef,
	'created_on'		=>	q`'NOW()'`,
	'updated_on'		=>	q`'NOW()'`,
);

sub starttime_seconds {
	my $parser = 'DateTime::Format::Pg';
	if ( @_ == 2 ) {
		$_[0]{'starttime'} = $parser->format_datetime( DateTime->from_epoch( 'epoch'=>$_[1], 'time_zone'=>$_[0]->TZ() ) );
	} # end if
	return $parser->parse_datetime( $_[0]{'starttime'} )->epoch();
} # endsub

sub startdate_seconds {
	my ( $self ) = @_;
	my $time = $self->starttime_seconds();
	return Date::Parse::str2time( Date::Format::time2str( '%Y-%m-%d', $time ) );
} # end sub startdate_seconds

sub endtime_seconds {
	if ( @_ == 2 ) {
		$_[0]{'endtime'} = Date::Format::time2str( '%Y-%m-%d %H:%M:%S', $_[1] );
	} # end if
	return Date::Parse::str2time( $_[0]{'endtime'} );
} # endsub

sub Operator {
	return new openprint::User( $_[0]{'operator_id'} );
} # end sub Operator

sub Equipment_Shift {
	return new openprint::Equipment_Shift( $_[0]{'shift_id'} );
} # end sub Equipment_Shift

# We have this here so that changing the shift_id will cause reloading of the shift name
sub shift_id {
	if ( @_ > 1 ) {
		$_[0]{'shift_id'} = $_[1];
		delete $_[0]{'name'};
	} # end if
	return $_[0]{'shift_id'};
} # end sub shift_id

sub name {
	my ( $self, $new_name ) = @_;
	if ( defined $new_name ) {
		$$self{'name'} = $new_name;
	} elsif ( ! $$self{'name'} ) {
		$$self{'name'} = $self->Equipment_Shift()->name();
	} # end if
	return $$self{'name'};
} # end sub name

sub schedule {
	return openprint::press_schedule->find( 'starttime >='=>$_[0]{'starttime'}, 'starttime <='=>$_[0]{'endtime'}, 'equipment_id'=>$_[0]{'equipment_id'} );
} # end sub schedule

sub Schedule {
	return openprint::ScheduledJob->find( 
		( $_[0]{'starttime'} ? 
			( 
			'starttime >='		=>	$_[0]{'starttime'}, 
			'starttime <'		=>	$_[0]{'endtime'}, 
			) : (
			'starttime is null'	=>	$_[0]{'starttime'} ? 0 : 1,
			) ),
			'equipment_id'		=>	$_[0]{'equipment_id'},
			'order'				=>	'starttime,projectindex,service_id',
			);
} # end sub Schedule

sub operator_id {
	my $self = shift;

	if ( @_ ) {
		if ( $$self{'id'} ) {
			foreach my $Job ( $self->Schedule() ) {
				$Job->save({'operator_id'=>$_[0]});	
			} # end foreach
$openprint::log->debug("Setting operator from $$self{'operator_id'} to $_[0]");
			if ( $$self{'operator_id'} != $_[0] ) {
$openprint::log->debug("Setting operator to $_[0]");
				$$self{'operator_id'} = $_[0];
				$self->save();
			} # end if
		} # end if
	} # end if
	return $$self{'operator_id'};
} # end sub operator_id

sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

sub to_string {
	my ( $self ) = @_;
	if ( ! exists $$self{'to_string'} ) {
		$$self{'to_string'} = sprintf('%s %s %s to %s %s', $self->Equipment()->name(), $self->name(), 
			Date::Format::time2str( $config{'DateTimeFormat'}, Date::Parse::str2time( $$self{'starttime'} ) ),
			Date::Format::time2str( $config{'DateTimeFormat'}, Date::Parse::str2time( $$self{'endtime'} ) ), $self->Operator()->name() );
	} # end if
	return $$self{'to_string'};
} # end sub to_string

sub get_lis {
	my ( $Shift, $filters ) = @_;

	my @Jobs = $Shift->Schedule();
	if ( ( ! @Jobs ) and ! $Shift->starttime() ) {
		return 'empty';
	} # end if
	my $html;
	my $ul_id = $Shift->ul_id();

	foreach my $Job ( @Jobs ) {
		if ( $filters ) {
			if ( $$filters{'Status'} ) {
				next if ! sets::isin( $Job->Project()->status(), $$filters{'Status'} );
			} # end if
		} # end if
		
		$html .= $Job->get_li( $ul_id );
	} # end foreach Job

	return $html;
} # end sub get_lis

sub ul_id {
	my ( $self ) = @_;
	if ( $self->starttime() ) {
		return sprintf('ul%d-%s-%s', $$self{'equipment_id'}, Date::Format::time2str('%Y-%m-%d', $self->starttime_seconds() ), $self->name() );
	} else {
		return sprintf('ul%d-%s', $$self{'equipment_id'}, $self->name() );
	} # end if
} # end sub ul_id

sub get_from_ul_id {
	my ( $id ) = @_;

	$id =~ /^ul(\d*)-(\d\d\d\d-\d\d-\d\d)?-?(\w*)$/;
	my ( $equipment_id, $date, $shift_name ) = ( $1, $2, $3 );

	my $Shift;
	if ( $shift_name and $date ) {
		$Shift = openprint::Shift->find_one( 'equipment_id'=>$equipment_id, 'name'=>$shift_name, 'startdate'=>$date );
		return if ! $Shift;
	} else {
		$Shift = new openprint::Shift();
		$Shift->set({ 'equipment_id'	=>	$equipment_id, });
		$Shift->name( $shift_name );
	} # end if Shift
	return $Shift;
} # end if

sub get_ul {
	my ( $Shift, $filters ) = @_;

	my $html = '<div id="'.$Shift->ul_id().'_div">';
	my $total_impressions;

	my @Jobs = $Shift->Schedule();
	openprint::Project->find(id=>[ map { $$_{project_id} } @Jobs ]) if @Jobs;
	foreach my $Job ( @Jobs ) {
		if ( $filters ) {
			if ( $$filters{Status} ) {
				next if ! sets::isin( $Job->Project()->status(), $$filters{'Status'} );
			} # end if
		} # end if
		$total_impressions += $Job->impressions();
	} # end foreach Job

	if ( $Shift->name() ) {
		my ( $s, $min, $h, $day, $month, $year );
		if ( $Shift->starttime() ) {
			( $s, $min, $h, $day, $month, $year ) = Date::Parse::strptime( $Shift->starttime );
			$year += 1900;
			$month += 1;
		} # endif
		if ( Date::Calc::check_date( $year, $month, $day ) ) {
			my $Operator = $Shift->Operator();

			if ( openprint::usergroup::is_user_in( ['PressManager','Scheduling'], $session{'user_id'} ) ) {
				$html .= sprintf( q`<div class="When" onclick="popup_window('_shift_popup.html','shift_id=%d', {width:475});"><span class="Interval">%s %d %.3s %s %s to %s</span><span class="TotalImpressions">(%d)</span><span class="%s">%s</span></div>`, 
						$Shift->id(), 
						Date::Calc::Day_of_Week_Abbreviation( Date::Calc::Day_of_Week($year, $month, $day)), $day, Date::Calc::Month_to_Text( $month ), $Shift->name(), 
						Date::Format::time2str('%H:%M', $Shift->starttime_seconds() ),
						Date::Format::time2str('%H:%M', $Shift->endtime_seconds() ),
						$total_impressions, ($Operator->id() ? 'Operator' : 'assign' ), 
						($Operator->id() ? $Operator->name() : 'assign') );
			} else {
				$html .= sprintf( '<div class="When"><span class="Shift_time">%s %d %.3s %s %s to %s</span><span class="operator">%s</span></div>', 
						Date::Calc::Day_of_Week_Abbreviation( Date::Calc::Day_of_Week($year, $month, $day)), $day, Date::Calc::Month_to_Text( $month ), $Shift->name(), 
						Date::Format::time2str('%H:%M', $Shift->starttime_seconds() ),
						Date::Format::time2str('%H:%M', $Shift->endtime_seconds() ),
						( $Operator->id() ? $Operator->name() : 'assign' ) );
			} # end if
		} # end if valid date
	} # end if Shift->name
	my $content = $Shift->get_lis($filters);
	$html .= sprintf('<ul id="%s" class="shift%s">', $Shift->ul_id(), ($content ? '' : ' Empty') );
	$html .= $content;
	$html .= '</ul></div>';
	return $html;
} # end sub get_ul

sub get {
	return $_[0]->Shift();
} # end sub get

sub Previous {
	my ( $self ) = @_;
	if ( ! $$self{'Previous'} ) {
		my $Previous = openprint::Shift->find_one('starttime <' => $self->starttime(), 'equipment_id'=>$$self{'equipment_id'}, 'order'=>'starttime DESC' );
		$log->debug( 'Previous: ' . $Previous->to_string() );
		$$self{'Previous'} = $Previous;
	} # end if
	return $$self{'Previous'};
} # end sub Previous
sub Next {
	my ( $self ) = @_;
	if ( ! $$self{'Next'} ) {
		my $Next = openprint::Shift->find_one('starttime >=' => $self->endtime(), 'equipment_id'=>$$self{'equipment_id'}, 'order'=>'starttime' );
		$log->debug( 'Next: ' . $Next->to_string() );
		if ( ! $Next ) {
			my $ES = openprint::Equipment_Shift->find_one(
					'equipment_id'		=>	$$self{'equipment_id'},
					'starttime_seconds >='	=>	$self->Shift()->Equipment_Shift()->endtime_seconds(),
					'order'			 =>	'starttime_seconds',
					);
			$Next = $ES->emanantise( $self->endtime_seconds() );
		} # end if
		$$self{'Next'} = $Next;
	} # end if
	return $$self{'Next'};
} # end sub Next

sub delete {
	my ( $self ) = @_;
	if ( ( ! $self->Equipment()->smartscheduling() ) and $self->Schedule() ) {
		return 'Cannot delete a shift with jobs in it.	Please move the jobs to another shift first.';	
	} # end if
	return $self->SUPER::delete();
} # end sub delete

sub TZ {
	if ( ! $_[0]{'TZ'} ) {
		$_[0]{'TZ'} = DateTime::TimeZone->new( name => $openprint::config{'Timezone'} );
	} # end if
	return $_[0]{'TZ'};
} # end sub TZ

sub get_Shifts {
	my ( $Equipment, $start_dt, $end_dt, @Equipment_Shifts ) = @_;

	@Equipment_Shifts = $Equipment->Equipment_Shifts() if ! @Equipment_Shifts;
	return () if ! @Equipment_Shifts;
	my @Shifts;
	my $parser = 'DateTime::Format::Pg';
	# Three cases, no shifts, shifts before, shifts after.

	# Case #1 Shift before
	if ( my $LastShift = openprint::Shift->find_one(
			equipment_id	=>	$Equipment->id(),
			'starttime <'	=>	$parser->format_datetime( $start_dt ),
			order			=>	'starttime DESC',
			) ) {
		my $last_time = $LastShift->starttime_seconds()+1;
		while ( $last_time < $end_dt->epoch() ) {
			my $Shift = $Equipment_Shifts[0]->emanantise( $last_time );
			$last_time = $Shift->starttime_seconds() + 1;
			push @Shifts, $Shift if $Shift->starttime_seconds() > $start_dt->epoch();
		} # end while
	} elsif ( my $NextShift = openprint::Shift->find_one(
			equipment_id	=>	$Equipment->id(),
			'starttime >'	=> $parser->format_datetime( $start_dt ),
			order			=>	'starttime',
			) ) {
		my $next_time = $NextShift->starttime_seconds();
		while ( $NextShift->starttime_seconds() > $start_dt->epoch() ) {
			$NextShift = $NextShift->Equipment_Shift()->Previous()->emanantise( $NextShift->starttime() - $NextShift->Equipment_Shift()->Previous()->duration_seconds() );
			unshift @Shifts, $NextShift if $NextShift->starttime_seconds() < $end_dt->epoch();
		} # end while
	} else {
	# Just add them all in the specified range
		my $ES = $Equipment_Shifts[0];
		while ( $start_dt < $end_dt ) {
			my $Shift = $ES->emanantise( $start_dt->epoch() );
			if ( ! $Shift ) {
				$log->error("failed to emanantise");
			} elsif ( ref $Shift ne 'openprint::Shift' ) {
				$log->error("emanantise returned crap $Shift");
			} # end if

			if ( $start_dt->epoch() > $Shift->starttime_seconds() ) {
				$log->error("Created shift before requeted time!");
				last;
			} else {
				push @Shifts, $Shift;
				$log->debug("Starttime : " . $parser->format_datetime($start_dt). ' ' . $parser->format_datetime( DateTime->from_epoch( 'epoch'=>$Shift->starttime_seconds(), 'time_zone'=>$start_dt->time_zone() ) ));
			} # end fi
			$start_dt = DateTime->from_epoch( 'epoch'=>$Shift->starttime_seconds() + 1, 'time_zone'=>$start_dt->time_zone() );
			$ES = $ES->Next();
		} # end while
	} # end if
	return @Shifts;
} # end sbu get_Shifts

1;
__END__
