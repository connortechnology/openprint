package openprint::bindery_schedule;
use strict;

require openprint::Project;
require openprint::ProjectService;
require openprint::service;

use vars qw( @columns %services );

@columns = ( 'Cutting','Folding','Stitching','Pending','Finishing','Outsource','Ship Flat' );
%services = (
	'Folding'	=> [ 'Folding','Scoring','Perforating' ],
	'Cutting'	=> [ 'Cutting' ],
	'Stitching'	=> [ 'SaddleStitching','LoopStitching' ],
	'Pending'	=> [ 'HandAssembly' ],
	'Finishing'	=> [ 'Drilling','Padding' ],
	'Outsource'	=> ['Shipping' ],
'Ship Flat'     => ['NoBindery' ],
	);

sub find {
	my %params = @_;
	my @values;
	my $sql = 'SELECT *, starttime+runtime as endtime FROM Bindery_Schedule WHERE 1>0';
	if ( $params{'runtime_start'} and $params{'runtime_end'} ) {
		$sql .= ' AND runtime BETWEEN ( ? AND ? )';
		push @values, @params{'runtime_start','runtime_end'};
	} # end if
	if ( $params{'service_status'} ) {
		if ( ref $params{'service_status'} eq 'ARRAY' ) {
			$sql .= ' AND (SELECT strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=ProjectIndex AND lngServiceIndex=ServiceIndex) IN ('.join(',', map { '?' } @{$params{'service_status'}} ).')';
			push @values, @{$params{'service_status'}};
		} else {
			$sql .= ' AND (SELECT strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=ProjectIndex AND lngServiceIndex=ServiceIndex)=?';
			push @values, $params{'service_status'};
		} # end if
	} # end if
	if ( $params{'service_types'} ) {
		if ( ref $params{'service_types'} eq 'ARRAY' ) {
			$sql .= ' AND servicetype_id IN ( SELECT id FROM Service_Types WHERE name IN ('.join(',', map { '?' } @{$params{'service_types'}} ).') )';
			push @values, @{$params{'service_types'}};
		} else {
			$sql .= ' AND servicetype_id=(SELECT id FROM Service_Types WHERE name=?)';
			push @values, $params{'service_types'};
		} # end if
	} # end if
	if ( $params{'service_type_ids'} ) {
		if ( ref $params{'service_types'} eq 'ARRAY' ) {
			$sql .= ' AND servicetype_id IN ('.join(',', map { '?' } @{$params{'service_types'}} ).')';
			push @values, @{$params{'service_types'}};
		} else {
			$sql .= ' AND servicetype_id=?';
			push @values, $params{'service_types'};
		} # end if
	} # end if
	if ( $params{'project_id'} ) {
		if ( substr($params{'project_id'},0,1) == '!' ) {
			$sql .= ' AND projectindex != ?';
			push @values, substr $params{'project_id'}, 1, length $params{'project_id'};
			$openprint::log->debug("! ($params{'project_id'}) (" . substr($params{'project_id'}, 1, length $params{'project_id'}).')' );
		} else {
			$sql .= ' AND projectindex=?';
			push @values, $params{'project_id'};
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading bindery_schedule: ($sql) (@values)");
		return;
	} # end if
	return @$data;
} # end sub find

sub get_li {
} # end sub get_li

sub add_project {
	my $Project = shift;
	my %services = $Project->services();
	foreach my $service_type ( 'Cutting','Folding','SaddleStitching','LoopStitching','Drilling','Padding','Shipping','Pending' ) {
		foreach my $s_id ( @{$services{$service_type}} ) {
			add( $Project->id(), $s_id, $service_type );
		} # end foreach s_id
	} # end foreach sservice_type
} # end sub add_project

sub add {
	my ( $p_id, $s_id, $s_type ) = @_;

	my ( $service_type_id ) = sql::execute( undef, undef, 'SELECT id FROM Service_Types WHERE name=?', $s_type );
	my ( $start_time ) = sql::execute( undef, undef, 'SELECT MAX(starttime+runtime) FROM Bindery_Schedule WHERE servicetype_id=?', $service_type_id );
	( $start_time ) = sql::execute( undef, undef, 'SELECT NOW()' ) if ! $start_time;

	my $Project = new openprint::Project( $p_id );
	my $runtime = openprint::service::get_runtime( $Project, $s_id );

	openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $p_id, $s_id, 'RunTime', $runtime );
	
	sql::insert( $openprint::log, $openprint::dbh, 'Bindery_Schedule',
		'ProjectIndex', $p_id,
		'ServiceIndex',	$s_id,
		'ServiceType_id',	$service_type_id,
		'StartTime',		$start_time,
		'RunTime',  		join(':', misc::seconds_to_interval( $runtime ) ),
		);

} # end sub add

