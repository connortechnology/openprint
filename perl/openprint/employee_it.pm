use strict;

package openprint::employee_it;
use openprint;
use vars qw( %variable %session %param %config $log $dbh $r );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::Host;
require openprint::RADIUS_Check;
require openprint::RADIUS_Reply;
require openprint::User_Type;
require openprint::Session;
require openprint::License;
require openprint::Software;
require openprint::Location;

sub logs {
	ssi::setup_date_select( '/employee/it/logs.html', 'date_time_start', -31 );
	ssi::setup_date_select( '/employee/it/logs.html', 'date_time_end', '' );
	ssi::save_params( '/employee/it/logs.html', 
			'date_time_start_year', 'date_time_start_month', 'date_time_start_day', 
			'date_time_end_year', 'date_time_end_month', 'date_time_end_day', 
);
} # end sub logs

sub hosts {
	if ( $param{'action'} eq 'Delete' ) {
		foreach my $host_id ( ref $param{'host_id'} eq 'ARRAY' ? @{$param{'host_id'}} : $param{'host_id'} ) {
			my $Host = new openprint::Host( $host_id );
			$variable{'error'} .= $Host->delete();
		} # end foreach host_id
		%param = ();
	} # end if
	_hosts();
	ssi::setup_date_select( '/employee/it/hosts.html', 'created_on_start', '' );
	ssi::setup_date_select( '/employee/it/hosts.html', 'created_on_end', '' );
	ssi::setup_date_select( '/employee/it/hosts.html', 'updated_on_start', '' );
	ssi::setup_date_select( '/employee/it/hosts.html', 'updated_on_end', '' );
	if ( ! exists $session{'/employee/it/hosts.html?has_hostname'} ) {
		$session{'/employee/it/hosts.html?has_hostname'} = 1;
	} # end if
	if ( ! exists $session{'/employee/it/hosts.html?assigned'} ) {
		$session{'/employee/it/hosts.html?assigned'} = 1;
	} # end if
	if ( ! exists $session{'/employee/it/hosts.html?notassigned'} ) {
		$session{'/employee/it/hosts.html?notassigned'} = 1;
	} # end if
} # end sub hosts

sub _hosts {
	if ( $param{'action'} eq 'Delete' ) {
		foreach my $host_id ( ref $param{'host_id'} eq 'ARRAY' ? @{$param{'host_id'}} : $param{'host_id'} ) {
			my $Host = new openprint::Host( $host_id );
			$variable{'error'} .= $Host->delete();
		} # end foreach host_id
	} # end if
	ssi::save_params( '/employee/it/hosts.html', 
			'created_on_start_year', 'created_on_start_month', 'created_on_start_day', 
			'created_on_end_year', 'created_on_end_month', 'created_on_end_day', 
			'updated_on_start_year', 'updated_on_start_month', 'updated_on_start_day', 
			'updated_on_end_year', 'updated_on_end_month', 'updated_on_end_day', 
			'has_hostname', 'monitored','whitelisted','blacklisted','online',
			'ip','hostname','mac','type_id',
			'radius_auth', 'order',
			);
	if ( $config{'RADIUS Support'} eq 'Y' ) {
		$openprint::RADIUS_Reply::dbh = $openprint::RADIUS_Check::dbh = sql::open_sql( $log,
				'database'  => $config{'RADIUS DB Name'},
				'driver'    => $config{'RADIUS DB Driver'},
				'host'      => $config{'RADIUS DB Server'},
				'login'     => $config{'RADIUS DB Username'},
				'password'  => $config{'RADIUS DB Password'},
				);
		if ( ! $openprint::RADIUS_Check::dbh ) {
			$variable{'error'} .= 'Unable to connect to RADIUS DB server.';
		} # end if
	} # end if
} # end sub _hosts

