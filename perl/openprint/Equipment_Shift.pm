package openprint::Equipment_Shift;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

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

my $debug = 1;

$table = 'equipment_shifts';
$serial = 'equipment_shifts_id_seq';

%fields = (
	'id'				=>	'id',
	'starttime'			=>	'starttime',
	'duration'			=>	'duration',
	'name'				=>	'name',
	'equipment_id'		=>	'equipment_id',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
);

%defaults = (
);

sub find {
	my %params = @_;

	my @values;
	my $sql = "SELECT *,starttime+duration-'1 second'::interval as ending FROM $table WHERE 1>0";

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( exists $params{'equipment_id'} ) {
		$sql .= ' AND equipment_id=?';
		push @values, $params{'equipment_id'};
	} # end if
	if ( exists $params{'name'} ) {
		$sql .= ' AND name=?';
		push @values, $params{'name'};
	} # end if
    if ( $params{'starttime_start'} and $params{'starttime_end'} ) {
        $sql .= ' AND ( starttime BETWEEN ? AND ? )';
        push @values, @params{'starttime_start','starttime_end'};
    } elsif ( $params{'starttime_start'} ) {
        $sql .= ' AND starttime >= ?';
        push @values, $params{'starttime_start'};
    } elsif ( $params{'starttime_end'} ) {
        $sql .= ' AND starttime <= ?';
        push @values, $params{'starttime_end'};
    } elsif ( $params{'starttime_<'} ) {
        $sql .= ' AND starttime < ?';
        push @values, $params{'starttime_<'};
    } elsif ( exists $params{'starttime_start'} and ! $params{'starttime_start'} ) {
        $sql .= ' AND starttime IS NULL';
    } elsif ( exists $params{'starttime_end'} and ! $params{'starttime_end'} ) {
        $sql .= ' AND starttime IS NULL';
    } # end if

	if ( $params{'endtime_end'} ) {
        $sql .= ' AND starttime+duration <= ?';
        push @values, $params{'endtime_end'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Equipment_Shifts SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Equipment_Shifts loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Equipment_Shifts ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Equipment_Shift( $_->{id}, $_ ) } @$data;
} # end sub find

sub starttime_seconds {
	return misc::hms2time( $_[0]{'starttime'} );
} # end sub starttime_seconds

sub duration_seconds {
	return misc::hms2time( $_[0]{'duration'} );
} # end sub duration_seconds

sub emanantise {
	my ( $self, $date_seconds ) = @_;

#$log->debug("Emanentise: Date: " . Date::Format::time2str('%Y-%m-%d %H:%M:%S', $date_seconds ) );
	#$date_seconds -= ($date_seconds % (24*3600));
	$date_seconds = Date::Parse::str2time( Date::Format::time2str('%Y-%m-%d', $date_seconds ) );
#$log->debug("Emanentise: Date: " . Date::Format::time2str('%Y-%m-%d %H:%M:%S', $date_seconds ) );

	my $Shift = new openprint::Shift();
	$Shift->save({
		'starttime'		=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S', $date_seconds + $self->starttime_seconds() ),
		'endtime'		=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S', $date_seconds + $self->starttime_seconds() + $self->duration_seconds() ),
		'equipment_id'	=>	$$self{'equipment_id'},
		'shift_id'		=>	$$self{'id'},
	});
	return $Shift;
} # end sub emanantise

1;
#__END__
