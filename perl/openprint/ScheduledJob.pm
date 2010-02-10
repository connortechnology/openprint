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
	'equipment_id'	=>	'equipment_id',
	'locked'		=>	'starttime_locked',
	'speed'			=>	'speed',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'project_id'	=>	[ 's/\D//g' ],
	'speed'			=>	[ 's/\D//g' ],
	#'runtime'		=>	[ 's/[^\d:]//g' ],
);

%defaults = (
	'speed'			=>	undef,
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
	my $self = shift;
	if ( @_ ) {
		$$self{'runtime'} = misc::seconds2hms($_[0]);
	} # end if
	
	return misc::hms2time( $$self{'runtime'} );
} # end sub runtime_seconds

sub starttime_seconds {
	my $self = shift;
	if ( @_ ) {
		$$self{'starttime'} = Date::Format::time2str( '%Y-%m-%d %H:%M:%S', $_[0] );
	} # end if
	return Date::Parse::str2time( $$self{'starttime'} );
} # endsub

sub startdate_seconds {
	my ( $self ) = @_;
	my $time = $self->starttime_seconds();
	return Date::Parse::str2time( Date::Format::time2str( '%Y-%m-%d', $time ) );
} # end sub startdate_seconds

sub endtime {
	if ( ! $_[0]{'endtime'} ) {
		$_[0]{'endtime'} = Date::Format::time2str( '%Y-%m-%d %H:%M:%S', $_[0]->starttime_seconds() + $_[0]->duration_seconds() );
	} # end if
$log->debug("ENdtime: " . $_[0]{'endtime'} );
	return $_[0]{'endtime'};
} # end sub endtime_seconds
sub endtime_seconds {
	return $_[0]->starttime_seconds() + $_[0]->runtime_seconds();
} # endsub

sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

