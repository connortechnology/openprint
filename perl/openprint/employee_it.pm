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
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $host_id ( ref $param{'host_id'} eq 'ARRAY' ? @{$param{'host_id'}} : $param{'host_id'} ) {
			my $Host = new openprint::Host( $host_id );
			$variable{'error'} .= $Host->delete();
		} # end foreach host_id
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		my $Host = new openprint::Host( $param{'host_id'} );
		$param{'mac'} = [ map { split( ',', $_ ) } split("\n", $param{'mac'}) ];
		$variable{'error'} .= $Host->save(\%param);
		%param = ();
	} # end if
	ssi::setup_date_select( '/employee/it/hosts.html', 'created_on_start', '' );
	ssi::setup_date_select( '/employee/it/hosts.html', 'created_on_end', '' );
	ssi::setup_date_select( '/employee/it/hosts.html', 'updated_on_start', '' );
	ssi::setup_date_select( '/employee/it/hosts.html', 'updated_on_end', '' );
	if ( ! exists $session{'/employee/it/hosts.html?assigned'} ) {
		$session{'/employee/it/hosts.html?assigned'} = 1;
	} # end if
	if ( ! exists $session{'/employee/it/hosts.html?notassigned'} ) {
		$session{'/employee/it/hosts.html?notassigned'} = 1;
	} # end if
	ssi::save_params( '/employee/it/hosts.html', 
			'created_on_start_year', 'created_on_start_month', 'created_on_start_day', 
			'created_on_end_year', 'created_on_end_month', 'created_on_end_day', 
			'updated_on_start_year', 'updated_on_start_month', 'updated_on_start_day', 
			'updated_on_end_year', 'updated_on_end_month', 'updated_on_end_day', 
			);

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
			);
} # end sub _hosts

sub host {
	$variable{'Host'} = new openprint::Host( $param{'host_id'} );
	if ( $param{'btnFunction'} eq 'Resolve' ) {
		$variable{'error'} .= $variable{'Host'}->save({
				'hostname'=> $variable{'Host'}->resolve(),
				'mac'=> $variable{'Host'}->get_mac(),
				});
	} # end if
} # end sub view_host

sub camera {
} # end sub camera

sub cameras {
} # end sub cameras

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

1;
__END__
