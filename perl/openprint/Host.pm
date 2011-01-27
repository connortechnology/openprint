use strict;
package openprint::Host;
our @ISA = qw( openprint::Object );
require openprint::Object;
use Net::ARP;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'hosts';
$serial = 'hosts_id_seq';
%fields = (
	'id'			=>	'id',
	'ip'			=>	'ip',
	'hostname'		=>	'hostname',
	'mac'			=>	'mac',	
	'blacklist'		=>	'blacklist',
	'whitelist'		=>	'whitelist',
	'monitor'		=>	'monitor',
	'description'	=>	'description',
	'dhcp'			=>	'dhcp',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'count'			=>	'count',
);
%transforms = (
);
%defaults = (
	'blacklist'	=>	0,
	'whitelist'	=>	0,
	'monitor'	=>	0,
	'mac'		=>	undef,
	'hostname'	=>	'undef',
	'ip'		=>	undef,
	'dhcp'		=>	0,
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'count'		=>	undef,
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
	my $mac = Net::ARP::arp_lookup( 'eth1', $$self{'ip'} );
$openprint::log->debug("Mac: $mac");
	return $mac;
} # end sub get_mac

1;
__END__