sub remove {
	sql::execute( undef, undef, q{DELETE FROM Bindery_Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, @_ );
}

sub get_column {
	my $service = shift;
	foreach my $col ( @columns ) {
		if ( sets::isin( $service, $services{$col} ) ) {
			return $col;
		} # end if
	} 
}

sub get_lis {
	my ( $start_time_start, $start_time_end, $service_types, $statuses, $column ) = @_;
	my $html;

	if ( ! $service_types ) {
	$openprint::log->debug("Loading service_types");
		foreach my $col ( @columns ) {
			if ( sets::isin( $column, $services{$col} ) ) {
				$service_types = $services{$col};
				$column = $col;
				last;
			} # end if
		} 
	} # end if

	my @schedule = find( 
				'start_time_start'	=> sprintf('%s 00:00:00', $start_time_start ),
				'start_time_end'	=> sprintf('%s 23:59:59', $start_time_end ),
				'service_types'		=> $service_types,
				'service_status'	=> $statuses,
				'order'				=> 'starttime',
				);

	if ( @schedule ) {
		if ( my @projects = map { $$_{'projectindex'} } @schedule ) {
			if ( my @companies = map { $_->company_id() } openprint::Project::find( 'id'=>\@projects ) ) {
				openprint::Company::find( 'id'=>\@companies );
			} # end if
		} # end if
	} # end if

	foreach my $row ( @schedule ) {
		my $Project = new openprint::Project( $$row{'projectindex'} );
		my $Service = new openprint::ProjectService( $$row{'serviceindex'} );
		my %specs = openprint::service::get_specifications_pairs( $openprint::log, $openprint::dbh, @$row{'projectindex','serviceindex'} );

		my $colour = 'white';
		if ( sets::isin( $Service->status(), ['In Production', 'On Hold'] ) ) {
			$colour = 'blue';
		} elsif ( sets::isin( $Project->status(), 'In Prepress', 'Proofs Out', 'Approved' ) ) {
			$colour = 'green';
		} elsif ( sets::isin( $Project->status(), 'Complete','Waiting For Pickup', 'Picked Up', 'Shipped' ) ) {
# Shouldn't happen, but can...
			$colour = 'pink';
		} # end if
		$html .= sprintf( '<li id="service_%d" class="%s">', $$row{'serviceindex'}, $colour );

		$html .= '<div class="Company">';
		$html .= sprintf( '<a class="handle" href="/employee/project/view.html?ProjectIndex=%1$d&Docket=%2$d">%2$d</a>', $Project->id(), $Project->docket() );
		$html .= ssi::htmlize(substr( $Project->Company()->name(), 0, 20 ));
		$html .= '</div>';

		if ( openprint::usergroup::is_user_in( ['BinderyManager'], $openprint::session{'user_id'} ) ) {
			$html .= sprintf( q{<div id="%2$dComment" class="Comment" onClick="editComment( %1$d, %2$d, '%3$s', event );">%3$s&nbsp;</div>}, @$row{'projectindex','serviceindex'}, $specs{'txtEmployeeComments'} );
			$html .= qq`<span class="DueDate" id="JumpToDate$$row{'serviceindex'}">`;
			if ( ! $Project->due_date() ) {
				$html .= 'no duedate';
			} else {
				my ( $year, $month, $day ) = split('-', $Project->due_date() );
				if ( $month ) { $html .= '&nbsp;'.substr( Date::Calc::Month_to_Text( $month ),0, 3); } 
				$html .= qq` $day`;
			} # end if
			$html .= '</span>';
			$html .= sprintf( '<input type="hidden" name="ScheduleDate-%1$d" id="ScheduleDate-%1$d" value="%2$s"/>
					<script type="text/javascript">
						Calendar.setup({
							inputField	:	"ScheduleDate-%1$d",      // id of the input field
							ifFormat	:	"\%Y-\%m-\%d",       // format of the input field
							daFormat	:	"\%b \%d",
							align		:	"Tl",
							showsTime	:	false,            // will display a time selector
							displayArea	:	"JumpToDate%1$d",
							singleClick	:	false,           // double-click mode
							onClose		:	setduedate
						});
					</script>
					', $$row{'serviceindex'}, $Project->due_date() );

			$html .= '<span style="float:left; margin-left: 5px;">';
			$html .= ssi::writeButton( $openprint::log, $openprint::dbh, 'Complete'.$$row{'serviceindex'}, '', "if(confirm('Are you sure?')){complete_project($$row{'projectindex'} );};", '', 'C' );
			$html .= ssi::writeButton( $openprint::log, $openprint::dbh, 'Remove'.$$row{'serviceindex'}, '', "if(confirm('Are you sure?')){remove_project($$row{'projectindex'});}", '', 'D' );
			$html .= '</span>';
		} else {
			$html .= qq`<div class="Comment">$specs{'txtEmployeeComments'}</div>`;
			$html .= q`<span class="DueDate">`;
			my ( $year, $month, $day ) = split('-', $Project->due_date() );
			if ( $month ) { $html .= substr( Date::Calc::Month_to_Text( $month ),0, 3); };
			$html .= qq` $day</span>`;
		} # end if
		$html .= 'Qty: ' . $specs{'txtQuantity'.$Project->ordered_quantity_index()};
		#$html .= ' ' . $specs{'ServiceType'};
		$html .= '<br class="spacer"/><div style="width:100%; text-align: left;">';
		my %services = $Project->services();
		foreach my $service ( 'Cutting','Folding','SaddleStitching','Drilling','HandAssembly','Shipping' ) {
			$html .= '<span class="icon" style="float: left;">';
			if ( ! $services{$service} ) {
				$html .= '<br/>';
				$html .= sprintf(q{<a href="#" onClick="icon_action(%1$d,%2$d,'%3$s','%4$s');return false;"><img class="icon" name="%1$d%3$sicon" src="/images/icons/bindery/%3$s-grey.gif" /></a>},@$row{'projectindex','serviceindex'}, $service, openprint::bindery_schedule::get_column($service) );
			} else {
				my $Icon_Service = new openprint::ProjectService( $services{$service}[0] );

				my %specs = openprint::service::get_specifications_pairs( $openprint::log, $openprint::dbh, $Project->id(), $services{$service}[0] );
				if ( ! $specs{'RunTime'} ) {
					$specs{'RunTime'} = openprint::service::get_runtime( $Project, $services{$service}[0] );
					$openprint::log->debug("RunTime: $specs{'RunTime'}");
					if ( $specs{'RunTime'} ) {
						openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $Project->id(), $services{$service}[0], 'RunTime', $specs{'RunTime'} );
						sql::update( undef, undef, 'Bindery_Schedule', ['projectindex=? AND serviceindex=?', $Project->id(), $services{$service}[0] ], ['runtime', $specs{'RunTime'} ] );
					} # end if
				} # end if

				$html .= sprintf(q{<span id="%2$d-%3$d-RunTime" onClick="editRunTime( %1$d, %3$d, %2$d, '%4$d:%5$.2d', event);">%4$d:%5$.2d</span>}, @$row{'projectindex','serviceindex'}, $services{$service}[0], misc::seconds_to_interval( $specs{'RunTime'} ) ) . '<br/>';

				if ( $Icon_Service->status() eq 'In Production' ) {
					$html .= sprintf(q{<a href="#" onClick="icon_action(%1$d,%2$d,'%3$s','%4$s');return false;"><img class="icon" name="%1$d%3$sicon" src="/images/icons/bindery/%3$s-white.gif" /></a>},@$row{'projectindex','serviceindex'}, $service, openprint::bindery_schedule::get_column($service) );
				} elsif ( $Icon_Service->status() eq 'On Hold' ) {
					$html .= sprintf(q{<a href="#" onClick="icon_action(%1$d,%2$d,'%3$s', '%4$s');return false;"><img class="icon" name="%1$d%3$sicon" src="/images/icons/bindery/%3$s-red.gif" /></a>},@$row{'projectindex','serviceindex'}, $service, openprint::bindery_schedule::get_column($service) );
				} elsif ( $Icon_Service->status() eq 'Complete' ) {
					$html .= sprintf(q{<a href="#" onClick="icon_action(%1$d,%2$d,'%3$s', '%4$s');return false;"><img class="icon" name="%1$d%3$sicon" src="/images/icons/bindery/%3$s-checkmark.gif" /></a>},@$row{'projectindex','serviceindex'}, $service, openprint::bindery_schedule::get_column($service) );
				} elsif ( sets::isin( $Icon_Service->status(), 'Ordered','uncalculated','calculated' ) ) {
					$html .= sprintf(q{<a href="#" onClick="icon_action(%1$d,%2$d,'%3$s', '%4$s');return false;"><img class="icon" name="%1$d%3$sicon" src="/images/icons/bindery/%3$s-green.gif" /></a>},@$row{'projectindex','serviceindex'}, $service, openprint::bindery_schedule::get_column($service) );
				} # end if

			} # end if
			$html .= '</span>';
		} # end foreach
		if ( sets::isin( $Service->status(), [ 'In Production', 'On Hold' ] ) ) {
			$html .= '<span class="icon" style="float: right;"><br/>';
			$html .= sprintf(q{<a href="#" onClick="icon_action(%1$d,%2$d,'%3$s','Complete');return false;"><img class="icon" name="%1$d%3$sCompleteicon" src="/images/icons/bindery/Complete.gif" /></a>},@$row{'projectindex','serviceindex'}, $specs{'ServiceType'} );
			$html .= '</span>';
		} else {
			$html .= '<span class="icon" style="float: right;"><br/>';
			$html .= sprintf(q{<a href="#" onClick="move_up(%1$d,%2$d,'%3$s','%4$s');return false;"><img class="icon" src="/images/icons/bindery/UP.gif" /></a>},@$row{'projectindex','serviceindex'}, $specs{'ServiceType'}, openprint::bindery_schedule::get_column($specs{'ServiceType'} ) );
			$html .= '</span>';
		} # end if
		$html .= '<br class="spacer"/></div>';
		$html .= '</li>';
	} # end foreach row

	return $html;
} # end sub get_lis

sub apply_sort {
$openprint::log->debug("Applying Sort");
	my $ac = sql::start_transaction( $openprint::dbh );
	my $starttime = $_[0]{starttime};
	foreach my $row ( @_ ) {
		sql::update( undef, undef, 'Bindery_Schedule', "ProjectIndex=$$row{'projectindex'} AND ServiceIndex=$$row{'serviceindex'}", 'starttime', $starttime );
		( $starttime ) = sql::execute( undef, undef, q{SELECT starttime+runtime FROM Bindery_Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, @$row{'projectindex','serviceindex'} );
	} # end foreach
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub apply_sort

sub move_up {
	my ( $p_id ) = @_;

	my @results;
	my %sorting;
	my %service_types = map { $_->id(), $_->name() } openprint::ServiceType::find();
	foreach my $row ( find( 'project_id'=> $p_id, 'statuses'=>['calculated','uncalculated','Ordered'] ) ) {
		my $column = get_column($service_types{$$row{'servicetype_id'}} );
		if ( ! $column ) {
		$openprint::log->error("Unknown column for $service_types{$$row{'servicetype_id'}} $$row{'servicetype_id'}");
		} # end nif
		push @{$sorting{$column}}, $row;
	} # end foreach

	foreach my $column ( keys %sorting ) {
		# Get starttime
		my @rows = find( 'servicetypes'=>$services{$column}, 'statuses'=>['In Production','OnHold'],'order'=>'starttime desc', 'limit'=>'1' );
		if ( @rows ) {
			$sorting{$column}[0]{starttime} = $rows[0]{endtime};
		} # end if
		push @{$sorting{$column}}, find( 'project_id'=>'!'.$p_id, 'servicetypes'=>$services{$column}, 'statuses'=>['calculated','uncalculated','Ordered'],'order'=>'starttime' );
		apply_sort( @{$sorting{$column}} );
		push @results, 
			 join('~', 'Div', $column.'-calculateduncalculatedOrdered', get_lis( join('-', @openprint::session{'/employee/production/bindery_schedule.html?ddmScheduleStartYear','/employee/production/bindery_schedule.html?ddmScheduleStartMonth','/employee/production/bindery_schedule.html?ddmScheduleStartDay'}), join('-', @openprint::session{'/employee/production/bindery_schedule.html?ddmScheduleEndYear','/employee/production/bindery_schedule.html?ddmScheduleEndMonth','/employee/production/bindery_schedule.html?ddmScheduleEndDay'}), $services{$column}, ['calculated','uncalculated','Ordered'], $column ) );
	} # end foreach column
	return join('|', @results );
} # end sub move_up

sub drop {
	my $stuff = shift;
	my %rows = map { $_->{serviceindex}, $_ } find();
	my %sorting;
	foreach my $row ( split('&', $stuff ) ) {
		$row =~ /(.*)\[\]=(\d*)/;
		my ( $column, $s_id ) = ( $1, $2 );
		push @{$sorting{$column}}, $rows{$s_id};
	} # end foreach

	#my @results;
	foreach my $column ( keys %sorting ) {
		apply_sort( @{$sorting{$column}} );
		#push @results, 
			 #join('~', 'Div', $column.'-uncalculatedOrdered', get_lis( join('-', @openprint::session{'/employee/production/bindery_schedule.html?ddmScheduleStartYear','/employee/production/bindery_schedule.html?ddmScheduleStartMonth','/employee/production/bindery_schedule.html?ddmScheduleStartDay'}), join('-', @openprint::session{'/employee/production/bindery_schedule.html?ddmScheduleEndYear','/employee/production/bindery_schedule.html?ddmScheduleEndMonth','/employee/production/bindery_schedule.html?ddmScheduleEndDay'}), $services{$column}, ['uncalculated','Ordered'], $column ) );
	} # end foreach
	#return join('|', @results );
} # end sub drop

1;
__END__
