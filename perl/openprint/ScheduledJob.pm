package openprint::ScheduledJob;
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

my $debug = 1;

$table = 'schedule';
$serial = 'schedule_id_seq';

%fields = (
	'id'			=>	'id',
	'starttime'		=>	'starttime',
	'runtime'		=>	'runtime',
	'project_id'	=>	'projectindex',
	'service_id'	=>	'service_id',
	'serviceindex'	=>	'serviceindex',
	'equipment_id'	=>	'equipment_id',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'project_id'	=>	[ 's/\D//g' ],
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
	if ( exists $params{'equipment_id'} ) {
		$sql .= ' AND equipment_id=?';
		push @values, $params{'equipment_id'};
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
		if ( ref $params{'service_id'} eq 'ARRAY' ) {
			$sql .= ' AND service_id={?}';
			push @values, $params{'service_id'};
		} else {
			$sql .= ' AND ? = ANY(service_id)';
			push @values, $params{'service_id'};
		} # end if
    } # end if

	if ( $params{'startdate'} ) {
		$sql .= ' AND date(starttime) = ?';
		push @values, $params{'startdate'};
	} 
	if ( $params{'starttime'} ) {
		$sql .= ' AND starttime = ?';
		push @values, $params{'starttime'};
	} 
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
    } elsif ( $params{'endtime_>'} ) {
        $sql .= ' AND endtime > ?';
        push @values, $params{'endtime_>'};
    } elsif ( exists $params{'endtime_start'} and ! $params{'endtime_start'} ) {
        $sql .= ' AND endtime IS NULL';
    } elsif ( exists $params{'endtime_end'} and ! $params{'endtime_end'} ) {
        $sql .= ' AND endtime IS NULL';
    } # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading ScheduledJobs SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No ScheduledJobs loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded ScheduledJobs ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::ScheduledJob( $_->{id}, $_ ) } @$data;
} # end sub find

sub runtime_seconds {
	return misc::hms2time( $_[0]->runtime() );
} # end sub runtime_seconds

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

sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

sub comment {
	my ( $self, $comment ) = @_;

    my $Project = new openprint::Project( $$self{'project_id'} );

	# We check for comments in the services, if we find one, we use it, otherwise we generate from the first.
	if ( $comment ) {
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'txtEmployeeComments', $comment );
		} # end foreach sig_id	
	} else {
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
			if ( $comment = $$sig_specs{'txtEmployeeComments'} ) {
				last;
			} # end if
		} # end foreach sig_id
	} # end if

	if ( ( ! $comment ) and $$self{'service_id'} ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $$self{'service_id'}[0] );
		my @side_one = openprint::Estimating::Printing::get_colours( $sig_specs, 'SideOne' );
		my @side_two = openprint::Estimating::Printing::get_colours( $sig_specs, 'SideTwo' );
		$comment = sprintf( '%d/%d', scalar @side_one, scalar @side_two );

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
			$comment .= '+' . ( keys %pms ) . ' PMS';
		} # end if

		if ( $$sig_specs{'rdbAqueousSideOne'} ne 'None' or $$sig_specs{'rdbAqueousSideTwo'} ne 'None' ) {
			$comment .= '+AQ';
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
			$comment .= '+Varnish';
		} # end if

		$comment .= ' on ' . $$sig_specs{'ddmStockSheetSize'.$Project->ordered_quantity_index()};

		my $Equipment = new openprint::Equipment($$self{'equipment_id'});
		if ( $Equipment->specification('Folding Capable') eq 'When Printing' ) {
			my $services = $Project->services();
			if ( $$services{'Folding'} ) {
				my $fold_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
				if ( $$fold_specs{'ddmEquipment-'.$$sig_specs{'SignatureIndex'}.'-'.$Project->ordered_quantity_index()} == $Equipment->id() ) {
					$comment .= '(fold inline)';
				} # end if
			} else {
				$comment .= '(sheeted)';
			} # end if
		} # end if
		# Store it.
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'txtEmployeeComments', $comment );
		} # end foreach sig_id	
	} # end if has service_ids

	return $comment;
} # end sub comment

