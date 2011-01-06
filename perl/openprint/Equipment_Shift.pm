package openprint::Equipment_Shift;
@ISA = qw(openprint::Object);
require openprint::Object;
require openprint::Shift;

use strict;
use openprint ();
use vars qw( $log $dbh %session $debug $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;

require sql;
require ssi;
require misc;

$debug = 1;

$table = 'equipment_shifts';
$serial = 'equipment_shifts_id_seq';

%fields = (
	'id'			=>	'id',
	'starttime'		=>	'starttime',
	'duration'		=>	'duration',
	'name'			=>	'name',
	'equipment_id'	=>	'equipment_id',
    'operator_id'   =>  'operator_id',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'operator_id'   =>  [ 's/\D//g' ],
);

%defaults = (
	'operator_id'	=>	undef,
	'starttime'		=>	'00:00:00',
	'name'			=>	'Shift',
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
	my $sql = "SELECT *,starttime+duration-'1 second'::interval as endtime FROM $table WHERE 1>0";

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
    } # end if
	if ( $params{'starttime_<'} ) {
        $sql .= ' AND starttime < ?';
        push @values, $params{'starttime_<'};
    } 
	if ( $params{'starttime_>'} ) {
        $sql .= ' AND starttime > ?';
        push @values, $params{'starttime_>'};
    } 
	if ( $params{'starttime_<='} ) {
        $sql .= ' AND starttime <= ?';
        push @values, $params{'starttime_<='};
    } 
	if ( $params{'starttime_>='} ) {
        $sql .= ' AND starttime >= ?';
        push @values, $params{'starttime_>='};
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
	my ( $self, $new ) = @_;
	if ( $new ) {
		$$self{'starttime'} = Date::Format::time2str( '%H:%M:%S', $new );
	} # end if $new
	return Date::Parse::str2time( $_[0]{'starttime'} );
} # end sub starttime_seconds

sub starttime_time_seconds {
	return misc::hms2time( Date::Format::time2str('%H:%M:%S', Date::Parse::str2time( $_[0]{'starttime'} ) ) );
} # end sub starttime_seconds

sub duration_seconds {
	return misc::hms2time( $_[0]{'duration'} );
} # end sub duration_seconds

sub endtime {
	if ( ! $_[0]{'endtime'} ) {
		$_[0]{'endtime'} = Date::Format::time2str( '%H:%M:%S', $_[0]->starttime_seconds() + $_[0]->duration_seconds() );
	} # end if
	return $_[0]{'endtime'};
} # end sub endtime_seconds

sub endtime_seconds {
	return $_[0]->starttime_seconds() + $_[0]->duration_seconds();
} # end sub endtime_seconds

sub emanantise {
	my ( $self, $date_seconds ) = @_;

$log->debug("Emanentise: Date: " . Date::Format::time2str('%Y-%m-%d %H:%M:%S', $date_seconds ) );
	#$date_seconds -= ($date_seconds % (24*3600));
	# The point is to drop any additional time part, but how can that be right? What we want to do is jump gaps
	my $date_part = Date::Parse::str2time( Date::Format::time2str('%Y-%m-%d', $date_seconds ) );
	my $time_part = $date_seconds - $date_part;
	if ( $self->starttime_time_seconds() < $time_part ) {
		# Need to add a day
		$date_seconds = $date_part + ( 60*60*24 );
	} # end if
	my $starttime_seconds = $date_seconds + $self->starttime_time_seconds();
	my $endtime_seconds = $starttime_seconds + $self->duration_seconds();


	my $Shift;
	if ( $Shift = openprint::Shift::find_one(
				'equipment_id'	=>	$$self{'equipment_id'},
				'shift_id'		=>	$$self{'id'},
				'starttime'		=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S', $starttime_seconds ),
				'endtime'		=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S', $endtime_seconds ),
				) ) {
	} else {
		$log->debug("Emanentise: Date: " . Date::Format::time2str('%Y-%m-%d %H:%M:%S', $starttime_seconds ) . " ending: " . 
				Date::Format::time2str('%Y-%m-%d %H:%M:%S', $endtime_seconds)
				);
		$Shift = new openprint::Shift();
		$Shift->save({
				'equipment_id'	=>	$$self{'equipment_id'},
				'operator_id'	=>	( $$self{'operator_id'} ? $$self{'operator_id'} : $openprint::session{'user_id'} ),
				'shift_id'		=>	$$self{'id'},
				'starttime'		=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S', $starttime_seconds ),
				'endtime'		=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S', $endtime_seconds ),
				});
	} # end if
	return $Shift;
} # end sub emanantise


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

sub Operator {
	return new openprint::User( $_[0]{'operator_id'} );
} # end sub Operator

sub First {
	my ( $self ) = @_;
	return find_one( 
			'equipment_id'	=>	$$self{'equipment_id'},
			'order'			=>	'starttime',
			);
} # end sub First

sub Next {
	my ( $self ) = @_;
	return find_one( 
			'equipment_id'	=>	$$self{'equipment_id'},
			'starttime_>'	=>	$$self{'starttime'},
			'order'			=>	'starttime',
			);
} # end sub Next

sub delete {
	foreach my $Shift ( openprint::Shift::find('shift_id'=>$_[0]{'id'}) ) {
#$log->debug("Delete shift " . $Shift->to_string() );
		$Shift->delete();
	} # end foreach
	my $error = $_[0]->SUPER::delete();
} # end sub delete

1;
__END__