sub host {
	my $Host = $variable{Host} = new openprint::Host( $param{host_id} );
	if ( $param{action} eq 'Resolve' ) {
		foreach my $I ( $Host->Interfaces() ) {
			if ( ! $I->ip() ) {
				$variable{error} .= 'For ' . $I->mac() . ': No ip.  Cant resolve without an ip.';
			} else {
				$variable{error} .= $Host->save({ hostname	=> $Host->resolve() });
				$variable{error} .= $I->save({ mac		=> $I->get_mac(), });
			} # end if
		} # end foreach
	} elsif ( $param{action} eq 'Delete' ) {
		$variable{error} .= $Host->delete();
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/employee/it/hosts.html';
			return;
		} # end if
		%param = ();
	} elsif ( $param{action} eq 'Wake' ) {
		foreach my $I ( $Host->Interfaces() ) {
			next if ! $I->mac();
			`wakeonlan $$I{mac}`;
		} # end foraech
	} elsif ( $param{action} eq 'GEOLookup' ) {
		foreach my $I ( $Host->interfaces() ) {
			if ( ! $I->ip() ) {
				$variable{error} .= "Interface $$I{mac} does not have an ip.<br/>";
			} else {
				my $Location = openprint::Location::from_ip( $I->ip() );
				if ( ! $Location ) {
					$variable{error} .= 'No Location found from ip.';
				} else {
					$$Host{location_id} = $Location->id();
				} # end if
			} # end if
		} # end foreach I
		
	} elsif ( $param{action} eq 'Save' ) {
		if ( $param{type_id} ) {
			delete $param{type};
		} else {
			delete $param{type_id};
		} # end if
		$variable{error} .= $Host->save(\%param);
		foreach my $I ( $Host->Interfaces(), new openprint::Host_Interface() ) {
			if ( $param{"mac-$$I{id}"} or $param{"ip-$$I{id}"} or $param{"comment-$$I{id}"} ) {
				$variable{error} .= $I->save({
					host_id=>$$Host{id},
					map { $_, $param{"$_-$$I{id}"} } ( 'mac', 'ip', 'dhcp', 'comment' )
				});
			} else {
				$variable{error} .= $I->delete() if $$I{id};
			} # end if
		} # end foreach Interface
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/employee/it/hosts.html';
			return;
		} # end if
		%param = ();
	} elsif ( $param{'action'} eq 'ping' ) {
		if ( $Host->ping() ) {
			$variable{'information'} .= 'Host is alive.';
		} else {
			$variable{'information'} .= 'Host did not respond to ping.';
		} # end if	
	} elsif ( $param{'action'} eq 'Upload' ) {
        # Save any changes made to Article
		$param{'mac'} = [ map { split( ',', $_ ) } split("\n", $param{'mac'}) ];
		if ( $param{'type_id'} ) {
			delete $param{'type'};
		} else {
			delete $param{'type_id'};
		} # end if
        $variable{'error'} .= $Host->save(\%param);
        my $Asset = openprint::Asset::upload( 'filename' );
        if ( ref $Asset ne 'openprint::Asset' ) {
            $variable{'error'} .= $Asset;
        } else {
            my $Object_Asset = new openprint::Object_Asset();
            $variable{'error'} .= $Object_Asset->save({
					'asset_id'		=>	$Asset->id(),
					'object_id'		=>	$Host->id(),
					'object_type'	=>	'openprint::Host',
					});
            if ( $param{'asset_name'} and ! $Asset->name() ) {
                $Asset->save({'name'=>$param{'asset_name'}});
            } # end if
        } # end if
	} # end if
	if ( ( ! $Host->id() ) and ( $param{'ip'} or $param{'mac'} or $param{'hostname'} ) ) {
		my $I = new openprint::Host_Interface();
		$I->set({ ip=>$param{ip}, mac=>$param{mac} });
		$Host->Interfaces( [ $I ] );
		$Host->hostname( $param{'hostname'} );
		if ( $I->ip() ) {
			if ( ! $I->mac() ) {
				$I->mac( [ $I->get_mac() ] );
			} # end if
			if ( ! $Host->hostname() ) {
				$Host->hostname( $Host->resolve() );
			} # end if
		} # end if
	} # end if
	ssi::setup_date_select( '/employee/it/host.html', 'log_created_on_start', 0 );
	ssi::setup_date_select( '/employee/it/host.html', 'log_created_on_end', '' );
	if ( $config{'RADIUS Support'} eq 'Y' ) {
		$openprint::RADIUS_Reply::dbh = $openprint::RADIUS_Check::dbh = sql::open_sql( $log,
				'database'  => $config{'RADIUS DB Name'},
				'driver'    => $config{'RADIUS DB Driver'},
				'host'      => $config{'RADIUS DB Server'},
				'login'     => $config{'RADIUS DB Username'},
				'password'  => $config{'RADIUS DB Password'},
				);
		if ( ! $openprint::RADIUS_Check::dbh ) {
			$variable{'error'} .= 'Unable to connect to RADIUS DB server.';
			return;
		} # end if
    } # end if

} # end sub view_host

sub camera {
} # end sub camera

sub cameras {
} # end sub cameras

sub camera_viewer {
} # end sub camera_viewer