sub comment {
	my ( $self, $comment ) = @_;

	my $Project = new openprint::Project( $$self{'project_id'} );

	# We check for comments in the services, if we find one, we use it, otherwise we generate from the first.
	if ( @_ > 1 ) {
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

	if ( ( ! $comment ) and $$self{'service_id'} and @{$$self{'service_id'}} ) {
	#if ( $$self{'service_id'} and @{$$self{'service_id'}} ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $$self{'service_id'}[0] );

		$comment = openprint::Estimating::Printing::get_colour_description( $sig_specs );
		#$comment .= ' on ' . $$sig_specs{'ddmStockSheetSize'.$Project->ordered_quantity_index()};
		my $Stock;
		if ( my @PA = openprint::PaperAllocation::find('project_id'=>$Project->id()) ) {
			$Stock = $PA[0]->Paper();
		} else {
			$Stock = openprint::Paper::load_from_signature( $Project, $sig_specs, $Project->ordered_quantity_index() );
		} # end if
		$comment .= ' on ' . $Stock->to_string();

		my $Equipment = new openprint::Equipment($$self{'equipment_id'});
		if ( $Equipment->specification('Folding Capable') eq 'When Printing' ) {
			my $services = $Project->services();
			if ( $$services{'Folding'} ) {
				my $fold_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
				if ( $$fold_specs{'ddmEquipment-'.$$sig_specs{'SignatureIndex'}.'-'.$Project->ordered_quantity_index()} == $Equipment->id() ) {
					my $Imposition = new openprint::Imposition();
					$Imposition->load( $sig_specs, $Project->ordered_quantity_index() );
					my $foldtype = sprintf('%sx%s-%dPage-%sFold', $Imposition->get('spread_columns','spread_rows','pages','image_orientation' ) );
					$comment .= "($foldtype inline)";
				} else {
					$comment .= '(sheeted)';
				} # end if
			} # end if
		} else {
			#$comment .= 'This press does not fold';
		} # end if
		# Store it.
		#foreach my $sig_id ( @{$$self{'service_id'}} ) {
			#openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'txtEmployeeComments', $comment );
		#} # end foreach sig_id	
	} # end if has service_ids

	return $comment;
} # end sub comment

sub get_li {
	my ( $self, $ul_id ) = @_;

# a 12hour shift ~= 600px, so each hour gets 50px;
	my $scale = $session{'/employee/production/print_overview.html?scale'};
	my @Presses = split(';', $session{'/employee/production/print_overview.html?Presses'} );
	my $min_height = 50 + ( 10 * ( @Presses ? @Presses : 1 ) );
	my $height;
	if ( ! $scale ) {
		$height = $min_height;
	} else {
		$height = $self->starttime() ? $scale * int($self->runtime_seconds()/3600) : $min_height;
		$height = $min_height if $height < $min_height;
	} # end if

	my $html;
	if ( ! $$self{'project_id'} ) {
		$html .= sprintf( '<li id="item_%d" class="%s">Reserved', $$self{'id'}, 'reserved' );
		$html .= '<span class="Buttons">';
		$html .= ssi::writeButton( $log, $dbh, 'Remove'.$$self{'id'}, '', "if(confirm('Are you sure?')){f1.schedule_id.value=$$self{'id'};f1.btnFunction.value='RemoveJob';f1.submit();}", '', 'D' );
		$html .= '</span>';
		$html .= sprintf( q{<span class="RunTime" onclick="openPopup( 'RunTime', %1$d );"><span id="%1$dRunTime">%2$.2d:%3$.2d</span></span>}, $$self{'id'}, split(':',$self->runtime()) );
		$html .= '</li>';
		return $html;
	} # end if

	my $Project = new openprint::Project( $$self{'project_id'} );
	my $services = $Project->services();
	my $Equipment = new openprint::Equipment($$self{'equipment_id'});

	my $impressions = 0;
	#my $forms = 0;
	foreach my $sig_id ( @{$$self{'service_id'}} ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		#if ( ! $$sig_specs{'SignatureQuantity'} ) {
			#$$sig_specs{'SignatureQuantity'} = 1;
			#openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'SignatureQuantity', $$sig_specs{'SignatureQuantity'} );
		#} # end if
		if ( ! $$sig_specs{'ImpressionQuantity'} ) {
			$$sig_specs{'ImpressionQuantity'} = $$sig_specs{'hdnImpressionQuantity'.$Project->ordered_quantity_index()};
			openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'ImpressionQuantity', $$sig_specs{'ImpressionQuantity'} );
		} # end if
		$impressions += $$sig_specs{'ImpressionQuantity'};
		#$forms += $$sig_specs{'SignatureQuantity'};
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
	$html .= sprintf( '<li id="item_%d" class="%s" style="height:%spx;">', $$self{'id'}, $colour, $height );
	$html .= '<div class="Company">';
	$html .= sprintf( '<a class="docket" href="/employee/project/view.html?ProjectIndex=%1$d&amp;Docket=%2$d">%2$d</a>', $$self{'project_id'}, $Project->docket() );
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
		$html .= sprintf( q`<div class="Comment" onclick="popup_window( '_job_popup.html', 'schedule_id=%1$d', {width:475} );">%2$s</div>`, $$self{'id'}, $self->comment() );

		$html .= sprintf( q`<span id="%1$dForms" class="Forms" onclick="popup_window( '_job_popup.html', 'schedule_id=%1$d', {width:475} );">%2$d %3$s</span>`, $$self{'id'}, $self->forms(), 'form'.($self->forms() > 1 ? 's' : '') );
		$html .= sprintf( q`<span class="Impressions" onclick="popup_window( '_job_popup.html', 'schedule_id=%1$d', {width:475} );">%2$d imps @ %3$d/Hr</span>`, $$self{'id'}, $impressions, $self->speed() );
		if ( $Equipment->smartscheduling() or $$self{'locked'} ) {
			$html .= sprintf( q`<span class="StartTime" onclick="popup_window( '_job_popup.html', 'schedule_id=%1$d', {width:475} );">Start: %2$s<img src="/images/small-%3$s.gif" alt="%3$s"/></span>`, $$self{'id'},
					Date::Format::time2str( '%H:%M', Date::Parse::str2time( $$self{'starttime'} ) ),
					$$self{'locked'} ? 'locked' : 'unlocked',
					);
		} # end if

		$html .= sprintf( q`<span class="RunTime" onclick="popup_window( '_job_popup.html','schedule_id=%1$d', {width:475} );">%2$.2d:%3$.2d</span>`, $$self{'id'}, split(':',$self->runtime()) );

		$html .= '<span class="Buttons">';
		$html .= ssi::writeButton( $log, $dbh, 'Approve'.$$self{'id'}, '', "if(confirm('Are you sure?')){f1.schedule_id.value=$$self{'id'};f1.btnFunction.value='ApproveJob';f1.submit();}", '', 'A' ) if sets::isin( $Project->status(), 'In Prepress', 'Proofs Out','Waiting For Customer Approval','Waiting For QA Approval' );
		$html .= ssi::writeButton( $log, $dbh, 'Bump'.$$self{'id'}, '', "popup_window('_bump_job.html','schedule_id=$$self{id}');", '', 'B' );
		$html .= ssi::writeButton( $log, $dbh, 'Complete'.$$self{'id'}, '', "popup_window('_signature_completion_popup.html', 'schedule_id=$$self{'id'}' );", '', 'C' );
		$html .= ssi::writeButton( $log, $dbh, 'Remove'.$$self{'id'}, '', "if(confirm('Are you sure?')){new Ajax.Request('_li_change.json', {parameters: {schedule_id:$$self{'id'}, action: 'RemoveJob'}, evalScripts: true } )};", '', 'D' );
		$html .= ssi::writeButton( $log, $dbh, 'Split'.$$self{'id'}, '', "new Ajax.Updater( '$ul_id', '_ul.html', { parameters: { id: '$ul_id', schedule_id: $$self{'id'}, action:'split'}, evalScripts: true } );", '', 'S' ) if @{$$self{'service_id'}} > 1;
		$html .= ssi::writeButton( $log, $dbh, 'Stock'.$$self{'id'}, '', "popup_window('_stock_details.html','project_id='+$$self{'project_id'} );", '', 'P' );
		if ( $self->status() ne 'In Production' ) {
		$html .= ssi::writeButton( $log, $dbh, 'Start'.$$self{'id'}, '', "new Ajax.Request('_li_change.json', { parameters: { schedule_id: $$self{id}, action: 'start' } } );", '', 'Start' );
		} else {
		$html .= ssi::writeButton( $log, $dbh, 'Stop'.$$self{'id'}, '', "new Ajax.Request('_li_change.json', { parameters: { schedule_id: $$self{id}, action: 'stop' } } );", '', 'Stop' );
		} # end if
		$html .= '</span>';
		if ( $Equipment->smartscheduling() ) {
			$html .= '<span class="Services">';
			$html .= '<span class="Service">fold</span>' if $$services{'Folding'};
			$html .= '<span class="Service">stitch</span>' if $$services{'SaddleStitching'} or $$services{'LoopStitching'};
			$html .= '<span class="Service">trim</span>' if $$services{'Cutting'};
			$html .= '<span class="Service">nobindery</span>' if $$services{'NoBindery'};
			$html .= '</span>';
		}
	} else {
		$html .= sprintf( '<div class="Comment">%3$s</div>', ssi::htmlize( $self->comment() ) );
		$html .= sprintf( '<span class="Forms">%d %s</span>', $self->forms(), $self->forms() > 1 ? ' forms' : ' form' );
		$html .= sprintf( '<span class="Impressions">%d imps</span>', $impressions );
		$html .= sprintf( q`<span class="StartTime">Start:%2$s</span>`, $$self{'id'},
				Date::Format::time2str( '%H:%M', Date::Parse::str2time( $$self{'starttime'} ) ),
				);
		$html .= sprintf( q{<span class="RunTime">%2$.2d:%3$.2d</span>}, $$self{'id'}, split(':',$self->runtime()) );
		$html .= '<span class="Buttons">';
		$html .= ssi::writeButton( $log, $dbh, 'Paper'.$$self{'id'}, '', "popup_window('_stock_details.html','project_id=$$self{'project_id'}' );", '', 'P' );
		if ( $$self{'operator_id'} == $session{'user_id'} ) {
			$html .= ssi::writeButton( $log, $dbh, 'Start'.$$self{'id'}, '', "new Ajax.Request('_li_change.json', { parameters: { id: $$self{id}, action: 'start' } } );", '', 'Start' );
		} # end if
		$html .= '</span>';
		if ( $Equipment->smartscheduling() ) {
			$html .= '<span class="Services">';
			$html .= '<span class="Service">fold</span>' if $$services{'Folding'};
			$html .= '<span class="Service">stitch</span>' if $$services{'SaddleStitching'} or $$services{'LoopStitching'};
			$html .= '<span class="Service">trim</span>' if $$services{'Cutting'};
			$html .= '<span class="Service">nobindery</span>' if $$services{'NoBindery'};
			$html .= '</span>';
		} # end if smart
	} # end if
	$html .= "</li>\n";
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

	if ( @_ ) {
		$impressions = shift;
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'ImpressionQuantity', int($impressions/@{$$self{'service_id'}}) );
		} # end foreach sig
	} else {
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
			if ( ! $$sig_specs{'ImpressionQuantity'} ) {
				$$sig_specs{'ImpressionQuantity'} = $$sig_specs{'hdnImpressionQuantity'.$Project->ordered_quantity_index()};
				openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'ImpressionQuantity', $$sig_specs{'ImpressionQuantity'} );
			} # end if
			$impressions += $$sig_specs{'ImpressionQuantity'};
		} # end foreach sig
	} # end if
	return $impressions;
} # end sub impressions

