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
require openprint::PaperAllocation;
require openprint::Shift;

my $debug = 1;

$table = 'schedule';
$serial = 'schedule_id_seq';

%fields = (
	'id'			=>	'id',
	'starttime'		=>	'starttime',
	'runtime'		=>	'runtime',
	'project_id'	=>	'projectindex',
	'service_id'	=>	'service_id',
	'pertains_id'	=>	'pertains_id',
	'equipment_id'	=>	'equipment_id',
	'locked'		=>	'starttime_locked',
	'speed'			=>	'speed',
	'comment'		=>	'comment',
	'runtime_seconds'	=>	undef,
	'starttime_seconds'	=>	undef,
	'impressions'		=>	undef,
	'created_on'		=>	'created_on',
	'operator_id'		=>	undef,
	'stock_verified'	=>	'stock_verified',
	'stock'				=>	'stock',
	'servicetype_id'	=>	'servicetype_id',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'project_id'	=>	[ 's/\D//g' ],
	'speed'			=>	[ 's/\D//g' ],
	#'runtime'		=>	[ 's/[^\d:]//g' ],
);

%defaults = (
	'speed'			=>	undef,
	'created_on'	=>	undef,
	'stock_verified'	=>	0,
);
sub find_one {
	my %params = @_;
	$params{'limit'}=1;
	my @Results = find(%params);
	return $Results[0] if @Results;
	return;
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
	if ( $params{'servicetype_id'} ) {
		if ( ref $params{'servicetype_id'} eq 'ARRAY' ) {
			$sql .= ' AND servicetype_id IN ('. join(',', map {'?'} @{$params{'servicetype_id'}} ) . ')';
			push @values, @{$params{'servicetype_id'}};
		} else {
			$sql .= ' AND servicetype_id=?';
			push @values, $params{'servicetype_id'};
		} # end if
	} # end if
	if ( $params{'servicetype'} ) {
		$sql .= ' AND servicetype_id=(SELECT id FROM service_types WHERE name=?)';
		push @values, $params{'servicetype'};
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
	if ( $params{'pertains_id'} ) {
		if ( ref $params{'pertains_id'} eq 'ARRAY' ) {
			$sql .= ' AND pertains_id={?}';
			push @values, $params{'pertains_id'};
		} else {
			$sql .= ' AND ? = ANY(pertains_id)';
			push @values, $params{'pertains_id'};
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
	
	return misc::hms2time( $self->runtime() );
} # end sub runtime_seconds

sub starttime_seconds {
	my $self = shift;
	if ( @_ ) {
		if ( $_[0] < ( time -10 ) ) {
			$log->error( 'ScheduledJob: startime_seconds < NOW() ' . Date::Format::time2str( '%Y-%m-%d %H:%M:%S', $_[0] ) );
		} # end if
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
		$_[0]{'endtime'} = Date::Format::time2str( '%Y-%m-%d %H:%M:%S%z', $_[0]->starttime_seconds() + $_[0]->duration_seconds() );
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

	# We check for comments in the services, if we find one, we use it, otherwise we generate from the first.
	if ( @_ > 1 ) {
		$$self{'comment'} = $comment;
		if ( $$self{'project_id'} ) {
			foreach my $service_id ( @{$$self{'service_id'}} ) {
				openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $service_id, 'txtEmployeeComments', $comment );
			} # end foreach sig_id	
		} # end if
	} else {
		if ( $$self{'project_id'} ) {
			my $Project = new openprint::Project( $$self{'project_id'} );
			foreach my $service_id ( @{$$self{'service_id'}} ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $service_id );
				if ( $comment = $$sig_specs{'txtEmployeeComments'} ) {
					last;
				} # end if
			} # end foreach sig_id
		} # end if
	} # end if

	if ( ( ! $$self{'comment'} ) and $$self{'project_id'} and $$self{'service_id'} and @{$$self{'service_id'}} ) {
		my $Project = new openprint::Project( $$self{'project_id'} );
	#if ( $$self{'service_id'} and @{$$self{'service_id'}} ) {
		if ( $self->ServiceType()->name() eq 'Folding' ) {
			my $qty_index = $Project->ordered_quantity_index();

			foreach my $service_index ( @{$$self{'service_id'}} ) {
				my $Service = $Project->Service( $service_index );
				my $specs = $Service->specs();

				foreach my $sig_id ( @{$self->pertains_id()} ) {
					my $SignatureService = $Project->Service( $sig_id );
					my $sig_specs = $SignatureService->specs();

					foreach my $fold_type ( keys %openprint::Estimating::Folding::fold_types ) {

						if ( $$specs{"$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} ) {
							$comment .= $$specs{"$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} . ' ' . $fold_type . '<br/>';
						} # end if
					} # end foreach
				} # end foreach sig_id
				$comment = 'unknown fold' if ! $comment;
			} # end foreach service_index

		} elsif ( $self->ServiceType()->name() eq 'Cutting' ) {
		} elsif ( $self->ServiceType()->name() eq 'SaddleStitching' ) {
		} else {
			my $service_specs = openprint::service::get_specs_ref( $Project, $$self{'service_id'}[0] );
			$comment = openprint::Estimating::Printing::get_colour_description( $service_specs );
			my $Equipment = $self->Equipment();

			if ( $Equipment->specification('Folding Capable') eq 'When Printing' ) {
				my $services = $Project->services();
				if ( $$services{'Folding'} ) {
					my $fold_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
					if ( $$fold_specs{'ddmEquipment-'.$$service_specs{'SignatureIndex'}.'-'.$Project->ordered_quantity_index()} == $Equipment->id() ) {
						my $Imposition = new openprint::Imposition();
						$Imposition->load( $service_specs, $Project->ordered_quantity_index() );
						my $foldtype = sprintf('%sx%s-%dPage-%sFold', $Imposition->get('spread_columns','spread_rows','pages','image_orientation' ) );
						$comment .= "($foldtype inline)";
					} else {
						$comment .= '(sheeted)';
					} # end if
				} # end if
			} # end if
		} # end if
		return $comment;
	} # end if has service_ids

	return $$self{'comment'};
} # end sub comment

sub stock {
	my ( $self, $stock ) = @_;
	if ( @_ == 2 ) {
		$$self{'stock'} = $stock;
	} # end if
	if ( ( ! $$self{'stock'} ) and $$self{'project_id'} and ( $self->ServiceType()->name() eq 'AdditionalSignature' ) ) {
		$$self{'stock'} = 'Stock: ';
		my $Equipment = $self->Equipment();
		my $Project = new openprint::Project( $$self{'project_id'} );
		my $Stock;
		my @PA = openprint::PaperAllocation::find('project_id'=>$$self{'project_id'});
		if ( @PA ) {
			$Stock = $PA[0]->Paper();
		} else {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $$self{'service_id'}[0] );
			$Stock = openprint::Paper::load_from_signature( $Project, $sig_specs, $Project->ordered_quantity_index() ) if ! $Stock;
		} # end if
		if ( $Equipment->smartscheduling() ) {
			if ( $Stock ) {
				$$self{'stock'} .= join(' ', ( $Stock->name(), $Stock->finish(), $Stock->colour(), $Stock->weight(), $Stock->type() eq 'Roll' ? $Stock->width.'&quot; Roll' : $Stock->width().'x'.$Stock->height() ) );
				$$self{'stock'} .= ' FSC:' . $$Stock{'fsc_code'} if $$Stock{'fsc_code'};
			} else {
				$$self{'stock'} .= ' not allocated.';
			} # end if
			if ( ( ! @PA ) and $Project->docket() and ( my @PO = openprint::PurchaseOrder_Content::find('docket'=>$Project->docket()) ) ) {
				$$self{'stock'} .= ' Ordered on PO: ' . join(',', map { sprintf('<a href="/employee/inventory/purchase_order_view.html?po_id=%1$d">%1$d</a>' , $_->po_id() ); } @PO );
			} else {
				$$self{'stock'} .= ' not ordered.';
			} # end if
		} else {
			if ( $Stock->type() eq 'Roll' ) {
				$$self{'stock'} .= $Stock->width().'&quot; Roll';
			} else {
				$$self{'stock'} .= $Stock->width() . 'x' . $Stock->height();
			} # end if
		} # end if
	} # end if
	return $$self{'stock'};
} # end sub stock

sub get_li {
	my ( $self, $ul_id ) = @_;

# a 12hour shift ~= 600px, so each hour gets 50px;
	my $scale = $session{'/employee/production/print_overview.html?scale'};
	my @Presses = split(';', $session{'/employee/production/print_overview.html?Presses'} );
	my $min_height = 50 + ( 10 * ( @Presses ? @Presses : 1 ) );
	my $height;
	if ( ! $scale ) {
		#$height = $min_height;
	} else {
		$height = $self->starttime() ? $scale * int($self->runtime_seconds()/3600) : $min_height;
		$height = $min_height if $height < $min_height;
	} # end if

	my $html;

	my $Project = $self->Project();
	my $services = $Project->services();
	my $Equipment = $self->Equipment();

	my $colour = '';

	if ( $$self{'project_id'} ) {
		if ( sets::isin( $Project->status(), ['In Prepress', 'Proofs Out','Waiting For QA Approval'] ) ) {
			$colour = 'inprepress';
		} elsif ( sets::isin( $Project->status(), ['Printed', 'Complete','Waiting For Pickup', 'Picked Up', 'Shipped'] ) ) {
			$colour = 'complete';
		} elsif ( sets::isin( $Project->status(), ['Waiting For Customer Approval'] ) ) {
			$colour = 'approval';
		} elsif ( 1 < sql::execute( $log, $dbh, q{SELECT DISTINCT equipment_id FROM Schedule WHERE projectindex=? AND servicetype_id=?}, @$self{'project_id','servicetype_id'} ) ) {
			$colour = 'multipress';
		} # end if
		if ( $Project->rush() ) {
			$colour .= ' rush';
		} # end if
	} # end if

	$html .= sprintf( '<li id="item_%d"%s%s>', $$self{'id'}, 
			( $colour ? ' class="'.$colour.'"' : '' ), 
			( $height ? ' style="height:'.$height.'px;"' : '' )
			);

	if ( $$self{'project_id'} ) {
		$html .= '<span class="Company">';
		$html .= sprintf( '<a class="docket" href="/employee/project/view.html?ProjectIndex=%1$d&amp;Docket=%2$d">%2$d</a>', $$self{'project_id'}, $Project->docket() );
		my $n = $Project->Company()->name();
		$n =~ s/The //gi;
		$html .= ssi::htmlize( $n );
		$html .= ' (<span class="CSR">'.$Project->Company()->CSR()->firstname().'</span>)';
		if ( $Project->operator_id() ) {
			$html .= ' (<span class="PrepressOperator">'.$Project->Operator()->firstname().'</span>)';
		} # end if
		if ( $Project->reprint() eq 'Y' ) {
			$html .= ' REPRINT'. $Project->reprint_reason();
		} # end if
		$html .= '</span>';
		$html .= qq`<span class="DueDate" id="JumpToDate$$self{'id'}">`;
		if ( ! $Project->due_date() ) {
			$html .= 'no duedate</span>';
		} else {
			my ( $year, $month, $day ) = split('-', $Project->due_date() );
			if ( $month ) { $html .= '&nbsp;'.substr( Date::Calc::Month_to_Text( $month ),0, 3); } # end if
				$html .= qq` $day</span>`;
		} # end if
	} # end if

	if ( openprint::usergroup::is_user_in( ['Scheduling'], $session{'user_id'} ) ) {
		$html .= sprintf( q`<div class="Comment" onclick="popup_window( '_job_popup.html', 'schedule_id=%1$d', {width:475} );">%2$s</div>`, $$self{'id'}, $self->comment() );
		$html .= sprintf( q`<div class="Stock" onclick="popup_window( '_stock_popup.html', 'schedule_id=%1$d', {width:475} );">%2$s</div>`, $$self{'id'}, $self->stock() );
		if ( $$self{'project_id'} ) {
			$html .= sprintf(q`<input type="hidden" name="ScheduleDate-%1$d" id="ScheduleDate-%1$d" value="%2$s"/>`, $$self{'id'}, $Project->due_date() );
			if ( sets::isin( $self->ServiceType()->name(), [ '', 'AdditionalSignature' ] ) ) {
				$html .= sprintf( q`<span class="Forms" onclick="popup_window( '_job_popup.html', 'schedule_id=%1$d', {width:475} );">%2$d %3$s</span>`, $$self{'id'}, $self->forms(), 'form'.($self->forms() > 1 ? 's' : '') );
			} # end if
			if ( $Equipment->smartscheduling() ) {
				$html .= sprintf( q`<span class="Impressions" onclick="popup_window( '_job_popup.html', 'schedule_id=%1$d', {width:475} );">%2$d imps @ %3$d/Hr</span>`, $$self{'id'}, $self->impressions(), $self->speed() );
			} else {
				$html .= sprintf( q`<span class="Impressions" onclick="popup_window( '_job_popup.html', 'schedule_id=%1$d', {width:475} );">%2$d imps</span>`, $$self{'id'}, $self->impressions() );
			} # end if
		} # end if
		if ( $Equipment->smartscheduling() or $$self{'locked'} ) {
			$html .= sprintf( q`<span class="StartTime" onclick="popup_window( '_job_popup.html', 'schedule_id=%1$d', {width:475} );">Start: %2$s<img src="/images/small-%3$s.gif" alt="%3$s"/></span>`, $$self{'id'},
					Date::Format::time2str( '%H:%M', Date::Parse::str2time( $$self{'starttime'} ) ),
					$$self{'locked'} ? 'locked' : 'unlocked',
					);
		} # end if

		$html .= sprintf( q`<span class="RunTime" onclick="popup_window( '_job_popup.html','schedule_id=%1$d', {width:475} );">Total Hr: %2$.2d:%3$.2d</span>`, $$self{'id'}, split(':',$self->runtime()) );

		if ( $Equipment->specification('DoStockVerification') eq 'Y' ) {
			$html .= sprintf( q`<span class="StockVerified" onclick="popup_window( '_job_popup.html','schedule_id=%1$d', {width:475} );">Stock: %2$s</span>`, $$self{'id'}, $self->stock_verified() ? 'Yes' : 'No' );
		} # end if

		$html .= '<span class="Buttons">';
		if ( $$self{'project_id'} ) {
			$html .= ssi::writeButton( $log, $dbh, 'Approve'.$$self{'id'}, '', "if(confirm('Are you sure?')){f1.schedule_id.value=$$self{'id'};f1.btnFunction.value='ApproveJob';f1.submit();}", '', 'A' ) if sets::isin( $Project->status(), 'In Prepress', 'Proofs Out','Waiting For Customer Approval','Waiting For QA Approval' );
			$html .= ssi::writeButton( $log, $dbh, 'Up'.$$self{'id'}, '', "new Ajax.Request( '_li_change.json', {parameters: { schedule_id:$$self{'id'}, action: 'Up' }, evalScripts: true } );", '', 'U' );
			$html .= ssi::writeButton( $log, $dbh, 'Bump'.$$self{'id'}, '', "popup_window('_bump_job.html','schedule_id=$$self{id}');", '', 'B' );
			$html .= ssi::writeButton( $log, $dbh, 'Complete'.$$self{'id'}, '', "popup_window('_signature_completion_popup.html', 'schedule_id=$$self{'id'}', { height: '100px', center: 'false' } );", '', 'C' );
			$html .= ssi::writeButton( $log, $dbh, 'House'.$$self{'id'}, '', "new Ajax.Updater('item_$$self{id}','_li.html', {parameters: {schedule_id:$$self{'id'}, action: 'House Stock' } } );", '', 'H' );
		} # end if
		$html .= ssi::writeButton( $log, $dbh, 'Remove'.$$self{'id'}, '', "if(confirm('Are you sure?')){new Ajax.Request('_li_change.json', {parameters: {schedule_id:$$self{'id'}, action: 'RemoveJob'}, evalScripts: true } )};", '', 'D' );
		if ( $$self{'project_id'} ) {
			if ( @{$$self{'service_id'}} == 2 ) {
				$html .= ssi::writeButton( $log, $dbh, 'Split'.$$self{'id'}, '', "new Ajax.Updater( '$ul_id', '_ul.html', { parameters: { id: '$ul_id', schedule_id: $$self{'id'}, action:'split'}, evalScripts: true } );", '', 'S' );
			} elsif ( @{$$self{'service_id'}} > 2 ) {
				$html .= ssi::writeButton( $log, $dbh, 'Split'.$$self{'id'}, '', "popup_window('_split_popup.html', 'schedule_id=$$self{'id'}' );", '', 'S' );
			} # end if
			if ( sets::isin( $self->ServiceType()->name(), [ '','AdditionalSignature' ] ) ) {
				$html .= ssi::writeButton( $log, $dbh, 'Stock'.$$self{'id'}, '', "popup_window('_stock_details.html','project_id='+$$self{'project_id'} );", '', 'P' );
} else {
$log->debug("ServiceType: $$self{'project_id'} $$self{'servicetype_id'}" . $self->ServiceType()->name() );
			} # end if
		} # end if
		if ( ( $self->starttime_seconds() > time ) or ( $$self{'project_id'} and ( $self->status() ne 'In Production' ) ) ) {
			$html .= ssi::writeButton( $log, $dbh, 'Start'.$$self{'id'}, '', "new Ajax.Request('_li_change.json', { parameters: { schedule_id: $$self{id}, action: 'start' } } );", '', 'Start' );
		} elsif ( ( $self->starttime_seconds() < time ) and ( (!$$self{'project_id'}) or $self->status() eq 'In Production' ) ) {
			$html .= ssi::writeButton( $log, $dbh, 'Stop'.$$self{'id'}, '', "new Ajax.Request('_li_change.json', { parameters: { schedule_id: $$self{id}, action: 'stop' } } );", '', 'Stop' );
		} # end if
		$html .= '</span>';
		if ( $$self{'project_id'} ) {
			$html .= '<span class="Services">';
			$html .= '<span class="Service">fold</span>' if $$services{'Folding'};
			$html .= '<span class="Service">stitch</span>' if $$services{'SaddleStitching'} or $$services{'LoopStitching'};
			$html .= '<span class="Service">trim</span>' if $$services{'Cutting'};
			$html .= '<span class="Service">no bindery</span>' if $$services{'NoBindery'};
			$html .= '</span>';
		}
	} else {
		$html .= sprintf( '<div class="Comment">%1$s</div>', $self->comment() );
		$html .= sprintf( q`<div class="Stock">%1$s</div>`, $self->stock() );
		if ( $$self{'project_id'} ) {
			$html .= sprintf( '<span class="Forms">%d %s</span>', $self->forms(), $self->forms() > 1 ? ' forms' : ' form' );
			$html .= sprintf( '<span class="Impressions">%d imps</span>', $self->impressions() );
		} # en dif
		$html .= sprintf( q`<span class="StartTime">Start:%2$s</span>`, $$self{'id'},
				Date::Format::time2str( '%H:%M', Date::Parse::str2time( $$self{'starttime'} ) ),
				);
		$html .= sprintf( q{<span class="RunTime">%2$.2d:%3$.2d</span>}, $$self{'id'}, split(':',$self->runtime()) );
		$html .= '<span class="Buttons">';
		if ( $$self{'project_id'} ) {
			if ( sets::isin( $self->ServiceType()->name(), [ '','AdditionalSignature' ] ) ) {
				$html .= ssi::writeButton( $log, $dbh, 'Paper'.$$self{'id'}, '', "popup_window('_stock_details.html','project_id=$$self{'project_id'}' );", '', 'P' );
			} # end if
		} # end if
		if ( $$self{'operator_id'} == $session{'user_id'} ) {
			$html .= ssi::writeButton( $log, $dbh, 'Start'.$$self{'id'}, '', "new Ajax.Request('_li_change.json', { parameters: { id: $$self{id}, action: 'start' } } );", '', 'Start' );
		} # end if
		$html .= '</span>';
		if ( $$self{'project_id'} ) {
			$html .= '<span class="Services">';
			$html .= '<span class="Service">fold</span>' if $$services{'Folding'};
			$html .= '<span class="Service">stitch</span>' if $$services{'SaddleStitching'} or $$services{'LoopStitching'};
			$html .= '<span class="Service">trim</span>' if $$services{'Cutting'};
			$html .= '<span class="Service">no bindery</span>' if $$services{'NoBindery'};
			$html .= '</span>';
		} # end if smart
	} # end if
	$html .= "</li>\n";
	return $html;
} # end sub get_li

sub operator_id {
	my ( $self, $operator_id ) = @_;

	my $Project = $self->Project();

	if ( ( defined $operator_id ) and ( $operator_id != $$self{'operator_id'} ) ) {
		$$self{'operator_id'} = $operator_id;
		if ( $$self{'project_id'} ) {
			foreach my $sig_id ( @{$$self{'service_id'}} ) {
				next if ! $sig_id;
				my $Service = $Project->Service( $sig_id );
				$Service->save({'operator_id'=>$operator_id}) if $Service->project_id();
			} # end foreach
		} # end if
	} # end if
	if ( ! $$self{'operator_id'} ) {
		if ( $$self{'project_id'} ) {
			foreach my $sig_id ( @{$$self{'service_id'}} ) {
				my $Service = $Project->Service( $sig_id );
				$$self{'operator_id'} = $Service->operator_id();
				last;
			} # end foreach
		} # end if
	} # end if
	return $$self{'operator_id'};
} # end sub operator_id

sub impressions {
	my $self = shift;

	my $impressions = 0;

	if ( @_ ) {
		$impressions = shift;
		if ( $$self{'project_id'} ) {
			foreach my $sig_id ( @{$$self{'service_id'}} ) {
				openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'ImpressionQuantity', int($impressions/@{$$self{'service_id'}}) );
			} # end foreach sig
		} # end if
	} elsif ( $$self{'project_id'} ) {
		my $Project = $self->Project();
		foreach my $sig_id ( @{$self->service_id()} ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
			$impressions += $$sig_specs{'ImpressionQuantity'};
		} # end foreach sig
		
		if ( ! $impressions ) {
# Pull from printing
			foreach my $sig_id ( @{$self->pertains_id()} ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
				if ( ! $$sig_specs{'ImpressionQuantity'} ) {
					$$sig_specs{'ImpressionQuantity'} = $$sig_specs{'hdnImpressionQuantity'.$Project->ordered_quantity_index()};
					openprint::service::insert_service_spec( $log, $dbh, $$self{'project_id'}, $sig_id, 'ImpressionQuantity', $$sig_specs{'ImpressionQuantity'} );
				} # end if
				$impressions += $$sig_specs{'ImpressionQuantity'};
			} # end foreach sig
		} # end if
	} # end if
	return $impressions;
} # end sub impressions

sub Project {
	return new openprint::Project( $_[0]{'project_id'} );
} # end sub Project

sub runtime {
	my ( $self, $new ) = @_;
	if ( @_ == 2 ) {
		$$self{'runtime'} = $new;
	} # end if

	if ( ! $$self{'runtime'} ) {
		my $seconds = 0;
		if ( $$self{'project_id'} ) {
			my $Project = $self->Project();
			my @forms = @{$self->pertains_id()};

			foreach my $sig_id ( @{$$self{'service_id'}} ) {
				my $Service = $Project->Service( $sig_id );
				$seconds += $Service->runtime( $self->Equipment(), @forms > 1 ? $self->impressions()/@forms : $self->impressions(), $self->speed(), $self->pertains_id() );

				#$seconds += openprint::service::get_runtime( $Project, $sig_id, $self->Equipment(), $self->impressions()/@{$$self{'service_id'}}, $self->speed() );
			} # end foreach
		} # end if
		$$self{'runtime'} = misc::seconds2hms( $seconds );
	} # end if
	return $$self{'runtime'};
} # end sub runtime

sub forms {
	my ( $self ) = @_;
	return scalar @{$self->pertains_id()};
} # end sub forms

sub shift_id {
	my $Shift = $_[0]->Shift();
	return $Shift->id() if $Shift;
	return;
} # end sub shift_id

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
				'equipment_id'	=>	$$self{'equipment_id'}, 
				'endtime_>'		=>	$$self{'starttime'}, 
				'starttime_<='	=>	$$self{'starttime'},
				#'limit'			=>	1,
				);
		if ( ! @Shifts ) {
$openprint::log->error('Shouldnt have to instantite here');
# We really shouldn't have to instantiate Shifts here.
if ( 0 ) {
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
} # end if
		} else {
			$Shift = shift @Shifts;
			if ( @Shifts ) {
				$log->warn("Deleting duplicate shifts! " . @Shifts );
				foreach ( @Shifts ) {
					$log->error( $_->to_string() );
					#$_->delete();
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
		if ( $$self{'project_id'} ) {
			foreach my $sig_id ( @{$$self{'service_id'}} ) {
				openprint::service::status( $$self{'project_id'}, $sig_id, 'In Production' );
			} # end foreach sig_id
		} # end if
	} # end if
	return $e;
} # end sub start

sub stop {
	my ( $self ) = @_;
	my $new_runtime = $self->runtime_seconds() - ( time - $self->starttime_seconds() );
	$new_runtime = 300 if $new_runtime < 0; # default to 5minutes
$log->debug("Stopping job: new runtime: $new_runtime starttime $$self{'starttime'} seconds: " . $self->starttime_seconds() . " now: " . time . " elapsed: " . ( time - $self->starttime_seconds() ) );
	my $e = $self->save({'runtime_seconds'=>$new_runtime,'locked'=>0});
	if ( ! $e ) {
		if ( $$self{'project_id'} ) {
			foreach my $sig_id ( @{$$self{'service_id'}} ) {
				openprint::service::status( $$self{'project_id'}, $sig_id, 'Ordered' );
			} # end foreach sig_id
		} # end if
	} # end if
	return $e;
} # end sub stop

sub status {
	my ( $self ) = @_;
	if ( $$self{'project_id'} ) {
	foreach my $sig_id ( @{$$self{'service_id'}} ) {
		return openprint::service::status( $$self{'project_id'}, $sig_id );
	} # end foreach sig_id
	} # end if
} # end sub status

sub bump {
	my ( $self, $equipment_id ) = @_;
	push @{$variable{'changed'}}, $self->Shift()->ul_id();
	my $Project = $self->Project();
	$Project->save({'due_date'=>$Project->get_due_date()}) if $Project->id() and ! $Project->due_date();

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
	my @forms = map {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $_ );
		$$sig_specs{'SignatureIndex'};
	} @{$self->service_id()} if $self->service_id();

	$Project->add_to_log( @session{'company_id','user_id'}, 'Form ' .join(',',sort @forms).' bumped to next shift: '.Date::Format::time2str($config{'DateTimeFormat'}, $self->starttime_seconds() ) . ' on ' . $self->Equipment()->name() );
	return $error;
} # end sub bump

sub speed {
	my $self = shift;
#$log->debug("Speed");
	if ( @_ ) {
		$$self{'speed'} = $_[0];
	} # end if
	if ( ! $$self{'speed'} ) {
		if ( (!($$self{'speed'} = $self->Equipment()->specification('Default Scheduling Runspeed'))) and $$self{'project_id'} ) {
			my $Project = $self->Project();
			if ( $Project->ordered_quantity_index() ) {
				my $Service = $Project->Service( $$self{'service_id'}[0] );
				my $ServiceType = $Service->ServiceType();
				my $specs = $Service->specs();
				return if ! $specs;

				if ( $ServiceType->name() eq 'Folding' ) {
					my $signatures = $self->pertains_id();
if ( ! $signatures ) {
$log->warn("No pertains $signatures");
} elsif ( ! @{$signatures} ) {
$log->warn("Empty pertains @$signatures");
}
					$$self{'speed'} = openprint::Estimating::Folding::runspeed( $Project, $Service, $self->Equipment(), $Project->ordered_quantity_index(), $$signatures[0] );
				} elsif ( $ServiceType->name() eq 'Cutting' ) {
					my $signatures = $self->pertains_id();
					$$self{'speed'} = openprint::Estimating::Cutting::runspeed( $Project, $Service, $self->Equipment(), $Project->ordered_quantity_index(), $signatures );
				} elsif ( $ServiceType->name() eq 'SaddleStitching' ) {
				} else {
					$$self{'speed'} = openprint::Estimating::Printing::runspeed( $Project, $specs, $Project->ordered_quantity_index(), $self->Equipment() );
				} # end if
			} # end if
		} # end if
	} # en dif
#$log->debug("DOne Speed $$self{'speed'}");
	return $$self{'speed'};
} # end sub speed

sub split {
	my ( $self, $forms ) = @_;

	my $Project = $self->Project();
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, 'Splitting forms' );
    my @service_ids = @{$$self{'service_id'}};
	if ( @service_ids > 1 ) {
		if ( $forms ) {
			my @new_forms = splice @service_ids, @service_ids - $forms, $forms;
			$self->service_id( \@service_ids );
			$self->runtime(undef);
			$self->save();
			my $J2 = $self->copy();
			if ( $self->starttime() ) {
				$J2->starttime_seconds( $self->endtime_seconds() + 1);
			} # end if
			$J2->service_id(\@new_forms);
			$J2->runtime(undef);
			$J2->save();
		} else {
			my $runtime = int ( $self->runtime_seconds()/@service_ids );
			$self->runtime_seconds( $runtime );
			$self->impressions( $self->impressions() / @service_ids );
			$$self{'service_id'} = [ shift @service_ids ];
			$self->save();
			my $starttime = $self->starttime_seconds() + $runtime if $self->starttime();
			foreach my $s_id ( @service_ids ) {
				my $J2 = $self->copy();
				$$J2{'service_id'} = [ $s_id ];
				if ( $self->starttime() ) {
					$J2->starttime_seconds( $starttime );
					$starttime += $runtime;
				} # end if starttime
				$J2->save();
			} # end foreach 
		} # end if
	} elsif ( @service_ids ) { # == 1
		# If there is only 1 service, then we copy it, dividing al relevant values
		my $service_index = $service_ids[0];
		my $old_specs = openprint::service::get_specs_ref( $Project, $service_index );
		my $qty_index = $Project->ordered_quantity_index();

		my $NewJob = $self->copy();
		my $new_service_index = $Project->copy_signature( $old_specs, {
				'txtPrice'.$qty_index   => $$old_specs{"txtPrice$qty_index"}/2,
				}, openprint::service::status( $Project->id(), $service_index ),
				);
		$$NewJob{'service_id'} = [ $new_service_index ];
		$NewJob->save();
# Update source service
		openprint::service::insert_service_spec( $log, $dbh, $Project->id, $service_index, "txtPrice$qty_index", $$old_specs{"txtPrice$qty_index"}/2 );

	} # end if
} # end sub split

