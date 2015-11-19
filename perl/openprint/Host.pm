use strict;
require openprint::Object;

package openprint::Host_Interface;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table $serial %find_fields %fields %transforms %defaults );
$debug = 0;
$serial = 'host_interfaces_id_seq';
$table = 'host_interfaces';

%fields = (
	id				=>	'id',
	mac				=>	'mac',
	ip				=>	'ip',
	comment			=>	'comment',
	dhcp			=>	'dhcp',
    host_id         =>  'host_id',
);
%find_fields = (
	whitelist	=>	'(SELECT whitelist FROM Hosts WHERE Hosts.id=host_id)',
);
%defaults	= (
	dhcp		=>	0,
	ip			=>	undef,
	mac			=>	undef,
);

sub Host {
	return new openprint::Host( $_[0]{host_id} );
} # end sub Host;

sub resolve {
	my ( $self ) = @_;
	my @h = gethostbyaddr(pack('C4',split('\.',$$self{ip})),2);
	if ( @h ) {
		return $h[0];
	} elsif ( $debug ) {
		$openprint::log->warn("Unable to reverse DNS $$self{ip}");
	} # end if
	return undef;
} # end sub resolve

sub get_mac {
	my ( $self ) = @_;

	my ( $subnet ) = $$self{'ip'} =~ /^(\d+\.\d+\.\d+)\.\d+$/;

	my $use_iface;

	require IO::Interface::Simple;
	foreach my $iface ( IO::Interface::Simple->interfaces ) {
$openprint::log->debug("Looking at $iface. " . $iface->address . ', subnet: ' . $subnet );
		if ( $iface->address =~ /^$subnet\.\d+$/ ) {
			$use_iface = $iface;
		} # end if
	}

	if ( $use_iface ) {
		require Net::ARP;
		my $mac = Net::ARP::arp_lookup( $use_iface, $$self{'ip'} );
		$openprint::log->debug("Mac: $mac");
		return $mac;
	} else {
		$openprint::log->debug("Unable to determine interface");
	} # end if
} # end sub get_mac
package openprint::Host_Notification;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table @identified_by %fields %transforms %defaults );
$debug = 0;
$table = 'host_notifications';
@identified_by = ( 'host_id','user_id' );

%fields = (
	host_id			=>	'host_id',
	user_id			=>	'user_id',
);

package openprint::Host_Type;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table $serial %fields %transforms %defaults %types );
$debug = 0;
$table = 'host_types';
$serial = 'host_types_id_seq';
%fields = (
	id			=>	'id',
	name		=>	'name',
);
%transforms = (
	id		=>	[ 's/\D//g' ],
	name	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);

package openprint::Host_Info;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table $serial %fields %transforms %defaults %types %find_fields );
$debug = 0;
$table = 'host_info';
$serial = 'host_info_id_seq';
%fields = (
	id			=>	'id',
	host_id		=>	'host_id',
	name		=>	'name',
	value		=>	'value',
);
%find_fields = (
);
%transforms = (
	id		=>	[ 's/\D//g' ],
	name	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	value	=>	[ 's/^\s+//', 's/\s+$//' ],
);

package openprint::Host;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults %types );
$debug = 0;
$table = 'hosts';
$serial = 'hosts_id_seq';
%fields = (
	id			=>	'id',
	hostname	=>	'hostname',
	blacklist	=>	'blacklist',
	whitelist	=>	'whitelist',
	monitored	=>	'monitored',
	description	=>	'description',
	created_on	=>	'created_on',
	updated_on	=>	'updated_on',
	resolved_on	=>	'resolved_on',
	count		=>	'count',
	deleted		=>	'deleted',
	online		=>	'online',
	type_id		=>	'type_id',
	type			=>	undef,
	offline_seconds	=>	'offline_seconds',
	state_changed_on	=>	'state_changed_on',
	notified			=>	'notified',
	location_id			=>	'location_id',
);
%find_fields = (
	type	=>	'(SELECT name FROM Host_types WHERE host_types.id=type_id)',
	mac	=>	'(SELECT mac FROM host_interfaces WHERE host_id=hosts.id)',
	ip	=>	'(SELECT ip FROM host_interfaces WHERE host_id=hosts.id)',
);
%transforms = (
	id			=>	[ 's/\D//g' ],
	hostname	=>	[ 's/\s//g' ],
	description	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	'blacklist'	=>	0,
	'whitelist'	=>	0,
	'monitored'	=>	0,
	'hostname'	=>	undef,
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	resolved_on		=>	undef,
	'count'		=>	0,
	'deleted'	=>	0,
	'online'	=>	undef,
	'type_id'	=>	undef,
	'state_changed_on'	=>	undef,
	'offline_seconds'	=>	undef,
	'notified'=>	0,
	location_id		=>	undef,
);

