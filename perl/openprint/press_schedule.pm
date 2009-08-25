package openprint::press_schedule;
use POSIX qw{ceil};
use strict;
use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require openprint::Project;
require openprint::Service;
require openprint::service;
require Date::Calc;

my $debug = 1;

sub find {
	my %params = @_;
	my @values;
	my $sql = 'SELECT *, starttime+runtime as endtime FROM Schedule WHERE 1>0';
	if ( $params{'runtime_start'} and $params{'runtime_end'} ) {
		$sql .= ' AND runtime BETWEEN ( ? AND ? )';
		push @values, @params{'runtime_start','runtime_end'};
	} # end if
	if ( exists $params{'starttime'} ) {
		$sql .= ' AND starttime = ?';
		push @values, $params{'starttime'};
	} # end if
	if ( exists $params{'starttime_null'} ) {
		$sql .= ' AND starttime IS ' . ($params{'starttime_null'} ? '' : 'NOT ' ) . ' NULL';
	} # end if
	if ( $params{'starttime_<'} ) {
		$sql .= ' AND starttime < ?';
		push @values, $params{'starttime_<'};
	} # end if
	if ( $params{'starttime_>='} ) {
		$sql .= ' AND starttime >= ?';
		push @values, $params{'starttime_>='};
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
	} elsif ( exists $params{'starttime_start'} and ! $params{'starttime_start'} ) {
		$sql .= ' AND starttime IS NULL';
	} elsif ( exists $params{'starttime_end'} and ! $params{'starttime_end'} ) {
		$sql .= ' AND starttime IS NULL';
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
	if ( $params{'equipment_id'} ) {
		$sql .= ' AND equipment_id=?';
		push @values, $params{'equipment_id'};
	} # end if
	if ( $params{'id'} ) {
		$sql .= ' AND id=?';
		push @values, $params{'id'};
	} # end if
	if ( $params{'project_id'} ) {
		if ( substr($params{'project_id'},0,1) == '!' ) {
			$sql .= ' AND projectindex != ?';
			push @values, substr $params{'project_id'}, 1, length $params{'project_id'};
		} else {
			$sql .= ' AND projectindex=?';
			push @values, $params{'project_id'};
		} # end if
	} # end if
	if ( $params{'service_id'} ) {
		$sql .= ' AND serviceindex=?';
		push @values, $params{'service_id'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->error( "Error loading schedule: ($sql) (@values) : " . $dbh->errstr() );
		return;
	} elsif ( $debug ) {
		$log->debug( "Loading schedule: ($sql) (@values) : " . @$data ); 
	} # end if
	return @$data;
} # end sub find

# Takes an array of hash pointers.  Each hash is an item to schedule assumes that the item is not already on the schedule.  Code should determine that prior to calling add
sub add {
	my $error = '';
	foreach my $item ( @_ ) {
		my ( $start_time ) = sql::execute( undef, undef, 'SELECT MAX(starttime+runtime) FROM Schedule WHERE equipment_id=?', $$item{equipment_id} );
		( $start_time ) = sql::execute( undef, undef, 'SELECT NOW()' ) if ! $start_time;

		my $runtime = openprint::service::get_runtime( new openprint::Project( $$item{'projectindex'} ), $$item{'serviceindex'} );

		$error .= sql::insert( undef, undef, 'Schedule',
				'ProjectIndex', $$item{projectindex},
				'ServiceIndex',	$$item{serviceindex},
				'equipment_id',	$$item{equipment_id},
				'StartTime',		$start_time,
				'RunTime',			join(':', misc::seconds_to_interval( $runtime ) ),
				);
	} # end foreach item
	return $error;
} # end sub add

sub remove {
	my ( $p_id, $s_id ) = @_;
	if ( ! $s_id ) {
		my $Project = new openprint::Project( $p_id );
		foreach $s_id ( $Project->signatures() ) {
			sql::execute( undef, undef, q{DELETE FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, $p_id, $s_id );
		} # end foreach
	} else {
		sql::execute( undef, undef, q{DELETE FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, $p_id, $s_id );
	} # end if
}

sub get_li {
	my ( $previous_row, $row, $ul_id ) = @_;

	my $html;
	if ( ! $$row{'projectindex'} ) {
		$html .= sprintf( '<li id="item_%d" class="%s">Reserved', $$row{'id'}, 'reserved' );
		$html .= '<span class="Buttons">';
		$html .= ssi::writeButton( $log, $dbh, 'Remove'.$$row{'id'}, '', "if(confirm('Are you sure?')){f1.schedule_id.value=$$row{'id'};f1.btnFunction.value='RemoveJob';f1.submit();}", '', 'D' );
		$html .= '</span>';
		$html .= sprintf( q{<span class="RunTime" onclick="openPopup( 'RunTime', %1$d );"><span id="%1$dRunTime">%2$.2d:%3$.2d</span></span>}, $$row{'id'}, split(':',$$row{'runtime'}) );
		$html .= '<br/></li>';
		return $html;
	} # end if

	my $Project = new openprint::Project( $$row{'projectindex'} );
	my $services = $Project->services();
	my $Equipment = new openprint::Equipment($$row{equipment_id});

	my $sig_specs = openprint::service::get_specs_ref( $Project, $$row{'serviceindex'} );
	if ( ! $$sig_specs{'txtEmployeeComments'} ) {
		my @side_one = openprint::Estimating::Printing::get_colours( $sig_specs, 'SideOne' );
		my @side_two = openprint::Estimating::Printing::get_colours( $sig_specs, 'SideTwo' );
		my $comments = sprintf( '%d/%d', scalar @side_one, scalar @side_two );

		my %pms;
		foreach my $side ( 'SideOne', 'SideTwo' ) {
			foreach my $index ( 1 .. 8 ) {
				if ( $$sig_specs{'chkSpecial'.$side.'Colour'.$index} ) {
					if ( $$sig_specs{'txtSpecial'.$side.'Colour'.$index} ) {
						$pms{$index} += 1;
					} # end if
				} # end if
			} # end foreach index
		} # end foreach side
		if ( keys %pms ) {
			$comments .= '+' . ( keys %pms ) . ' PMS';
		} # end if

		if ( $$sig_specs{'rdbAqueousSideOne'} ne 'None' or $$sig_specs{'rdbAqueousSideTwo'} ne 'None' ) {
			$comments .= '+AQ';
		} # end if
		if (
				$$sig_specs{'chkVarnishSpotGlossSideOne'}
				or $$sig_specs{'chkVarnishSpotMatteSideOne'}
				or $$sig_specs{'chkVarnishOverallGlossSideOne'}
				or $$sig_specs{'chkVarnishOverallMatteSideOne'}
				or $$sig_specs{'chkVarnishSpotGlossSideTwo'}
				or $$sig_specs{'chkVarnishSpotMatteSideTwo'}
				or $$sig_specs{'chkVarnishOverallGlossSideTwo'}
				or $$sig_specs{'chkVarnishOverallMatteSideTwo'}
			) {
			$comments .= '+Varnish';
		} # end if

		$comments .= ' on ' . $$sig_specs{'ddmStockSheetSize'.$Project->ordered_quantity_index()};

		if ( $Equipment->specification('Folding Capable') eq 'When Printing' ) {
			if ( $$services{'Folding'} ) {
				my $fold_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
				if ( $$fold_specs{'ddmEquipment-'.$$sig_specs{'SignatureIndex'}.'-'.$Project->ordered_quantity_index()} == $Equipment->id() ) {
					$comments .= '(fold inline)';
				} # end if
			} else {
				$comments .= '(sheeted)';
			} # end if
		} # end if
		openprint::service::insert_service_spec( $log, $dbh, @$row{'projectindex','serviceindex'}, 'txtEmployeeComments', $comments );
	} # end if

	if ( ! $$sig_specs{'SignatureQuantity'} ) {
		$$sig_specs{'SignatureQuantity'} = $$sig_specs{'txtSignatureQuantity'} ? $$sig_specs{'txtSignatureQuantity'} : 1;
		openprint::service::insert_service_spec( $log, $dbh, @$row{'projectindex', 'serviceindex'}, 'SignatureQuantity', $$sig_specs{'SignatureQuantity'} );
	} # end if
	if ( ! $$sig_specs{'ImpressionQuantity'} ) {
		$$sig_specs{'ImpressionQuantity'} = $$sig_specs{'hdnImpressionQuantity'.$Project->ordered_quantity_index()};
		openprint::service::insert_service_spec( $log, $dbh, @$row{'projectindex', 'serviceindex'}, 'ImpressionQuantity', $$sig_specs{'ImpressionQuantity'} );
	} # end if
	my $colour = 'blue';
	if ( sets::isin( $Project->status(), ['In Prepress', 'Proofs Out','Waiting For QA Approval'] ) ) {
		$colour = 'green';
	} elsif ( sets::isin( $Project->status(), ['Printed', 'Complete','Waiting For Pickup', 'Picked Up', 'Shipped'] ) ) {
		$colour = 'pink';
	} elsif ( sets::isin( $Project->status(), ['Waiting For Customer Approval'] ) ) {
		$colour = 'red';
	} elsif ( 1 < sql::execute( $log, $dbh, q{SELECT DISTINCT equipment_id FROM Schedule WHERE projectindex=?}, $$row{'projectindex'} ) ) {
		$colour = 'yellow';
	} # end if
	if ( $Project->rush() ) {
		$colour .= ' rush';
	} # end if
	$html .= sprintf( '<li id="item_%d" class="%s">', $$row{'id'}, $colour );
	if ( ( ! $previous_row ) or ( $$row{'projectindex'} != $$previous_row{'projectindex'} ) ) {
		$html .= '<div class="Company">';
		$html .= sprintf( '<a class="docket" href="/employee/project/view.html?ProjectIndex=%1$d&Docket=%2$d">%2$d</a>', $$row{'projectindex'}, $Project->docket() );
		my $n = $Project->Company()->name();
		$n =~ s/The //gi;
		$html .= ssi::htmlize( $n );
		$html .= '</div>';
		$html .= qq`<span class="DueDate" id="JumpToDate$$row{'serviceindex'}">`;
		if ( ! $Project->due_date() ) {
			$html .= 'no duedate</span>';
		} else {
			my ( $year, $month, $day ) = split('-', $Project->due_date() );
			if ( $month ) { $html .= '&nbsp;'.substr( Date::Calc::Month_to_Text( $month ),0, 3); } # end if
				$html .= qq` $day</span>`;
		} # end if

		if ( openprint::usergroup::is_user_in( ['Scheduling'], $openprint::session{'user_id'} ) ) {
			$html .= sprintf(q`<input type="hidden" name="ScheduleDate-%1$d" id="ScheduleDate-%1$d" value="%2$s"/>`, $$row{'serviceindex'}, $Project->due_date() );
		} # end if
	} # end if
	if ( openprint::usergroup::is_user_in( ['Scheduling'], $openprint::session{'user_id'} ) ) {
		$html .= sprintf( q{<div id="%2$dComment" class="Comment" onclick="openPopup( 'Comment', '%1$s', '%2$s' );">%3$s</div>}, @$row{'projectindex','serviceindex'}, $$sig_specs{'txtEmployeeComments'} );

		$html .= sprintf( q{<span class="Forms" id="%2$dForms" onclick="openPopup( 'Forms', '%1$s', '%2$s' );">%3$d %4$s</span>}, @$row{'projectindex','serviceindex'}, $$sig_specs{'SignatureQuantity'}, ($$sig_specs{'SignatureQuantity'} > 1 ? ' forms' : ' form') );
		$html .= sprintf( q{<span id="%2$dImpressions" class="Impressions" onclick="openPopup( 'Impressions', %1$s, %2$s );">%3$d imps</span>}, @$row{'projectindex','serviceindex'}, $$sig_specs{'ImpressionQuantity'} );

		$html .= '<span class="Buttons">';
		$html .= ssi::writeButton( $log, $dbh, 'Approve'.$$row{'serviceindex'}, '', "if(confirm('Are you sure?')){f1.ProjectIndex.value=$$row{'projectindex'};f1.ServiceIndex.value=$$row{'serviceindex'};f1.btnFunction.value='ApproveJob';f1.submit();}", '', 'A' ) if sets::isin( $Project->status(), 'In Prepress', 'Proofs Out','Waiting For Customer Approval','Waiting For QA Approval' );
		$html .= ssi::writeButton( $log, $dbh, 'Bump'.$$row{'id'}, '', "popup_window('_bump_job.html','id=$$row{id}');", '', 'B' );
		$html .= ssi::writeButton( $log, $dbh, 'Complete'.$$row{'serviceindex'}, '', "ajax_window('_signature_completion_popup.html?project_id='+$$row{'projectindex'}+'&amp;service_id='+$$row{serviceindex} );", '', 'C' );
		#$html .= ssi::writeButton( $log, $dbh, 'Complete'.$$row{'serviceindex'}, '', "if(confirm('Are you sure?')){f1.ProjectIndex.value=$$row{'projectindex'};f1.ServiceIndex.value=$$row{'serviceindex'};f1.btnFunction.value='CompleteJob';f1.submit();}", '', 'C' );
		$html .= ssi::writeButton( $log, $dbh, 'Remove'.$$row{'serviceindex'}, '', "if(confirm('Are you sure?')){f1.schedule_id.value=$$row{'id'};f1.btnFunction.value='RemoveJob';f1.submit();}", '', 'D' );
		$html .= ssi::writeButton( $log, $dbh, 'Split'.$$row{'serviceindex'}, '', "if(confirm('Are you sure?')){split_job($$row{'projectindex'}, $$row{'serviceindex'}, '$ul_id' );}", '', 'S' ) if $$sig_specs{'SignatureQuantity'} > 1;
		$html .= ssi::writeButton( $log, $dbh, 'Stock'.$$row{'serviceindex'}, '', "popup_window('_stock_details.html','project_id='+$$row{'projectindex'} );", '', 'P' );
		$html .= '</span>';
if ( $Equipment->smartscheduling() ) {
		$html .= sprintf( q`<span class="StartTime" onclick="ajax_window( '_starttime_popup.html?id=%1$d' );">Start:<span id=%1$dStartTime">%2$s</span><img src="/images/small-%3$s.gif" alt="%3$s"/></span>`, $$row{'id'},
				Date::Format::time2str( '%H:%M', Date::Parse::str2time( $$row{'starttime'} ) ),
				$$row{'starttime_locked'} ? 'locked' : 'unlocked',
				);
} # end if

		$html .= sprintf( q{<span id="%1$dRunTime" class="RunTime" onclick="openPopup( 'RunTime', %1$d );">%2$.2d:%3$.2d</span>}, $$row{'id'}, split(':',$$row{'runtime'}) );
if ( $Equipment->smartscheduling() ) {
		$html .= '<span class="Services">';
		$html .= '<span class="Service">fold</span>' if $$services{'Folding'};
		$html .= '<span class="Service">stitch</span>' if $$services{'SaddleStitching'} or $$services{'LoopStitching'};
		$html .= '<span class="Service">trim</span>' if $$services{'Cutting'};
		$html .= '</span>';
}
	} else {
		$html .= sprintf( '<div class="Comment"><a href="/employee/proj/prin/prin_multi.html?ProjectIndex=%1$d&amp;ServiceIndex=%2$d">%3$s</a></div>', @$row{'projectindex','serviceindex'}, ssi::htmlize($$sig_specs{'txtEmployeeComments'}) );
		$html .= sprintf( '<span class="Forms">%d %s</span>', $$sig_specs{'SignatureQuantity'}, ($$sig_specs{'SignatureQuantity'} > 1 ? ' forms' : ' form') );
		$html .= sprintf( '<span class="Impressions">%d imps</span>', $$sig_specs{'ImpressionQuantity'} );
		$html .= '<span class="Buttons">';
		$html .= ssi::writeButton( $log, $dbh, 'Paper'.$$row{'serviceindex'}, '', "popup_window('_stock_details.html','project_id='+$$row{'projectindex'} );", '', 'P' );
		$html .= '</span>';
		$html .= sprintf( q`<span class="StartTime">Start:%2$s</span>`, $$row{'id'},
				Date::Format::time2str( '%H:%M', Date::Parse::str2time( $$row{'starttime'} ) ),
				);
		$html .= sprintf( q{<span class="RunTime">%2$.2d:%3$.2d</span>}, $$row{'id'}, split(':',$$row{'runtime'}) );
if ( $Equipment->smartscheduling() ) {
		$html .= '<span class="Services">';
		$html .= '<span class="Service">fold</span>' if $$services{'Folding'};
		$html .= '<span class="Service">stitch</span>' if $$services{'SaddleStitching'} or $$services{'LoopStitching'};
		$html .= '<span class="Service">trim</span>' if $$services{'Cutting'};
		$html .= '</span>';
}
	} # end if
	$html .= "<br/></li>\n";
	return $html;
} # end sub get_li


sub get_ul {
    my ( $start_time_start, $start_time_end, $equipment_id, $Shift, $filters ) = @_;

    my ( $s, $min, $h, $day, $month, $year );
    if ( $start_time_start ) {
        ( $s, $min, $h, $day, $month, $year ) = Date::Parse::strptime( $start_time_start );
    } # endif
        $year += 1900;
        $month += 1;
    my $ul_id = sprintf('%d-%.4d-%.2d-%.2d-%s', $equipment_id, $year, $month, $day, $Shift->name() );
    my $content = get_lis($ul_id, $start_time_start, $start_time_end, $equipment_id, $Shift, $filters);

	return qq{<ul id="$ul_id" class="shift} . ($content ? '' : ' Empty' ) .'">' . $content. "</ul>\n";
} # end sub get_ul

sub apply_sort {
$log->debug("Applying Sort");
	my $ac = sql::start_transaction( $dbh );
	my $starttime = $_[0]{starttime};
	foreach my $row ( @_ ) {
		sql::update( undef, undef, 'Schedule', ['ProjectIndex=? AND serviceindex=?', @$row{'projectindex','serviceindex'}], 'starttime', $starttime );
		( $starttime ) = sql::execute( undef, undef, q{SELECT starttime+runtime FROM Schedule WHERE ProjectIndex=? AND ServiceIndex=?}, @$row{'projectindex','serviceindex'} );
	} # end foreach
	sql::end_transaction( $dbh, $ac );
} # end sub apply_sort

sub split_job {
	my ( $project_index, $service_index, $ul_id ) = @_;

	my $Project = new openprint::Project( $project_index );
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Splitting forms' );

	my %specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $service_index );

	my $ac = sql::start_transaction( $dbh );

	my $new_service_index = openprint::print_project::insert_service( $log, $dbh, $project_index, 'AdditionalSignature' );
	my %new_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $new_service_index );
	$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
	($specs{'SignatureIndex'}) = sql::execute( $log, $dbh, $_, $project_index );
	$specs{'SignatureIndex'} += 1;

	foreach my $key ( keys %specs ) {
		if ( $specs{$key} and ( $specs{$key} ne $new_specs{$key} ) ) {
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, $key, $specs{$key}, exists $new_specs{$key} );
		} # end if
	} # end foreach

# Fix everything in the new service
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'txtPrice1', ($specs{'txtPrice1'}/$specs{'SignatureQuantity'}) );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'txtPrice2', ($specs{'txtPrice2'}/$specs{'SignatureQuantity'}) );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'txtPrice3', ($specs{'txtPrice3'}/$specs{'SignatureQuantity'}) );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'SignatureQuantity', 1 );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $new_service_index, 'txtSignatureQuantity', 1 );