sub Project {
	return new openprint::Project( $_[0]{'project_id'} );
} # end sub Project

sub runtime {
	my ( $self ) = @_;

	my $seconds = 0;
	if ( ! $$self{'runtime'} ) {
		my $Project = $self->Project();
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			$seconds += openprint::service::get_runtime( $Project, $sig_id, $self->Equipment(), $self->impressions()/@{$$self{'service_id'}}, $self->speed() );
		} # end foreach
		$$self{'runtime'} = misc::seconds2hms( $seconds );
$log->debug("ScheduledJob::runtime seconds: $seconds => " . $$self{'runtime'} );
	} # end if
	return $$self{'runtime'};
} # end sub runtime

sub forms {
	my ( $self ) = @_;
	my $forms = 0;
	foreach my $sig_id ( @{$$self{'service_id'}} ) {
		my $sig_specs = openprint::service::get_specs_ref( $self->Project(), $sig_id );
		if ( $$sig_specs{'SignatureQuantity'} ) {
			$forms += $$sig_specs{'SignatureQuantity'};
		} # end if
	} # end foreach
	$forms = @{$$self{'service_id'}} if $$self{'service_id'} and ! $forms;

	return $forms;
} # end sub forms

sub Shift {
	my ( $self ) = @_;
	my $Shift;

	if ( ! $$self{'starttime'} ) {
		$Shift = new openprint::Shift();
		$Shift->equipment_id( $$self{'equipment_id'} );
		if ( sets::isin( $self->Project()->status(), ['In Prepress','Proofs Out','Waiting For QA Approval','Waiting For Customer Approval','Printed','Complete'] ) ) {
			$$Shift{'name'} = 'Pending';
		} else {
			$$Shift{'name'} = 'Approved';
		} # end if
	} else {
		my $starttime_seconds = Date::Parse::str2time( $$self{'starttime'} );
		my @Shifts = openprint::Shift::find(
				'equipment_id'=>$$self{'equipment_id'}, 
				'endtime_>'=>$$self{'starttime'}, 
				'starttime_<='=>$$self{'starttime'},'limit'=>1
				);
		if ( ! @Shifts ) {
			@Shifts = openprint::Equipment_Shift::find(
					'equipment_id'  =>  $$self{'equipment_id'},
					'starttime_<='  =>  Date::Format::time2str('%H:%M',$starttime_seconds ),
					'endtime_>'	 =>  Date::Format::time2str('%H:%M',$starttime_seconds ),
					'limit'		 =>  1,
					);
			@Shifts = openprint::Equipment_Shift::find(
					'equipment_id'  =>  $$self{'equipment_id'},
					'starttime_>'   =>  Date::Format::time2str('%H:%M',$starttime_seconds ),
					'order'		 =>  'starttime',
					'limit'		 =>  1,
					) if ! @Shifts;
			$Shift = $Shifts[0]->emanantise( Date::Parse::str2time( Date::Format::time2str('%Y-%m-%d', $starttime_seconds ) ) ) if @Shifts;
		} else {
			$Shift = shift @Shifts;
			if ( @Shifts ) {
				$log->warn("Deleting duplicate shifts! " . @Shifts );
				foreach ( @Shifts ) {
					$_->delete();
				} # end foreach
			} # end if
		} # end if
	} # end if
	return if ! $Shift;
	return $Shift;
} # end sub Shift

