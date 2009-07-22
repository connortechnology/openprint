package openprint::Operator_Shift;
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
require openprint::User;
require openprint::Equipment_Shift;

my $debug = 1;

$table = 'operator_shifts';
$serial = 'operator_shifts_id_seq';

%fields = (
	'id'			=>	'id',
	'equipment_id'	=>	'equipment_id',
	'operator_id'	=>	'operator_id',
	'shift_id'		=>	'shift_id',
	'starttime'		=>	'starttime',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'shift_id'		=>	[ 's/\D//g' ],
	'equipment_id'	=>	[ 's/\D//g' ],
	'operator_id'	=>	[ 's/\D//g' ],
);

%defaults = (
);

sub find_one {
	my %params = @_;
	$params{'limit'}=1;
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
	if ( exists $params{'operator_id'} ) {
		if ( ref $params{'operator_id'} eq 'ARRAY' ) {
			$sql .= ' AND operator_id IN ('. join(',', map {'?'} @{$params{'operator_id'}} ) . ')';
			push @values, @{$params{'operator_id'}};
		} else {
			$sql .= ' AND operator_id=?';
			push @values, $params{'operator_id'};
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
		$log->debug("Error loading Operator_Shift SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Operator_Shift loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Operator_Shift ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::ScheduledJob( $_->{id}, $_ ) } @$data;
} # end sub find

sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

sub get_li {
    my ( $self, $ul_id ) = @_;

# a 12hour shift ~= 600px, so each hour gets 50px;

    my $html;
	$html .= sprintf( '<li id="item_%d">', $$self{'id'} );
	$html .= '<span class="Buttons">';
	$html .= ssi::writeButton( $log, $dbh, 'Remove'.$$self{'id'}, '', "if(confirm('Are you sure?')){f1.schedule_id.value=$$self{'id'};f1.btnFunction.value='RemoveJob';f1.submit();}", '', 'D' );
	$html .= '</span>';

	$html .= "<br/></li>\n";
	return $html;
} # end sub get_li

sub Shift {
	return new openprint::Equipment_Shift( $_[0]{'shift_id'} );
} # end sub Shift

sub starttime_seconds {
	return misc::hms2time( $_[0]{'starttime'} );
} # end sub starttime_seconds

sub duration_seconds {
	return $_[0]->Shift()->duration_seconds();
} # end sub duration_seconds

1;
#__END__