sub _cameras_viewing {
	if ( $param{'camera_id'} ) {
		$session{'cameras_viewing'} = join(',', sets::union( split( ',', $session{'cameras_viewing'} ), $param{'camera_id'} ) );
	} # end if
} # end sub _cameras_viewing
sub _cameras_available {
	if ( $param{'camera_id'} ) {
		$session{'cameras_viewing'} = join(',', sets::exclude( [ $param{'camera_id'} ], [ split( ',', $session{'cameras_viewing'} ) ] ) );
	} # end if
} # end sub _cameras_available
sub _camera { # .json 
	$session{'/employee/it/camera_viewer.html?monitor_size-'.$param{'monitor_id'}} = join('x', @param{'width','height'} );
}

sub logs {
} # end sub logs

sub _radius_mac_line {
	if ( $config{'RADIUS Support'} ne 'Y' ) {
		$variable{'error'} .= 'RADIUS Support is not enabled.';
		return;
	} # end if
	$openprint::RADIUS_Reply::dbh = $openprint::RADIUS_Check::dbh = sql::open_sql( $log,
			'database'  => $config{'RADIUS DB Name'},
			'driver'    => $config{'RADIUS DB Driver'},
			'host'      => $config{'RADIUS DB Server'},
			'login'     => $config{'RADIUS DB Username'},
			'password'  => $config{'RADIUS DB Password'},
			);
	if ( ! $openprint::RADIUS_Check::dbh ) {
		$variable{'error'} .= 'Unable to connect to RADIUS DB server.';
		return;
	} # end if
	if ( $param{'action'} eq 'add' ) {
		if ( $param{username} =~ /^([[:xdigit:]]{2})[\:\-]?([[:xdigit:]]{2})[\:\-]?([[:xdigit:]]{2})[\:\-]?([[:xdigit:]]{2})[\:\-]?([[:xdigit:]]{2})[\:\-]?([[:xdigit:]]{2})$/ ) {
			# Convert from alternate mac formats
			$param{username} = "$1-$2-$3-$4-$5-$6";
		} else {
			$log->warn("Re didn't match $param{'username'}");
		} # end if
		if ( ! $param{value} ) {
			if ( $param{attribute} eq 'Cleartext-Password' ) {
				$param{value} = $param{'username'};
			} elsif ( $param{attribute} eq 'Framed-IP-Address' ) {
				my $Host = openprint::Host->find_one('mac any'=>$param{'username'});
				if ( $Host ) {
					$param{'value'} = $Host->ip();
				} # end if
			} # end if
		} # end if

		my $Radius;
		if ( $openprint::RADIUS_Check::attributes{$param{attribute}} ) {
			$Radius = new openprint::RADIUS_Check();
		} elsif ( $openprint::RADIUS_Reply::attributes{$param{attribute}} ) {
			$Radius = new openprint::RADIUS_Reply();
		} else {
			$log->error("Unknown RADIUS Attribute: $param{attribute}");
			$variable{error} .= "Unknown RADIUS Attribute: $param{attribute}<br/>";
			return;
		} # end if
		$variable{error} .= $Radius->save({
			username	=>	$param{username},
			value		=>	$param{value},
			op			=>	':=',
			attribute	=>	$param{attribute},
		});
	} elsif ( $param{'action'} eq 'remove' ) {
		my $Radius;
		if ( $openprint::RADIUS_Check::attributes{$param{attribute}} ) {
			$Radius = openprint::RADIUS_Check->find_one( username=>$param{username}, attribute=>$param{attribute} );
			$Radius = openprint::RADIUS_Reply->find_one( username=>$param{username}, attribute=>$param{attribute} ) if ! $Radius;
		} elsif ( $openprint::RADIUS_Reply::attributes{$param{attribute}} ) {
			$Radius = openprint::RADIUS_Reply->find_one( username=>$param{username}, attribute=>$param{attribute} );
			$Radius = openprint::RADIUS_Check->find_one( username=>$param{username}, attribute=>$param{attribute} ) if ! $Radius;
		} else {
			$log->error("Unknown RADIUS Attribute: $param{attribute}");
			$variable{error} .= "Unknown RADIUS Attribute: $param{attribute}<br/>";
			return;
		} # end if
		if ( ! $Radius ) {
			$variable{error} .= 'Radius entry for  username=>$param{username}, attribute=>$param{attribute} is not found.<br/>';
		} else {
			$variable{error} .= $Radius->delete() if $Radius->id();
		} # end if
	} # end if
	$variable{username} = $param{username};
	$variable{username} =~ s/[^[[:xdigit:]]]//g;
} # end sub _radius_mac_line