sub start {
	my ( $self ) = @_;
	my $e = $self->save({'starttime_seconds'=>time,'locked'=>1});
	if ( ! $e ) {
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			openprint::service::status( $$self{'project_id'}, $sig_id, 'In Production' );
		} # end foreach sig_id
	} # end if
	return $e;
} # end sub start

sub stop {
	my ( $self ) = @_;
$log->debug("Stopping job: starttime $$self{'starttime'} seconds: " . $self->starttime_seconds() . " now: " . time . " elapsed: " . ( time - $self->starttime_seconds() ) );
	my $new_runtime = $self->runtime_seconds() - ( time - $self->starttime_seconds() );
	$new_runtime = 300 if $new_runtime < 0; # default to 5minutes
	my $e = $self->save({'runtime_seconds'=>$new_runtime,'locked'=>0});
	if ( ! $e ) {
		foreach my $sig_id ( @{$$self{'service_id'}} ) {
			openprint::service::status( $$self{'project_id'}, $sig_id, 'Ordered' );
		} # end foreach sig_id
	} # end if
	return $e;
} # end sub stop

sub status {
	my ( $self ) = @_;
	foreach my $sig_id ( @{$$self{'service_id'}} ) {
		return openprint::service::status( $$self{'project_id'}, $sig_id );
	} # end foreach sig_id
} # end sub status

