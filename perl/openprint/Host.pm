use strict;
package openprint::Host;
our @ISA = qw( openprint::Object );
require openprint::Object;
use Net::ARP;
use Net::Ping;
use IO::Interface::Simple;
use strict;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'hosts';
$serial = 'hosts_id_seq';
%fields = (
	'id'			=>	'id',
	'ip'			=>	'ip',
	'hostname'		=>	'hostname',
	'mac'			=>	'mac',	
	'blacklist'		=>	'blacklist',
	'whitelist'		=>	'whitelist',
	'monitored'		=>	'monitored',
	'description'	=>	'description',
	'dhcp'			=>	'dhcp',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'count'			=>	'count',
	'deleted'		=>	'deleted',
	'online'		=>	'online',
);
%transforms = (
);
%defaults = (
	'blacklist'	=>	0,
	'whitelist'	=>	0,
	'monitored'	=>	0,
	'mac'		=>	undef,
	'hostname'	=>	'undef',
	'ip'		=>	undef,
	'dhcp'		=>	0,
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'count'		=>	undef,
	'deleted'	=>	0,
	'online'	=>	undef,
);
sub resolve {
	my ( $self ) = @_;
	my @h = gethostbyaddr(pack('C4',split('\.',$$self{'ip'})),2);
	if ( @h ) {
		return $h[0];
	} elsif ( $debug ) {
		$openprint::log->warn("Unable to reverse DNS $$self{'ip'}");
	} # end if
	return undef;
} # end sub resolve

sub get_mac {
	my ( $self ) = @_;

	my ( $subnet ) = $$self{'ip'} =~ /^(\d+\.\d+\.\d+)\.\d+$/;

	my $use_iface;

	foreach my $iface ( IO::Interface::Simple->interfaces ) {
$openprint::log->debug("Looking at $iface. " . $iface->address . ', subnet: ' . $subnet );
		if ( $iface->address =~ /^$subnet\.\d+$/ ) {
			$use_iface = $iface;
		} # end if
	}

	if ( $use_iface ) {
		my $mac = Net::ARP::arp_lookup( $use_iface, $$self{'ip'} );
		$openprint::log->debug("Mac: $mac");
		return $mac;
	} else {
		$openprint::log->debug("Unable to determine interface");
	} # end if
} # end sub get_mac

sub destroy {
	my $error;
	foreach my $Log ( openprint::Log->find('host_id'=>$_[0]{'id'}) ) {
		$error .= $Log->destroy();
		return $error if $error;
	} # end foreach Log
	$error .= $_[0]->SUPER::destroy();
	return $error;
} # end sub destroy

sub ping {
	my $p = Net::Ping->new();
	my $rc = $p->ping($_[0]{'ip'});
	$p->close();
	return $rc;
} # end sub ping

1;
__END__
