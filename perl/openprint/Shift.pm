package openprint::Shift;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %session $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

require sql;
require ssi;
require misc;
require Date::Parse;
require openprint::Equipment_Shift;
require openprint::User;
require openprint::ScheduledJob;

my $debug = 1;

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

%transforms = (
	'id'			=>	[ 's/\D//g' ],
);

%defaults = (
	'operator_id'		=>	undef,
	'created_on'		=>	'NOW()',
	'updated_on'		=>	'NOW()',
);

sub find_one {
	my %params = @_;
	$params{'limit'} = 1;
	my @Results = find(%params);
	return $Results[0] if @Results;
} # end sub find_one

sub find {
	my %params = @_;

	my @values;
	my $sql = "SELECT * FROM $table WHERE 1>0";

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( exists $params{'name'} and $params{'equipment_id'} ) {
		$sql .= ' AND shift_id IN (SELECT id FROM Equipment_shifts WHERE name=? AND equipment_id=?)';
		push @values, $params{'name'},$params{'equipment_id'};
	} # end if
	if ( exists $params{'equipment_id'} ) {
		$sql .= ' AND equipment_id=?';
		push @values, $params{'equipment_id'};
	} # end if
	if ( $params{'startdate'} ) {
		$sql .= ' AND date(starttime) = ?';
		push @values, $params{'startdate'};
	} 
	if ( $params{'starttime'} ) {
		$sql .= ' AND starttime = ?';
		push @values, $params{'starttime'};
	} 
	if ( $params{'starttime_start'} and $params{'starttime_end'} ) {
		$sql .= ' AND ( starttime BETWEEN ? AND ? )';
		push @values, @params{'starttime_start','starttime_end'};
	} elsif ( $params{'starttime_start'} ) {
		$sql .= ' AND starttime >= ?';
		push @values, $params{'starttime_start'};
	} elsif ( $params{'starttime_end'} ) {
		$sql .= ' AND starttime <= ?';
		push @values, $params{'starttime_end'};
	} elsif ( exists $params{'starttime_start'} and ! $params{'starttime_start'} ) {
		$sql .= ' AND starttime IS NULL';
	} elsif ( exists $params{'starttime_end'} and ! $params{'starttime_end'} ) {
		$sql .= ' AND starttime IS NULL';
	} # end if
	
	if ( $params{'starttime_>='} ) {
		$sql .= ' AND starttime >= ?';
		push @values, $params{'starttime_>='};
	} 
	if ( $params{'starttime_<='} ) {
		$sql .= ' AND starttime <= ?';
		push @values, $params{'starttime_<='};
	} # endif

	if ( $params{'starttime_<'} ) {
		$sql .= ' AND starttime < ?';
		push @values, $params{'starttime_<'};
	} 
	if ( $params{'starttime_>'} ) {
		$sql .= ' AND starttime > ?';
		push @values, $params{'starttime_>'};
	} # end if

	if ( $params{'endtime_start'} and $params{'endtime_end'} ) {
		$sql .= ' AND ( endtime BETWEEN ? AND ? )';
		push @values, @params{'endtime_start','endtime_end'};
	} elsif ( $params{'endtime_start'} ) {
		$sql .= ' AND endtime >= ?';
		push @values, $params{'endtime_start'};
	} elsif ( $params{'endtime_end'} ) {
		$sql .= ' AND endtime <= ?';
		push @values, $params{'endtime_end'};
	} elsif ( exists $params{'endtime_start'} and ! $params{'endtime_start'} ) {
		$sql .= ' AND endtime IS NULL';
	} elsif ( exists $params{'endtime_end'} and ! $params{'endtime_end'} ) {
		$sql .= ' AND endtime IS NULL';
	} # end if

	if ( $params{'endtime_<'} ) {
		$sql .= ' AND endtime < ?';
		push @values, $params{'endtime_<'};
	} 
	if ( $params{'endtime_<='} ) {
		$sql .= ' AND endtime <= ?';
		push @values, $params{'endtime_<='};
	} 
	if ( $params{'endtime_>'} ) {
		$sql .= ' AND endtime > ?';
		push @values, $params{'endtime_>'};
	} # end if
	if ( $params{'endtime_>='} ) {
		$sql .= ' AND endtime >= ?';
		push @values, $params{'endtime_>='};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Shifts SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Shifts loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Shifts ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Shift( $_->{id}, $_ ) } @$data;
} # end sub find