sub bump {
	my ( $self, $equipment_id ) = @_;
	push @{$variable{'changed'}}, $self->Shift()->ul_id();
	my $Project = $self->Project();
	$Project->save({'due_date'=>$Project->get_due_date()}) if ! $Project->due_date();

	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE Schedule IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
	$dbh->do( 'LOCK TABLE Shifts IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );

	if ( $equipment_id and ( $equipment_id != $$self{'equipment_id'} ) ) {
		my $old_equipment_id = $$self{'equipment_id'};
		$self->save({'equipment_id'=>$equipment_id});
		# Shuffle the old list
		if ( $old_equipment_id and new openprint::Equipment( $old_equipment_id )->smartscheduling() ) {
		openprint::employee_production::reorder_jobs(openprint::ScheduledJob::find( 'equipment_id'=>$old_equipment_id,'starttime_null'=>0,'order'=>'starttime' ))
		} # end if
	} # end if

	my $error;
	if ( ! $$self{'starttime'} ) {
		@$self{'starttime'} = sql::execute( $log, $dbh, q{SELECT MAX(starttime+runtime+'1 second'::interval) FROM Schedule WHERE equipment_id=? AND id != ?}, @$self{'equipment_id','id'} );
		my $starttime_seconds = $self->starttime_seconds();
		$starttime_seconds = time if $starttime_seconds < time;

		$error .= $self->save({'starttime_seconds'=>$starttime_seconds});
		push @{$variable{'changed'}}, $self->Shift()->ul_id();
	} elsif ( $self->Equipment()->smartscheduling() ) {
		my @final_order = openprint::ScheduledJob::find( 'equipment_id'=>$self->equipment_id(),'starttime_<'=>$self->starttime(),'order'=>'starttime' );
		foreach my $Job ( $self->Shift()->Schedule() ) {
			push @final_order, $Job if $$Job{'id'} != $$self{'id'};
		} # end foreach job in schift
		push @final_order, $self->Shift()->Next()->Schedule();
		push @final_order, $self;
		push @final_order, openprint::ScheduledJob::find( 'equipment_id'=>$self->equipment_id(),'starttime_start'=>$self->Shift()->Next()->endtime(),'order'=>'starttime' );

		openprint::employee_production::reorder_jobs( @final_order );
	} else {
		my $NextShift = $self->Shift()->Next();
		my @NextSchedule = $NextShift->Schedule();
		if ( @NextSchedule ) {
			my $LastJob = pop @NextSchedule;
			$self->starttime_seconds($LastJob->endtime_seconds()+1);
			$self->save();
		} else {
			$self->save({'starttime'=>$NextShift->starttime()});
		} # end if
		push @{$variable{'changed'}}, $self->Shift()->ul_id();
	} # end if smartscheduling
	sql::end_transaction( $dbh, $ac );
	$Project->add_to_log( @session{'company_id','user_id'}, 'Job bumped to next shift: '.Date::Format::time2str($config{'DateTimeFormat'}, $self->starttime_seconds() ) . ' on ' . $self->Equipment()->name() );
	return $error;
} # end sub bump

sub speed {
	my $self = shift;
	if ( @_ ) {
		$$self{'speed'} = $_[0];
	} # end if
	if ( ( ! $$self{'speed'} ) and $$self{'project_id'} ) {
		my $Project = $self->Project();
		if ( $Project->ordered_quantity_index() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $$self{'service_id'}[0] ) if $$self{'service_id'} and @{$$self{'service_id'}};
			
			$$self{'speed'} = openprint::Estimating::Printing::runspeed( $Project, $sig_specs, $Project->ordered_quantity_index(), $self->Equipment() ) if $sig_specs;
		} # end if
	} # en dif
	return $$self{'speed'};
} # end sub runspeed

1;
__END__