# Update source service
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'SignatureQuantity', $specs{'SignatureQuantity'}-1 );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'txtSignatureQuantity', $specs{'txtSignatureQuantity'}-1 );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'txtPrice1', $specs{'txtPrice1'}*(($specs{'SignatureQuantity'}-1)/$specs{'SignatureQuantity'}) );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'txtPrice2', $specs{'txtPrice2'}*(($specs{'SignatureQuantity'}-1)/$specs{'SignatureQuantity'}) );
	openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, 'txtPrice3', $specs{'txtPrice3'}*(($specs{'SignatureQuantity'}-1)/$specs{'SignatureQuantity'}) );

	my $status = openprint::service::status( $project_index, $new_service_index, openprint::service::status( $project_index, $service_index ) );

	my @schedule = find( 'project_id'=>$project_index, 'service_id'=>$service_index );
	my $schedule = shift @schedule;
	if ( $$schedule{'starttime'} and $$schedule{'runtime'} ) {
		my ( $year, $month, $day, $hours, $minutes, $seconds ) = $$schedule{'starttime'} =~ /(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/;
		if ( $$schedule{'equipment_id'} == 28 ) {
			( $year, $month, $day, $hours, $minutes, $seconds ) = Date::Calc::Add_Delta_DHMS( ( $year, $month, $day, $hours, $minutes, $seconds, 0, split(':', $$schedule{'runtime'} ) ) );
		} else {
			( $year, $month, $day, $hours, $minutes, $seconds ) = Date::Calc::Add_Delta_DHMS( ( $year, $month, $day, $hours, $minutes, $seconds, 0, 0, 0, 1 ) );
		} # end if
		$$schedule{'starttime'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', ( $year, $month, $day, $hours, $minutes, $seconds ) );

		sql::insert( $log, $dbh, 'Schedule',
				'ProjectIndex', $project_index,
				'ServiceIndex', $new_service_index,
				'Equipment_id', $$schedule{'equipment_id'},
				'StartTime',    $$schedule{'starttime'},
				'RunTime',      $$schedule{'runtime'},
				);
	} # end if

	sql::end_transaction( $dbh, $ac );

	my $Shift = openprint::Shift::get_from_ul_id( $ul_id );
	return "Div~$ul_id~".$Shift->get_ul();
} # end sub split_job


sub add_project_to_press_schedule {
	my ( $Project, $service_id ) = @_;

	my $error = '';

	my $ac = sql::start_transaction( $dbh );

	my @sigs = $service_id ? ( $service_id ) : $Project->signatures();

	foreach my $s_s_id ( @sigs ) {
		next if find('project_id'=>$Project->id(), 'service_id'=>$s_s_id );

		my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		$$sig_specs{'UsePress'} = $$sig_specs{'ddmPress'.$Project->ordered_quantity_index()} if ! $$sig_specs{'UsePress'};
		if ( ! $$sig_specs{'UsePress'} ) {
			$error .= "No press for signature $$sig_specs{'SignatureIndex'}<br/>";
		} # end if
		my $runtime = openprint::service::get_runtime( $Project, $s_s_id );
		if ( my @Equipment = openprint::Equipment::find('strid'=>$$sig_specs{'UsePress'},'use_in_estimating'=>1) ) {
			$_ = sql::insert( undef, undef, 'Schedule', ['ProjectIndex', $Project->id(), 'ServiceIndex', $s_s_id, 'Equipment_id', $Equipment[0]->id(),'StartTime', undef, 'RunTime', ($runtime ? "$runtime minutes" : undef ) ] );
			if ( $_ ) {
				$error .= 'Error adding to press schedule: ' . $_;
			} else {
				$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Added Form $$sig_specs{'SignatureIndex'} to pending press schedule." );

			} # end if
		} else {
			$error .= "Error adding to press schedule: Press not found ($$sig_specs{UsePress}) for signature $$sig_specs{'SignatureIndex'}<br/>";
		} # end if
	} # end foreach
	sql::end_transaction( $dbh, $ac );
	return $error;
} # end sub add_project_to_press_schedule

1;
__END__
