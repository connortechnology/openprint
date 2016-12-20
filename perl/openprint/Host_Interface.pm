use strict;
require openprint::Object;
require openprint::Host;

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
    connected_to  =>  'connected_to',
	monitor			=>	'monitor',
	online			=>	'online',
);
%transforms = (
	mac         	=>    [ 's/[^\da-fA-F:\-]//g' ],
	connected_to	=>    [ 's/[^\da-fA-F:\-]//g' ],
	ip          	=>    [ 's/[^\d\.\:a-fA-F]//g' ],
);

%find_fields = (
	whitelist	=>	'(SELECT whitelist FROM Hosts WHERE Hosts.id=host_id)',
);
%defaults	= (
	dhcp		=>	0,
	ip			=>	undef,
	mac			=>	undef,
  connected_to  =>  undef,
	monitor		=>	0,
	online		=>	undef,
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

	my ( $subnet ) = $$self{ip} =~ /^(\d+\.\d+\.\d+)\.\d+$/;

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
		my $mac = Net::ARP::arp_lookup( $use_iface, $$self{ip} );
		$openprint::log->debug("Mac: $mac");
		return $mac;
	} else {
		$openprint::log->debug("Unable to determine interface");
	} # end if
} # end sub get_mac

sub authenticate {
	my ( $HI, $browser, $response, $method, $port, $url, $args ) = @_;
	my $headers = $response->headers();
	if ( $$headers{'www-authenticate'} ) {
$openprint::log->debug("Having authenticate $$headers{'www-authenticate'}");

		my ( $auth, $tokens ) = $$headers{'www-authenticate'} =~ /^(\w+)\s+(.*)$/;
		my %tokens = map { /(\w+)="?([^"]+)"?/i } split(', ', $tokens );
		if ( $tokens{realm} ) {
			my $Host = $HI->Host();
			my $username = $Host->info('username');
			my $password = $Host->info('password');
			$openprint::log->debug("tokens: $tokens realm: $tokens{realm} username: $username password: $password ");
			$browser->credentials( $HI->ip().':'.$port, $tokens{realm}, $username, $password );
			$response = $browser->$method( $url, $args ? $args : () );
$openprint::log->debug("Auth response for $method $url $tokens{realm}, $username, $password " . $response->is_success );
		} else {
			$openprint::log->error("No realm");
		} # end if
	} else {
		foreach my $k ( keys %{$headers} ) {
			$openprint::log->debug("No auth Header $k => $$headers{$k}");
		}
	}
	return $response;
} # end sub authenticate

1;
__END__
