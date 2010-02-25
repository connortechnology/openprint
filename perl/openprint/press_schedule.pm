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
	foreach my $Job ( openprint::ScheduledJob::find('project_id'=>$p_id, ( $s_id ? ('service_id'=>$s_id) : () ) ) ) {
		$Job->delete();
	} # end foreach
} # end sub remove

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
		next if openprint::ScheduledJob::find('project_id'=>$Project->id(), 'service_id'=>$s_s_id );

		my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		$$sig_specs{'UsePress'} = $$sig_specs{'ddmPress'.$Project->ordered_quantity_index()} if ! $$sig_specs{'UsePress'};
		if ( ! $$sig_specs{'UsePress'} ) {
			$error .= "No press for signature $$sig_specs{'SignatureIndex'}<br/>";
			next;
		} # end if

		my @service_ids = ( $s_s_id );

		# Merge identical sigs
		foreach my $s_id_2 ( @sigs ) {
			next if $s_id_2 == $s_s_id;
			my $sig_specs2 = openprint::service::get_specs_ref( $Project, $s_id_2 );
			if ( openprint::Estimating::Printing::compare_signatures( $sig_specs, $sig_specs2, $Project->ordered_quantity_index() ) ) {
				push @service_ids, $s_id_2;
			} # end if
		} # end foreach

		if ( my @Equipment = openprint::Equipment::find('strid'=>$$sig_specs{'UsePress'}) ) {
			my $Job = new openprint::ScheduledJob();
			$_ = $Job->save({
				'project_id'	=>	$Project->id(),
				'equipment_id'	=>	$Equipment[0]->id(),
				'starttime'		=>	undef,
				'service_id'	=>	\@service_ids,
			});
			if ( $_ ) {
				$error .= 'Error adding to press schedule: ' . $_;
			} else {
				$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Added Form $$sig_specs{'SignatureIndex'} to pending press schedule." );

			} # end if
		} else {
			$error .= "Error adding to press schedule: Press not found ($$sig_specs{UsePress}) for signature $$sig_specs{'SignatureIndex'}<br/>";
		} # end if
	} # end foreach sig
	sql::end_transaction( $dbh, $ac );
	return $error;
} # end sub add_project_to_press_schedule

1;
__END__