sub get_li {
    my ( $self, $ul_id ) = @_;

    my $html;
    if ( ! $$self{'project_id'} ) {
        $html .= sprintf( '<li id="item_%d" class="%s">Reserved', $$self{'id'}, 'reserved' );
        $html .= '<span class="Buttons">';
        $html .= ssi::writeButton( $log, $dbh, 'Remove'.$$self{'id'}, '', "if(confirm('Are you sure?')){f1.schedule_id.value=$$self{'id'};f1.btnFunction.value='RemoveJob';f1.submit();}", '', 'D' );
        $html .= '</span>';
        $html .= sprintf( q{<span class="RunTime" onclick="openPopup( 'RunTime', %1$d );"><span id="%1$dRunTime">%2$.2d:%3$.2d</span></span>}, $$self{'id'}, split(':',$self->runtime()) );
        $html .= '<br/></li>';
        return $html;
    } # end if

    my $Project = new openprint::Project( $$self{'project_id'} );
    my $services = $Project->services();
    my $Equipment = new openprint::Equipment($$self{'equipment_id'});

	my $impressions = 0;
	my $forms = 0;
	foreach my $sig_id ( @{$$self{'service_id'}} ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		if ( ! $$sig_specs{'SignatureQuantity'} ) {
			$$sig_specs{'SignatureQuantity'} = $$sig_specs{'txtSignatureQuantity'} ? $$sig_specs{'txtSignatureQuantity'} : 1;
			openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'SignatureQuantity', $$sig_specs{'SignatureQuantity'} );
		} # end if
		if ( ! $$sig_specs{'ImpressionQuantity'} ) {
			$$sig_specs{'ImpressionQuantity'} = $$sig_specs{'hdnImpressionQuantity'.$Project->ordered_quantity_index()};
			openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'ImpressionQuantity', $$sig_specs{'ImpressionQuantity'} );
		} # end if
		$impressions += $$sig_specs{'ImpressionQuantity'};
		$forms += $$sig_specs{'SignatureQuantity'};
	} # end foreach sig

    my $colour = 'blue';
    if ( sets::isin( $Project->status(), ['In Prepress', 'Proofs Out','Waiting For QA Approval'] ) ) {
        $colour = 'green';
    } elsif ( sets::isin( $Project->status(), ['Printed', 'Complete','Waiting For Pickup', 'Picked Up', 'Shipped'] ) ) {
        $colour = 'pink';
    } elsif ( sets::isin( $Project->status(), ['Waiting For Customer Approval'] ) ) {
        $colour = 'red';
    } elsif ( 1 < sql::execute( $log, $dbh, q{SELECT DISTINCT equipment_id FROM Schedule WHERE projectindex=?}, $$self{'project_id'} ) ) {
        $colour = 'yellow';
    } # end if
    if ( $Project->rush() ) {
        $colour .= ' rush';
    } # end if
    $html .= sprintf( '<li id="item_%d" class="%s">', $$self{'id'}, $colour );
    $html .= '<div class="Company">';
    $html .= sprintf( '<a class="docket" href="/employee/project/view.html?ProjectIndex=%1$d&Docket=%2$d">%2$d</a>', $$self{'project_id'}, $Project->docket() );
	my $n = $Project->Company()->name();
	$n =~ s/The //gi;
	$html .= ssi::htmlize( $n );
	$html .= ' (<span class="CSR">'.$Project->Company()->CSR()->firstname().'</span>)';
	if ( $Project->operator_id() ) {
		$html .= ' (<span class="PrepressOperator">'.$Project->Operator()->firstname().'</span>)';
	} # end if
	$html .= '</div>';
	$html .= qq`<span class="DueDate" id="JumpToDate$$self{'id'}">`;
	if ( ! $Project->due_date() ) {
		$html .= 'no duedate</span>';
	} else {
		my ( $year, $month, $day ) = split('-', $Project->due_date() );
		if ( $month ) { $html .= '&nbsp;'.substr( Date::Calc::Month_to_Text( $month ),0, 3); } # end if
			$html .= qq` $day</span>`;
	} # end if

	if ( openprint::usergroup::is_user_in( ['Scheduling'], $session{'user_id'} ) ) {
		$html .= sprintf(q`<input type="hidden" name="ScheduleDate-%1$d" id="ScheduleDate-%1$d" value="%2$s"/>`, $$self{'id'}, $Project->due_date() );
        $html .= sprintf( q{<div id="%2$dComment" class="Comment" onclick="openPopup( 'Comment', '%1$d' );">%2$s</div>}, $$self{'id'}, $self->comment() );

        $html .= sprintf( q{<span class="Forms" id="%1$dForms" onclick="openPopup( 'Forms', '%1$d' );">%2$d %3$s</span>}, $$self{'id'}, $forms, ($forms > 1 ? ' forms' : ' form') );
        $html .= sprintf( q{<span id="%1$dImpressions" class="Impressions" onclick="openPopup( 'Impressions', %1$d );">%2$d imps</span>}, $$self{'id'}, $impressions );

        $html .= '<span class="Buttons">';
        $html .= ssi::writeButton( $log, $dbh, 'Approve'.$$self{'id'}, '', "if(confirm('Are you sure?')){f1.schedule_id.value=$$self{'id'};f1.btnFunction.value='ApproveJob';f1.submit();}", '', 'A' ) if sets::isin( $Project->status(), 'In Prepress', 'Proofs Out','Waiting For Customer Approval','Waiting For QA Approval' );
        $html .= ssi::writeButton( $log, $dbh, 'Bump'.$$self{'id'}, '', "popup_window('_bump_job.html','id=$$self{id}');", '', 'B' );
        $html .= ssi::writeButton( $log, $dbh, 'Complete'.$$self{'id'}, '', "popup_window('_signature_completion_popup.html', 'schedule_id=$$self{'id'}' );", '', 'C' );
        $html .= ssi::writeButton( $log, $dbh, 'Remove'.$$self{'id'}, '', "if(confirm('Are you sure?')){new Ajax.Request('_li_change.json', {parameters: {schedule_id:$$self{'id'}, action: 'RemoveJob'}, evalScripts: true } )};", '', 'D' );
        #$html .= ssi::writeButton( $log, $dbh, 'Split'.$$self{'id'}, '', "if(confirm('Are you sure?')){split_job($$self{'project_id'}, $$self{'serviceindex'}, '$ul_id' );}", '', 'S' ) if $$sig_specs{'SignatureQuantity'} > 1;
        $html .= ssi::writeButton( $log, $dbh, 'Stock'.$$self{'id'}, '', "popup_window('_stock_details.html','project_id='+$$self{'project_id'} );", '', 'P' );
        $html .= '</span>';
		if ( $Equipment->smartscheduling() ) {
			$html .= sprintf( q`<span class="StartTime" onclick="popup_window( '_starttime_popup.html?id=%1$d' );">Start:<span id=%1$dStartTime">%2$s</span><img src="/images/small-%3$s.gif" alt="%3$s"/></span>`, $$self{'id'},
					Date::Format::time2str( '%H:%M', Date::Parse::str2time( $$self{'starttime'} ) ),
					$$self{'starttime_locked'} ? 'locked' : 'unlocked',
					);
		} # end if

		$html .= sprintf( q{<span id="%1$dRunTime" class="RunTime" onclick="popup_window( '_starttime_popup.html,'id=%1$d' );">%2$.2d:%3$.2d</span>}, $$self{'id'}, split(':',$self->runtime()) );
		if ( $Equipment->smartscheduling() ) {
			$html .= '<span class="Services">';
			$html .= '<span class="Service">fold</span>' if $$services{'Folding'};
			$html .= '<span class="Service">stitch</span>' if $$services{'SaddleStitching'} or $$services{'LoopStitching'};
			$html .= '<span class="Service">trim</span>' if $$services{'Cutting'};
			$html .= '</span>';
		}
	} else {
		$html .= sprintf( '<div class="Comment">%3$s</div>', ssi::htmlize( $self->comment() ) );
		$html .= sprintf( '<span class="Forms">%d %s</span>', $forms, $forms > 1 ? ' forms' : ' form' );
		$html .= sprintf( '<span class="Impressions">%d imps</span>', $impressions );
		$html .= '<span class="Buttons">';
		$html .= ssi::writeButton( $log, $dbh, 'Paper'.$$self{'id'}, '', "popup_window('_stock_details.html','project_id=$$self{'project_id'}' );", '', 'P' );
		$html .= '</span>';
        $html .= sprintf( q`<span class="StartTime">Start:%2$s</span>`, $$self{'id'},
                Date::Format::time2str( '%H:%M', Date::Parse::str2time( $$self{'starttime'} ) ),
                );
        $html .= sprintf( q{<span class="RunTime">%2$.2d:%3$.2d</span>}, $$self{'id'}, split(':',$self->runtime()) );
		if ( $Equipment->smartscheduling() ) {
			$html .= '<span class="Services">';
			$html .= '<span class="Service">fold</span>' if $$services{'Folding'};
			$html .= '<span class="Service">stitch</span>' if $$services{'SaddleStitching'} or $$services{'LoopStitching'};
			$html .= '<span class="Service">trim</span>' if $$services{'Cutting'};
			$html .= '</span>';
		} # end if smart
	} # end if
	$html .= "<br/></li>\n";
	return $html;
} # end sub get_li

