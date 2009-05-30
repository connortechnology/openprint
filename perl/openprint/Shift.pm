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
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
);

%defaults = (
);

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
		$sql .= ' AND shift_id =(SELECT id FROM Equipment_shifts WHERE name=? AND equipment_id=?)';
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
    } elsif ( $params{'starttime_<'} ) {
        $sql .= ' AND starttime < ?';
        push @values, $params{'starttime_<'};
    } elsif ( exists $params{'starttime_start'} and ! $params{'starttime_start'} ) {
        $sql .= ' AND starttime IS NULL';
    } elsif ( exists $params{'starttime_end'} and ! $params{'starttime_end'} ) {
        $sql .= ' AND starttime IS NULL';
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
    } elsif ( $params{'endtime_<'} ) {
        $sql .= ' AND endtime < ?';
        push @values, $params{'endtime_<'};
    } elsif ( exists $params{'endtime_start'} and ! $params{'endtime_start'} ) {
        $sql .= ' AND endtime IS NULL';
    } elsif ( exists $params{'endtime_end'} and ! $params{'endtime_end'} ) {
        $sql .= ' AND endtime IS NULL';
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

sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

sub to_string {
	my ( $self ) = @_;
	return sprintf('%s %s %s to %s %s', $self->Equipment()->name(), $self->name(), $$self{'starttime'}, $$self{'endtime'}, $self->Operator()->name() );
} # end sub to_string

sub get_lis {
	my ( $Shift, $filters ) = @_;

	my ( $s, $min, $h, $day, $month, $year );
	if ( $Shift->starttime() ) {
		( $s, $min, $h, $day, $month, $year ) = Date::Parse::strptime( $Shift->starttime );
		$year += 1900;
		$month += 1;
	} # endif

	my @schedule = openprint::press_schedule::find(
			'starttime_null'	=>	$Shift->starttime() ? 0 : 1,
			'starttime_>='	=>	$Shift->starttime(),
			'starttime_<'	=>	$Shift->endtime(),
			'equipment_id'	=>	$Shift->equipment_id(),
			'order'			=>	'starttime,serviceindex',
			);

	my $html;
	my $ul_id = $Shift->ul_id();

	my $previous_row;
	my $total_impressions;

	for ( my $index = 0; $index < @schedule; $index += 1 ) {
		my $current_row = $schedule[$index];

		if ( $filters ) {
			if ( $$filters{'Status'} ) {
				my $Project = new openprint::Project($$current_row{'projectindex'});
				next if ! sets::isin( $Project->status(), $$filters{'Status'} );
			} # end if
		} # end if
		
		$html .= openprint::press_schedule::get_li( $previous_row, $current_row, $ul_id );
		my $sig_specs = openprint::service::get_specs_ref( new openprint::Project( $$current_row{'project_index'} ),$$current_row{'serviceindex'} );
		$total_impressions += $$sig_specs{'ImpressionQuantity'};
		$previous_row = $current_row;
	} # end for

	if ( $Shift->name() and Date::Calc::check_date( $year, $month, $day ) ) {
		my $Operator = $Shift->Operator();

		if ( openprint::usergroup::is_user_in( ['PressManager'], $openprint::session{'user_id'} ) ) {
			$html = sprintf( q{<div class="When"><span style="float: left;">%s %d %.3s %s %s to %s</span><span class="TotalImpressions">(%d)</span><span class="%s" id="%sOperator" onclick="openPopup('Operator', '%s', '%s' );">%s</span><br class="spacer"/></div>}, Date::Calc::Day_of_Week_Abbreviation( Date::Calc::Day_of_Week($year, $month, $day)), $day, Date::Calc::Month_to_Text( $month ), $Shift->name(), 
			Date::Format::time2str('%H:%M', $Shift->starttime_seconds() ),
			Date::Format::time2str('%H:%M', $Shift->endtime_seconds() ),
$total_impressions, ($Operator->id() ? 'Operator' : 'assign' ),$ul_id, $ul_id, $Operator->id(),($Operator->id() ? $Operator->name() : 'assign') ) . $html;
		} else {
			$html = sprintf( '<div class="When"><span style="float: left;">%s %d %.3s %s %s to %s</span><span style="float: right;">%s</span><br class="spacer"/></div>', Date::Calc::Day_of_Week_Abbreviation( Date::Calc::Day_of_Week($year, $month, $day)), $day, Date::Calc::Month_to_Text( $month ), $Shift->name(), 
			Date::Format::time2str('%H:%M', $Shift->starttime_seconds() ),
			Date::Format::time2str('%H:%M', $Shift->endtime_seconds() ),
			( $Operator->id() ? $Operator->name() : 'assign' ) ) . $html;
		} # end if
	} # end if
	return $html;
} # end sub

sub ul_id {
	my ( $self ) = @_;
	if ( $self->starttime() ) {
		return sprintf('%d-%s-%s', $$self{'equipment_id'}, Date::Format::time2str('%Y-%m-%d', $self->starttime_seconds() ), $self->name() );
	} else {
		return sprintf('%d-%s', $$self{'equipment_id'}, $self->name() );
	} # end if
} # end sub ul_id

sub get_from_ul_id {
	my ( $id ) = @_;

	$id =~ /^(\d*)-(\d\d\d\d-\d\d-\d\d)?-?(\w*)$/;
    my ( $equipment_id, $date, $shift_name ) = ( $1, $2, $3 );

    my $Shift;
    if ( $shift_name and $date ) {
		my $date_seconds = Date::Parse::str2time($date);
        my @Shifts = openprint::Shift::find('equipment_id'=>$equipment_id, 'name'=>$shift_name, 'startdate'=>$date,'limit'=>1 );
        if ( ! @Shifts ) {
            @Shifts = openprint::Equipment_Shift::find('equipment_id'=>$equipment_id, 'name'=>$shift_name );
            $Shift = $Shifts[0]->emanantise( $date_seconds ) if @Shifts;
        } else {
            $Shift = $Shifts[0];
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

1;
#__END__