sub radius {
	_radius();
} # end sub radius

sub _radius {
	if ( $config{'RADIUS Support'} eq 'Y' and ( ! $openprint::RADIUS_Check::dbh ) ) {
		$openprint::RADIUS_Reply::dbh = $openprint::RADIUS_Check::dbh = sql::open_sql( $log,
				'database'  => $config{'RADIUS DB Name'},
				'driver'    => $config{'RADIUS DB Driver'},
				'host'      => $config{'RADIUS DB Server'},
				'login'     => $config{'RADIUS DB Username'},
				'password'  => $config{'RADIUS DB Password'},
				);
		if ( ! $openprint::RADIUS_Check::dbh ) {
			$variable{'error'} .= 'Unable to connect to RADIUS DB server.';
		} # end if
	} # end if
	if ( $param{'action'} eq 'Delete' ) {
		foreach my $id ( ref $param{'record_id'} eq 'ARRAY' ? @{$param{'record_id'}} : $param{'record_id'} ) {
			my $Record = new openprint::openprint::RADIUS_Check( $id );
			$variable{'error'} .= $Record->delete();
		} # end foreach host_id
	} # end if
	ssi::save_params( '/employee/it/radius.html', 
			'attribute','username'
			);
} # end sub _radius

sub _host_logs {
	$variable{'Host'} = new openprint::Host( $param{'host_id'} );
	ssi::save_params( '/employee/it/host.html', 
			( map { 'log_created_on_start_'.$_ } ( 'year', 'month','day','hour','minute' ) ),
			( map { 'log_created_on_end_'.$_ } ( 'year', 'month','day','hour','minute' ) ),
	);
} # end sub _host_logs

sub sessions {
	_sessions();
	$session{'/employee/it/sessions.html?company_id'} = $session{'company_id'} if ! exists $session{'/employee/it/sessions.html?company_id'};
} # end sub sessions

sub _sessions {
	if ( $param{'action'} eq 'Delete' ) {
		foreach my $session_id ( ref $param{'session_id'} eq 'ARRAY' ? @{$param{'session_id'}} : $param{'session_id'} ) {
			next if ! $session_id;
			sql::execute(undef,undef,'DELETE FROM sessions WHERE id=?', $session_id );
		} # end foreach
	} # end if
	ssi::save_params( '/employee/it/sessions.html', 
			'created_on_start_year', 'created_on_start_month','created_on_start_day',
			'created_on_end_year', 'created_on_end_month','created_on_end_day',
			'updated_on_start_year', 'updated_on_start_month','updated_on_start_day',
			'updated_on_end_year', 'updated_on_end_month','updated_on_end_day',
			'company_id','user_type','user_id',
	);
} # end sub _sessions

sub session {
} # end sub session

sub _notifications {
	my $Host = $variable{'Host'} = new openprint::Host( $param{'host_id'} );

	if ( $param{'action'} eq 'add' ) {
		my $Notification = new openprint::Host_Notification();
		$variable{'error'} .= $Notification->save({
			'user_id'	=>	$param{'user_id'},
			'host_id'	=>	$$Host{'id'},
		});
	} elsif ( $param{'action'} eq 'delete' ) {
		my $Notification = openprint::Host_Notification->find_one(
			'user_id'	=>	$param{'user_id'},
			'host_id'	=>	$$Host{'id'},
			);
		if ( ! $Notification ) {
			$variable{'error'} .= 'Notification not found.';
		} else {
			$variable{'error'} .= $Notification->delete();
			delete $$Host{'Notifications'};
		} # end if
	} # end if
} # end sub _notifications

sub _assets {
	my $Host = $variable{'Host'} = new openprint::Host( $param{'host_id'} );
	if ( $param{'action'} eq 'delete' ) {
		my $Object_Asset = openprint::Object_Asset->find_one('asset_id'=>$param{'asset_id'}, 'object_type'=>'openprint::Host','object_id'=>$Host->id());
		if ( ! $Object_Asset ) {
			$variable{'error'} .= 'Object Asset not found.';
			return;
		} # end if
		$variable{'error'} .= $Object_Asset->delete();
	} # end if
} # end sub _assets

sub licenses {
	if ( $param{'action'} eq 'Delete' ) {
		foreach my $license_id ( ref $param{license_id} eq 'ARRAY' ? @{$param{license_id}} : $param{license_id} ) {
			my $License = new openprint::License( $license_id );
			$variable{error} .= $License->delete();
		} # end foreach license_id
		%param = ();
	} # end if
	_licenses();
	ssi::setup_date_select( '/employee/it/licenses.html', 'created_on_start', '' );
	ssi::setup_date_select( '/employee/it/licensess.html', 'created_on_end', '' );
	ssi::setup_date_select( '/employee/it/licenses.html', 'updated_on_start', '' );
	ssi::setup_date_select( '/employee/it/licenses.html', 'updated_on_end', '' );
} # end sub licenses