sub operator_id {
	my ( $self, $operator_id ) = @_;

	if ( defined $operator_id ) {
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			sql::update( $log, $dbh, 'tbl_Project_Contents',  ['lngProjectIndex=? AND lngServiceIndex=?', $$self{'project_id'}, $sig_id], 'operator_id', $operator_id ? $operator_id : undef );
		} # end foreach
	} # end if
} # end sub operator_id

sub impressions {
	my $self = shift;

	my $Project = $self->Project();
	
	my $impressions = 0;
	foreach my $sig_id ( @{$$self{'service_id'}} ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		if ( ! $$sig_specs{'ImpressionQuantity'} ) {
			$$sig_specs{'ImpressionQuantity'} = $$sig_specs{'hdnImpressionQuantity'.$Project->ordered_quantity_index()};
			openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'ImpressionQuantity', $$sig_specs{'ImpressionQuantity'} );
		} # end if
		$impressions += $$sig_specs{'ImpressionQuantity'};
	} # end foreach sig
	return $impressions;
} # end sub impressions

sub Project {
	return new openprint::Project( $_[0]{'project_id'} );
} # end sub Project

sub runtime {
	my ( $self ) = @_;

	my $minutes = 0;
	if ( ! $$self{'runtime'} ) {
		my $Project = $self->Project();
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			$minutes += openprint::service::get_runtime( $Project, $sig_id );
		} # end foreach
		$$self{'runtime'} = Date::Format::time2str( '%H:%M:%S', 60*$minutes );
	} # end if
	return $$self{'runtime'};
} # end sub runtime

1;
#__END__