sub destroy {
	my $error;
	require openprint::Log;
	foreach my $Log ( openprint::Log->find('host_id'=>$_[0]{'id'}) ) {
		$error .= $Log->destroy();
		return $error if $error;
	} # end foreach Log
	foreach my $N ( $_->Notifications() ) {
		$error .= $N->destroy();
		return $error if $error;
	} # end foreach Log
	foreach my $I ( $_->Interfaces() ) {
		$error .= $I->destroy();
		return $error if $error;
	} # end foreach Log

	$error .= $_[0]->SUPER::destroy();
	return $error;
} # end sub destroy

sub ping {
	require Net::Ping;
	my $p = Net::Ping->new();
	my $rc = $p->ping($_[0]{'ip'});
	$p->close();
	return $rc;
} # end sub ping

sub Type {
	return new openprint::Host_Type( $_[0]{type_id} );
} # end sub Type

sub type {
	if ( @_ > 1 ) {
		my $Type = openprint::Host_Type->find_one('name lc'=> lc openprint::Host_Type->transform('name',$_[1]) );
		if ( ! $Type ) {
			$Type = new openprint::Host_Type();
			$Type->save({name=>$_[1]});
		} # end if
		$_[0]{type_id} = $Type->id();
		$_[0]{type} = $Type->name();
	} # end if @_ > 1
	if ( ! $_[0]{type} ) {
		$_[0]{type} = new openprint::Host_Type( $_[0]{type_id} )->name();
	} # end if
	return $_[0]{type};
} # end sub type

sub Assets {
	require openprint::Object_Asset;
	if ( $_[1] ) {
		$_[1]{'object_id'} = $_[0]{'id'};
		$_[1]{'object_type'} = 'openprint::Host';
		$_[1]{'order'} = 'created_on' if ! $_[1]{'order'};

		return openprint::Object_Asset->find(%{$_[1]});
	} # end if

	if ( ! defined $_[0]{'Assets'} ) {
		@{$_[0]{'Assets'}} = openprint::Object_Asset->find(
				'object_type'	=>	'openprint::Host',
				'object_id'		=>	$_[0]{'id'}, 
				'order'			=>	'created_on'
				);
	} # end if
	return @{$_[0]{'Assets'}};
} # end sub Assets

sub Notifications {
	if ( ! $_[0]{'Notifications'} ) {
		@{$_[0]{'Notifications'}} = openprint::Host_Notification->find(
				'host_id'	=>	$_[0]{'id'},
				);
				#'order' => 'lower(strfirstName),lower(strlastname)' );
	} # end if
	return @{$_[0]{'Notifications'}};
} # end sub Notifications
sub Interfaces {
	if ( ! $_[0]{Interfaces} ) {
		@{$_[0]{Interfaces}} = openprint::Host_Interface->find(
				host_id	=>	$_[0]{id},
				order	=>	'mac',
				);
	} # end if
	return @{$_[0]{Interfaces}};
} # end sub Notifications

sub info {
	if ( ! $_[0]{Info} ) {
		%{$_[0]{Info}} = map { $_->name(), $_ } openprint::Host_Info->find(host_id=>$_[0]{id});
		foreach my $k ( keys %{$_[0]{Info}} ) {
			$openprint::log->debug(" $k => " . $_[0]{Info}{$k}->value() );
		} # end foreach
	} # end if
	if ( $_[0]{Info}{$_[1]} ) {
		return $_[0]{Info}{$_[1]}->value();
	} # end if
$openprint::log->debug("No value for $_[1] " . $_[0]->to_string() );
		foreach my $k ( keys %{$_[0]{Info}} ) {
			$openprint::log->debug(" $k => " . $_[0]{Info}{$k}->value() );
		} # end foreach
	return '';
} # end sub info