sub _licenses {
	if ( $param{action} eq 'Delete' ) {
		foreach my $license_id ( ref $param{license_id} eq 'ARRAY' ? @{$param{license_id}} : $param{license_id} ) {
			my $License = new openprint::License( $license_id );
			$variable{error} .= $License->delete();
		} # end foreach license_id
		%param = ();
	} # end if
	ssi::save_params( '/employee/it/licenses.html', 
	( map { 'created_on_start_' . $_ } ( 'year', 'month', 'day' ) ),
	( map { 'created_on_end_' . $_ } ( 'year', 'month', 'day' ) ),
	( map { 'updated_on_start_' . $_ } ( 'year', 'month', 'day' ) ),
	( map { 'updated_on_end_' . $_ } ( 'year', 'month', 'day' ) ),
	( map { 'purchased_on_start_' . $_ } ( 'year', 'month', 'day' ) ),
	( map { 'purchased_on_end_' . $_ } ( 'year', 'month', 'day' ) ),
	( map { 'expires_on_start_' . $_ } ( 'year', 'month', 'day' ) ),
	( map { 'expires_on_end_' . $_ } ( 'year', 'month', 'day' ) ),
			'ip','hostname','mac','software_id','serialkey',
			'order',
			);
} # end sub _licenses

sub license {
	my $License = $variable{License} = new openprint::License( openprint::License->transform('id',$param{license_id}) );
	if ( $param{action} eq 'Delete' ) {
		$variable{error} .= $License->delete();
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/employee/it/licenses.html';
			%param = ();
		} # end if
	} elsif ( $param{action} eq 'Save' ) {
		my $License = new openprint::License( $param{license_id} );
		if ( $_ = openprint::License->find_one(serialkey=>$param{serialkey}, ( $param{license_id} ? ('id !=' => $param{license_id}) : () ) ) ) {
			$variable{error} .= 'License has already been entered.  Click <a href="license.html?license_id='.$_->id().'">here</a> to view it.<br/>';
			return;
		} # end if
		if ( $param{software_id} ) {
			delete $param{software};
		} else {
			delete $param{software_id};
		} # end if
		$variable{error} .= $License->save(\%param);
		if ( ! $variable{error} ) {
			%param = ();
			$variable{ExternalRedirect} = '/employee/it/licenses.html';
		} # end if
	} # end if
} # end sub license

sub _license_host_popup {
	my $License = $variable{License} = new openprint::License($param{license_id});
	if ( ! $License->id() ) {
		$variable{error} .= 'License not found.';
		return;
	} # end if
} # end sub _license_host_popup

sub _license_host_results {
	my $License = $variable{License} = new openprint::License($param{license_id});
	if ( ! $License->id() ) {
		$variable{error} .= 'License not found.';
		return;
	} # end if
} # end sub _license_host_results

sub _license_allocations {
	my $License = $variable{License} = new openprint::License($param{license_id});
	if ( ! $License->id() ) {
		$variable{error} .= 'License not found.';
		return;
	} # end if
	if ( $param{action} eq 'allocate' ) {
		my $Host = new openprint::Host($param{host_id});
		if ( ! $Host->id() ) {
			$variable{error} .= 'Host not found.';
			return;
		} # end if
		
		my $LH = new openprint::License_Host();
		$variable{error} .= $LH->save({license_id=>$param{license_id}, host_id=>$param{host_id}});
	} # end if	
} # end sub _license_alliations

sub _information {
	my $Host = $variable{Host} = new openprint::Host( $param{host_id} );
	if ( ! $Host->id() ) {
		$variable{error} .= "Host not found: id=>$param{host_id}<br/>";
		return;
	} # end if

	if ( $param{action} eq 'add' ) {
		my $Info = new openprint::Host_Info();
		$variable{error} .= $Info->save({
				host_id	=>	$param{host_id},
				name	=>	$param{name},
				value	=>	$param{value}, 
			});
	} elsif ( $param{action} eq 'delete' ) {
		my $Info = new openprint::Host_Info( $param{info_id} );
		$variable{error} .= $Info->delete();
	} # end if
		
} # end sub _information
sub _host_actions {
} # end sub _host_actions

1;
__END__