sub starttime_seconds {
	if ( @_ == 2 ) {
		$_[0]{'starttime'} = Date::Format::time2str( '%Y-%m-%d %H:%M:%S', $_[1] );
	} # end if
	return Date::Parse::str2time( $_[0]{'starttime'} );
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
	return openprint::press_schedule::find( 'starttime_start'=>$_[0]{'starttime'}, 'starttime_end'=>$_[0]{'endtime'}, 'equipment_id'=>$_[0]{'equipment_id'} );
} # end sub schedule
sub Schedule {
	return openprint::ScheduledJob::find( 
			'starttime_null'	=>	$_[0]{'starttime'} ? 0 : 1,
			'starttime_>='		=>	$_[0]{'starttime'}, 
			'starttime_<'		=>	$_[0]{'endtime'}, 
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
			if ( $$self{'operator_id'} != $_[0] ) {
			$$self{'operator_id'} = shift;
			$self->save();
			} 
		} # end if
	} # end if
	return $$self{'operator_id'};
} # end sub operator_id

sub assign_operator_id {
	my ( $self ) = @_;
	my ( $s, $m, $h, $D, $M, $Y, $Z ) = Date::Parse::strptime( $$self{'starttime'} );
$log->debug( "assign_operator_id $$self{'starttime'} => $Y, $M, $D, $h, $m, $s");
	if ( Date::Calc::check_date( 1970, 1, $D ) and Date::Calc::check_time( $h, $m, $s ) ) {
		my $time = Date::Calc::Mktime( 1970, 1, $D, $h, $m, $s );
		my $Shift = openprint::Equipment_Shift::find_one(
				'equipment_id'	=>	$$self{'equipment_id'}, 
				'starttime'		=>	Date::Format::time2str( '%H:%M:%S', $time ),
				);
		if ( $Shift and $Shift->operator_id() ) {
			return $$self{'operator_id'} = $Shift->operator_id();
		} # end if
	} else {
		$log->error("Invalid Date or Time $$self{'starttime'} => $Y, $M, $D, $h, $m, $s");
	} # end if
	return;
} # end sub assign_operator_id

sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

sub to_string {
	my ( $self ) = @_;
	return sprintf('%s %s %s to %s %s', $self->Equipment()->name(), $self->name(), $$self{'starttime'}, $$self{'endtime'}, $self->Operator()->name() );
} # end sub to_string