sub Location {
	require openprint::Location;
	return new openprint::Location( $_[0]{location_id} );
} # end sub Location

sub resolve {
	foreach my $Interface (  $_[0]->Interfaces() ) {
		my $hostname = $Interface->resolve();
		return $hostname if $hostname;
	} # end foreach Interface
	return undef;
} # end sub resolve

sub reboot {
	my $Host = $_[0];
	require LWP;
	my $browser = LWP::UserAgent->new();
	my $response = $browser->get('http://'.$Host->hostname().'/');
	$openprint::log->debug( $response->status_line );
	$openprint::log->debug( $response->content );
	my $headers = $response->headers();
	foreach my $k ( keys %$headers ) {
		$openprint::log->debug("Initial Header $k => $$headers{$k}");
	}  # end foreach
	my ( $auth, $tokens ) = $$headers{'www-authenticate'} =~ /(\w+)\s+(.*)/;
	$tokens =~ s/"//g;	
	my %tokens = map { split('=', $_ ) } split(/\s/, $tokens);
	$browser->credentials( $Host->hostname().':80', $tokens{realm}, $Host->info('username'), $Host->info('password') );
	my $url;
	if ( sets::isin( $_[0]->type(), [ 'AIC500', 'AIC500W', 'AIC777W', 'AIC747W' ] ) ) {
		$url = 'http://'.$Host->hostname().'/admin/reboot.cgi?type=0';
	} elsif( $_[0]->type() eq 'D-Link DAP1522' ) {
		$url = 'http://'.$Host->hostname().'/sys_cfg_valid.xgi?&exeshell=submit REBOOT';
	} else {
		$openprint::log->error("Unknown host type $_[0]{type}");
		return 0;
	} # end if

	$openprint::log->debug("URL: $url" );
	$response = $browser->get($url);

	if ( ! $response->is_success ) {
		$openprint::log->error( $response->content );
		if ( $response->status_line() eq '401 Unauthorized' or $response->status_line() eq '401 Not Authorized' ) {
			$openprint::log->error("Couldn't get content from $url unauthorized trying again:". $response->status_line );
			$response = $browser->get($url);
			if ( $response->status_line() eq '401 Unauthorized' or $response->status_line() eq '401 Not Authorized' ) {
				$openprint::log->error("Couldn't get content from $url unauthorized:". $response->status_line );
				my $headers = $response->headers();
				foreach my $k ( keys %$headers ) {
					$openprint::log->error("Header $k => $$headers{$k}");
				}  # end foreach
				$openprint::log->error( $response->content );
				return 0;
			} else {
				$openprint::log->debug("Response after second attempt: " . $response->status_line );
			} # end if
		} else {
			$openprint::log->warn("Couldn't get content from $url rebooting" . $response->status_line );
			my $headers = $response->headers();
			foreach my $k ( keys %$headers ) {
				$openprint::log->error("Header $k => $$headers{$k}");
			}  # end foreach
			return 0;
		} # end if
	} # end if

	(new openprint::Log())->save({ action=>'Host rebooted', host_id=>$Host->id(), note=>sprintf('<a href="/employee/it/host.html?host_id=%d">%s</a> has been rebooted.', @$Host{'id','hostname'})});
	if ( 0 ) {
		my @To = map { $_->User() } $Host->Notifications();
		if ( @To and ( @To < 10 ) ) {
			$openprint::log->debug("Emailing: " . join(',', map { $_->email() } @To ) );
			my $results = (new openprint::Email())->send(
					TO    =>  \@To,
					SUBJECT   =>  'Camera rebooted ' . $Host->hostname(),
					FROM      =>  $openprint::config{'TechSupportEmail'},
					BODY      =>  "

					Description: $$Host{description}
					",
					);
		} else {
			$openprint::log->error("No To or too many @To");
		} # end if TO
	} # end if 0
	return 1;
} # end sub reboot

sub link_to {
	return sprintf('<a href="/employee/it/host.html?host_id=%d">%s</a>', $_[0]->id(), $_[0]->hostname() );
}

1;
__END__
