package openprint::Shift;
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
require Date::Parse;
require openprint::Equipment_Shift;
require openprint::User;

my $debug = 0;

$table = 'shifts';
$serial = 'shifts_id_seq';

%fields = (
	'id'				=>	'id',
	'starttime'			=>	'starttime',
	'endtime'			=>	'time',
	'operator_id'		=>	'operator_id',
	'shift_id'			=>	'shift_id',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
);

%defaults = (
);

sub find {
	my %params = @_;

	my @values;
	my $sql = "SELECT * as ending FROM $table WHERE 1>0";

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
	return Date::Parse::str2time( $_[0]{'starttime'} );
} # endsub
sub startdate_seconds {
	my ( $self ) = @_;
	my $time = $self->starttime_seconds();
	return Date::Parse::str2time( Date::Format::time2str( '%Y-%m-%d', $time ) );
} # end sub startdate_seconds

sub endtime_seconds {
	return Date::Parse::str2time( $_[0]{'endtime'} );
} # endsub

sub Operator {
	return new openprint::User( $_[0]{'operator_id'} );
} # end sub Operator

sub Equipment_Shift {
	return new openprint::Equipment_Shift( $_[0]{'shift_id'} );
} # end sub Equipment_Shift

sub name {
	return $_[0]->Equipment_Shift()->name();
} # end sub name

sub schedule {
	return openprint::press_schedule::find( 'starttime_start'=>$_[0]{'starttime'}, 'starttime_end'=>$_[0]{'endtime'}, 'equipment_id'=>$_[0]{'equipment_id'} );
} # end sub schedule

sub operator_id {
	my $self = shift;

	if ( @_ ) {
		$$self{'operator_id'} = shift;
		foreach my $row ( $self->schedule() ) {
			sql::update( $log, $dbh, 'tbl_Project_Contents',  ['lngProjectIndex=? AND lngServiceIndex=?', @$row{'projectindex','serviceindex'}], 'operator_id', $$self{'operator_id'} ? $$self{'operator_id'} : undef );
		} # end foreach
		$self->save();
	} # end if
	return $$self{'operator_id'};
} # end sub operator_id

1;
#__END__
