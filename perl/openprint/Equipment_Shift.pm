use strict;
package openprint::Equipment_Shift;
our @ISA = qw(openprint::Object);
require openprint::Object;
require openprint::Shift;
require sql;
require misc;

use constant DAY => 60*60*24;
use constant HOUR => 60*60;

use openprint ();
use vars qw( $log $dbh $debug $table $serial %fields %find_fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;


# Note: duration_seconds is 1 seconds less than duration

$debug = 1;

$table = 'equipment_shifts';
$serial = 'equipment_shifts_id_seq';

%fields = (
	'id'			=>	'id',
	'starttime_seconds'		=>	'starttime_seconds',
	'duration_seconds'		=>	'duration_seconds',
	'duration'				=>	undef,
	'endtime_seconds'		=>	undef,
	'name'			=>	'name',
	'equipment_id'	=>	'equipment_id',
    'operator_id'   =>  'operator_id',
);

%find_fields = (
	'endtime'	=>	'starttime_seconds + duration_seconds - 1',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'operator_id'   =>  [ 's/\D//g' ],
);

%defaults = (
	'operator_id'	=>	undef,
	'starttime'		=>	'00:00:00',
	'starttime_seconds'	=>	0,
	'duration_seconds'	=>	1,
	'name'			=>	'Shift',
);

sub starttime_seconds {
	if ( @_ > 1 ) {
		if ( ref $_[1] eq 'ARRAY' ) {
			my ( $d, $h, $m, $s ) = @{$_[1]};
			$_[0]{'starttime_seconds'} = ($d * DAY) + ($h * HOUR) + $m * 60 + $s;
		} else {
			$_[0]{'starttime_seconds'} = $_[1];
		} # end if
		$_[0]{'endtime_seconds'} = $_[0]{'starttime_seconds'} + $_[0]{'duration_seconds'};
	} # end if
	return $_[0]{'starttime_seconds'};
} # end sub endtime_seconds

sub endtime {
	if ( ! $_[0]{'endtime'} ) {
		$_[0]{'endtime'} = Date::Format::time2str( '%H:%M:%S', $_[0]->endtime_seconds());
	} # end if
	return $_[0]{'endtime'};
} # end sub endtime_seconds

sub endtime_seconds {
	if ( @_ > 1 ) {
		if ( ref $_[1] eq 'ARRAY' ) {
			my ( $d, $h, $m, $s ) = @{$_[1]};
			$_[0]{'endtime_seconds'} = ($d * DAY) + ($h * HOUR) + $m * 60 + $s;
		} else {
			$_[0]{'endtime_seconds'} = $_[1];
		} # end if
		$_[0]{'duration_seconds'} = $_[0]{'endtime_seconds'} - $_[0]{'starttime_seconds'};
	} # end if
	if ( ! $_[0]{'endtime_seconds'} ) {
		$_[0]{'endtime_seconds'} = $_[0]{'starttime_seconds'} + $_[0]{'duration_seconds'};
	} # end if
	return $_[0]{'endtime_seconds'};
} # end sub endtime_seconds

#Pass back a shift for the next time slot >= the passed in $date_seconds
# We presume that normally date_seconds is teh starttie + 1 of the previous shift
sub emanantise {
	my ( $self, $date_seconds ) = @_;
	$log->debug("Emanantise: " . $self->to_string() );
	my $parser = 'DateTime::Format::Pg';
	my $TZ = DateTime::TimeZone->new( name => $openprint::config{'Timezone'} );

	my $requested_dt = DateTime->from_epoch( 'epoch'=>$date_seconds, 'time_zone'=>$TZ );
	$log->debug("Emanentise: Date: $date_seconds : " . $parser->format_datetime( $requested_dt ) );
	# The point is to drop any additional time part, but how can that be right? What we want to do is jump gaps

	my $shift_start_time_dt = DateTime::Duration->new( 'seconds' => $self->starttime_seconds() % DAY );

	my $date_part_dt = $requested_dt->clone()->truncate('to'=>'day');

	my $st = $date_part_dt + $shift_start_time_dt;
	$log->debug("initial st: " . $parser->format_datetime( $st ) . ' requested: ' . $parser->format_datetime( $requested_dt ) );
	if ( $st < $requested_dt ) {
		# Need to add a day
		$st += DateTime::Duration->new( 'days'=>1 );
	} # end if
	$log->debug("final st: " . $parser->format_datetime( $st ) . ' requested: ' . $parser->format_datetime( $requested_dt ) );
	my $et = $st + DateTime::Duration->new( 'seconds' => $self->duration_seconds() );

	my $Shift;
	# FIXME: This does not handle cases where the times have been overriden.
	# It should be looking for a shift that starts great than date_seconds, which we assume is the previous shift starttime+1
	# With an endtime before the end of the ES AFTER this one!
	# THe current iteration handles all that, except that the end is shorted than normal.
	if ( $Shift = openprint::Shift::find_one(
				'equipment_id'	=>	$$self{'equipment_id'},
				'shift_id'		=>	$$self{'id'},
				'starttime >='	=>	$parser->format_datetime( $st ),
				'endtime <='	=>	$parser->format_datetime( $et ),
				) ) {
	} else {
		$Shift = new openprint::Shift();
		$Shift->save({
				'equipment_id'	=>	$$self{'equipment_id'},
				'operator_id'	=>	( $$self{'operator_id'} ? $$self{'operator_id'} : undef ),
				'shift_id'		=>	$$self{'id'},
				'starttime'		=>	$parser->format_datetime( $st ),
				'endtime'		=>	$parser->format_datetime( $et ),
				});
	} # end if
	return $Shift;
} # end sub emanantise


sub Equipment {
    return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

sub Operator {
	return new openprint::User( $_[0]{'operator_id'} );
} # end sub Operator

sub First {
	my ( $self ) = @_;
	return openprint::Equipment_Shift->find_one( 
			'equipment_id'	=>	$$self{'equipment_id'},
			'order'			=>	'starttime',
			);
} # end sub First

sub Previous {
	if ( @_ > 1 ) {
		$_[0]{'Previous'} = $_[1];
	} # end if
	if ( ! $_[0]{'Previous'} ) {
	$_[0]{'Previous'} = openprint::Equipment_Shift->find_one( 
			'equipment_id'	=>	$_[0]{'equipment_id'},
			'starttime_seconds <'	=>	$_[0]{'starttime_seconds'},
			'order'			=>	'starttime_seconds DESC',
			);
	} # end if
	if ( ! $_[0]{'Previous'} ) {
	$_[0]{'Previous'} = openprint::Equipment_Shift->find_one( 
			'equipment_id'	=>	$_[0]{'equipment_id'},
			'order'			=>	'starttime_seconds DESC',
			);
	} # end if
	return $_[0]{'Previous'};
} # end sub Previous

sub Next {
	if ( @_ > 1 ) {
		$_[0]{'Next'} = $_[1];
	} # end if
	if ( ! $_[0]{'Next'} ) {
	$_[0]{'Next'} = openprint::Equipment_Shift->find_one( 
			'equipment_id'	=>	$_[0]{'equipment_id'},
			'starttime_seconds >'	=>	$_[0]{'starttime_seconds'},
			'order'			=>	'starttime_seconds',
			);
	} # end if
	if ( ! $_[0]{'Next'} ) {
	$_[0]{'Next'} = openprint::Equipment_Shift->find_one( 
			'equipment_id'	=>	$_[0]{'equipment_id'},
			'order'			=>	'starttime_seconds',
			);
	} # end if
	return $_[0]{'Next'};
} # end sub Next

sub delete {
	foreach my $Shift ( openprint::Shift::find('shift_id'=>$_[0]{'id'}) ) {
#$log->debug("Delete shift " . $Shift->to_string() );
		if ( $$Shift{'shift_id'} == $_[0]{'id'} ) {
			$Shift->delete() 
		} else {
			$openprint::log->error("Equipment_Shift::delete deleting a shift that isn't ours!");
		} # end if
	} # end foreach
	my $error = $_[0]->SUPER::delete();
} # end sub delete

sub starttime_string {
	return 'Day ' . int( $_[0]{'starttime_seconds'} / DAY ) . ' ' .  misc::seconds2hms( $_[0]->starttime_seconds() % DAY );
} # end sub starttime_string
sub endtime_string {
	return 'Day ' . int( $_[0]->endtime_seconds() / DAY ) . ' ' .  misc::seconds2hms( $_[0]->endtime_seconds() % DAY );
} # end sub starttime_string

sub start_day {
	return int($_[0]{'starttime_seconds'} / DAY);
}
sub end_day {
	return int( $_[0]->endtime_seconds() / DAY );
} # end sub end_day

sub start_hour {
	my $time = $_[0]{'starttime_seconds'} % DAY;
	return int($time/HOUR);
} # end sub start_hour
sub end_hour {
	my $time = $_[0]->endtime_seconds() % DAY;
	return int($time/HOUR);
} # end sub end_hour

sub start_minute {
	return int( ( $_[0]{'starttime_seconds'} % HOUR ) /60);
} # end sub start_minute
sub end_minute {
	return int( ( $_[0]->endtime_seconds() % HOUR )/60);
} # end sub end_hour

sub duration {
	if ( @_ > 1 ) {
		my ( $h, $m, $s ) = split ( ':', $_[1] );
		$_[0]{'duration_seconds'} = ( $h * HOUR ) + ( $m * 60 ) + $s - 1;
		$_[0]{'endtime_seconds'} = $_[0]{'starttime_seconds'} + $_[0]{'duration_seconds'};
	} # end if
	return misc::seconds2hms( $_[0]{'duration_seconds'} );
} # end sub duration
sub duration_seconds {
	if ( @_ > 1 ) {
		$_[0]{'duration_seconds'} = $_[1];
		$_[0]{'endtime_seconds'} = $_[0]{'starttime_seconds'} + $_[0]{'duration_seconds'};
	} # end if
	return $_[0]{'duration_seconds'};
} # end sub duration_seconds

# Calculates the distance between an ES and it's next, or the given in seconds, taking into account wrap around
sub distance {
	my ( $self, $Next ) = @_;
	$Next = $self->Next() if ! $Next;
	if ( $$Next{'starttime_seconds'} >= $$self{'starttime_seconds'} ) {
		return $$Next{'starttime_seconds'} - $$self{'starttime_seconds'};
	} else {
		# Wrap around
		my $endtime = $self->endtime_seconds() % DAY;
		#if ( $endtime <= $$Next{'starttime_seconds'} ) {
			# No overlap
			return $$self{'duration_seconds'} + $$Next{'starttime_seconds'} - $endtime;
		#} else {
	} # end if
} # end sub


1;
__END__
