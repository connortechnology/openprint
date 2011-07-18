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
	require openprint::Blacklist;

use strict;

sub hosts {
	if ( $param{'action'} eq 'Delete' ) {
		foreach my $host_id ( ref $param{'host_id'} eq 'ARRAY' ? @{$param{'host_id'}} : $param{'host_id'} ) {
			my $Host = new openprint::Host( $host_id );
			$variable{'error'} .= $Host->delete();
		} # end foreach host_id
	} elsif ( $param{'action'} eq 'Save' ) {
		my $Host = new openprint::Host( $param{'host_id'} );
		$param{'mac'} = [ map { split( ',', $_ ) } split("\n", $param{'mac'}) ];
		$variable{'error'} .= $Host->save(\%param);
		%param = ();
	} # end if
	ssi::save_params( '/employee/it/hosts.html', 
			'created_on_start_year', 'created_on_start_month', 'created_on_start_day', 
			'created_on_end_year', 'created_on_end_month', 'created_on_end_day', 
			'updated_on_start_year', 'updated_on_start_month', 'updated_on_start_day', 
			'updated_on_end_year', 'updated_on_end_month', 'updated_on_end_day', 
			'has_hostname', 'monitored', 'whitelisted','blacklisted','online',
			);
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
	if ( $param{'btnFunction'} eq 'Delete' ) {
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
			);
} # end sub _hosts

sub host {
	my $Host = $variable{'Host'} = new openprint::Host( $param{'host_id'} );
	if ( $param{'action'} eq 'Resolve' ) {
		if ( ! $Host->ip() ) {
			$variable{'error'} .= 'No ip.  Cant resolve without an ip.';
		} else {
		$variable{'error'} .= $Host->save({
				'hostname'	=> $Host->resolve(),
				'mac'		=> $Host->get_mac(),
				});
		} # end if
	} elsif ( $param{'action'} eq 'ping' ) {
		if ( $Host->ping() ) {
			$variable{'information'} .= 'Host is alive.';
		} else {
			$variable{'information'} .= 'Host did not respond to ping.';
		} # end if	
	} # end if
	if ( ( ! $Host->id() ) and ( $param{'ip'} or $param{'mac'} or $param{'hostname'} ) ) {
		$Host->ip( $param{'ip'} );
		$Host->mac( [ $param{'mac'} ] ) if $param{'mac'};
		$Host->hostname( $param{'hostname'} );
		if ( $Host->ip() ) {
			if ( ! $Host->mac() ) {
				$Host->mac( [ $Host->get_mac() ] );
			} # end if
			if ( ! $Host->hostname() ) {
				$Host->hostname( $Host->resolve() );
			} # end if
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

sub blacklist {
	my $Blacklist = $variable{'Blacklist'} = new openprint::Blacklist( $param{'id'} );
	if ( $param{'action'} eq 'Delete' ) {
		$variable{'error'} = $Blacklist->delete();
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= 'Blacklist entry deleted.<br/>';
			%param = ();
		} # end if error
	} elsif ( $param{'action'} eq 'Save' ) {
		$variable{'error'} .= $Blacklist->save(\%param);
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= 'Blacklist entry saved.<br/>';
			%param = ();
		} # end if error
	} # end if
	ssi::save_params( '/employee/it/blacklist.html', 
			'created_on_start_year', 'created_on_start_month','created_on_start_day',
			'created_on_end_year', 'created_on_end_month','created_on_end_day',
			'updated_on_start_year', 'updated_on_start_month','updated_on_start_day',
			'updated_on_end_year', 'updated_on_end_month','updated_on_end_day',
	);
	ssi::setup_date_select( '/employee/it/blacklist.html', 'created_on_start', 0 );
	ssi::setup_date_select( '/employee/it/blacklist.html', 'created_on_end', 0 );
	ssi::setup_date_select( '/employee/it/blacklist.html', 'updated_on_start', 0 );
	ssi::setup_date_select( '/employee/it/blacklist.html', 'updated_on_end', 0 );
} # end sub blacklist
sub _blacklist {
	ssi::save_params( '/employee/it/blacklist.html', 
			'created_on_start_year', 'created_on_start_month','created_on_start_day',
			'created_on_end_year', 'created_on_end_month','created_on_end_day',
			'updated_on_start_year', 'updated_on_start_month','updated_on_start_day',
			'updated_on_end_year', 'updated_on_end_month','updated_on_end_day',
	);
} # end sub _blacklist

sub _blacklist_popup {
	my $Blacklist = $variable{'Blacklist'} = new openprint::Blacklist( $param{'id'} );
} # end sub _blacklist_popup

sub logs {
} # end sub logs

1;
__END__