sub to_string {
	my $self = $_[0];
	return sprintf('%d %s on %s starting %s', $self->project_id(), join(',', @{$self->service_id()}), $self->Equipment()->name(), $self->starttime() );
} # end sub to_string

sub pertains_id {
	
	if ( @_ > 1 ) {
		$_[0]{'pertains_id'} = $_[1];
	} # end if
	if ( (! $_[0]{'pertains_id'} ) and $_[0]{'service_id'} ) {
		return $_[0]{'service_id'};
	} # end if
	if ( $_[0]{'pertains_id'} ) {
		return $_[0]{'pertains_id'};
	} # end if
	return [];
} # end sub pertains_id

sub ServiceType {
	return new openprint::ServiceType( $_[0]{'servicetype_id'} );
} # end sub ServiceType

sub equipment_id {
	if ( @_ > 1 ) {
		$_[0]{'equipment_id'} = $_[1];
	} # end if
	if ( ! $_[0]{'equipment_id'} ) {
		# Attempt to guess
		my $Project = $_[0]->Project();
		my $Service = $Project->Service( $_[0]{'service_id'}[0] ) if $_[0]{'service_id'} and @{$_[0]{'service_id'}};
		my $specs = $Service->specs();

		if ( sets::isin( $Service->ServiceType()->name(), [ '', 'AdditionalSignature' ] ) ) {
			my $Equipment = openprint::Equipment::find_one( 'strid' => ( $$specs{'UsePress'} ? $$specs{'UsePress'} : $$specs{'ddmPress'.$Project->ordered_quantity_index()} ) );
			$_[0]{'equipment_id'} = $Equipment->id() if $Equipment;
		} elsif ( sets::isin( $Service->ServiceType()->name(), ['SaddleStitching','LoopStitching'] ) ) {
			$_[0]{'equipment_id'} = $$specs{'ddmEquipment'.$Project->ordered_quantity_index()};
		} # end if
	} # end if
	return $_[0]{'equipment_id'};
} # end sub equipment_id

1;
__END__