sub get_lis {
	my ( $Shift, $filters ) = @_;
	my $self = $Shift;

	my ( $s, $min, $h, $day, $month, $year );
	if ( $Shift->starttime() ) {
		( $s, $min, $h, $day, $month, $year ) = Date::Parse::strptime( $Shift->starttime );
		$year += 1900;
		$month += 1;
	} # endif

	my $html;
	my $ul_id = $Shift->ul_id();

	my $previous_row;
	my $total_impressions;

	foreach my $Job ( $self->Schedule() ) {
		if ( $filters ) {
			if ( $$filters{'Status'} ) {
				next if ! sets::isin( $Job->Project()->status(), $$filters{'Status'} );
			} # end if
		} # end if
		
		$html .= $Job->get_li( $ul_id );
		$total_impressions += $Job->impressions();
	} # end foreach Job

	if ( $Shift->name() and Date::Calc::check_date( $year, $month, $day ) ) {
		my $Operator = $Shift->Operator();

		if ( openprint::usergroup::is_user_in( ['PressManager','Scheduling'], $session{'user_id'} ) ) {
			$html = sprintf( q{<div class="When" onclick="popup_window('_shift_popup.html','shift_id=%d');"><span class="Interval">%s %d %.3s %s %s to %s</span><span class="TotalImpressions">(%d)</span><span class="%s">%s</span></div>},

			$Shift->id(), 
Date::Calc::Day_of_Week_Abbreviation( Date::Calc::Day_of_Week($year, $month, $day)), $day, Date::Calc::Month_to_Text( $month ), $Shift->name(), 
			Date::Format::time2str('%H:%M', $Shift->starttime_seconds() ),
			Date::Format::time2str('%H:%M', $Shift->endtime_seconds() ),
			$total_impressions, ($Operator->id() ? 'Operator' : 'assign' ), 
			($Operator->id() ? $Operator->name() : 'assign') ) . $html;
		} else {
			$html = sprintf( '<div class="When"><span style="float: left;">%s %d %.3s %s %s to %s</span><span style="float: right;">%s</span><br class="spacer"/></div>', 
					Date::Calc::Day_of_Week_Abbreviation( Date::Calc::Day_of_Week($year, $month, $day)), $day, Date::Calc::Month_to_Text( $month ), $Shift->name(), 
			Date::Format::time2str('%H:%M', $Shift->starttime_seconds() ),
			Date::Format::time2str('%H:%M', $Shift->endtime_seconds() ),
			( $Operator->id() ? $Operator->name() : 'assign' ) ) . $html;
		} # end if
	} # end if
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
		$Shift = openprint::Shift::find_one( 'equipment_id'=>$equipment_id, 'name'=>$shift_name, 'startdate'=>$date );
if ( 0 ) {
		if ( ! $Shift ) {
			if ( my $ES = openprint::Equipment_Shift::find_one('equipment_id'=>$equipment_id, 'name'=>$shift_name ) ) {
				$Shift = $ES->emanantise( Date::Parse::str2time($date) );
			} # end if
		} # end if
} # end if
		return if ! $Shift;
	} else {
		$Shift = new openprint::Shift();
		$Shift->set({ 'equipment_id'  =>  $equipment_id, });
		$Shift->name( $shift_name );
	} # end if Shift
	return $Shift;
} # end if

sub get_ul {
	my ( $Shift, $filters ) = @_;

	my $content = $Shift->get_lis($filters);
	return sprintf('<ul id="%s" class="shift %s">%s</ul>%s', $Shift->ul_id(), ($content ? '' : ' Empty'), $content, "\n" );
} # end sub get_ul

sub get {
	return $_[0]->Shift();
} # end sub get

sub Previous {
	my ( $self ) = @_;
	if ( ! $$self{'Previous'} ) {
		my $Previous = find_one('starttime_<' => $self->starttime(), 'equipment_id'=>$$self{'equipment_id'}, 'order'=>'starttime DESC' );
		$log->debug( 'Previous: ' . $Previous->to_string() );
		$$self{'Previous'} = $Previous;
	} # end if
	return $$self{'Previous'};
} # end sub Previous
sub Next {
	my ( $self ) = @_;
	if ( ! $$self{'Next'} ) {
		my $Next = find_one('starttime_>=' => $self->endtime(), 'equipment_id'=>$$self{'equipment_id'}, 'order'=>'starttime' );
		$log->debug( 'Next: ' . $Next->to_string() );
		if ( ! $Next ) {
			my $ES = openprint::Equipment_Shift::find_one(
					'equipment_id'	  =>  $$self{'equipment_id'},
					'starttime_start'   =>  $self->Shift()->Equipment_Shift()->endtime(),
					'order'			 =>  'starttime',
					);
			$Next = $ES->emanantise( $self->endtime_seconds() );
		} # end if
		$$self{'Next'} = $Next;
	} # end if
	return $$self{'Next'};
} # end sub Next

sub delete {
	my ( $self ) = @_;
	if ( ( ! $self->Equipment()->smart_scheduling() ) and $self->Schedule() ) {
		return 'Cannot delete a shift with jobs in it.  Please move the jobs to another shift first.';	
	} # end if
	return $self->SUPER::delete();
} # end sub delete

1;
#__END__
