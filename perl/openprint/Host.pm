package openprint::Host;
@ISA = qw( openprint::Object );
require openprint::Object;
use Net::ARP;
use strict;

my $debug = 1;
use vars qw( $log $dbh $table $serial %fields %transforms %defaults %types );
$table = 'hosts';
$serial = 'hosts_id_seq';
%fields = (
	'id'	=>	'id',
	'ip'	=>	'ip',
	'hostname'		=>	'hostname',
	'mac'	=>	'mac',	
	'block'	=>	'block',
	'description'	=>	'description',
);
%transforms = (
);
%defaults = (
	'block'	=>	0,
	'mac'	=>	undef,
	'hostname'	=>	undef,
);
use openprint ();
*log = \$openprint::log;
*dbh = \$openprint::dbh;

sub resolve {
	my ( $self ) = @_;
	my @h = gethostbyaddr(pack('C4',split('\.',$$self{'ip'})),2);
	if ( @h ) {
		return $h[0];
	} elsif ( $debug ) {
		$log->warn("Unable to reverse DNS $$self{'ip'}");
	} # end if
	return undef;
} # end sub resolve

sub get_mac {
	my ( $self ) = @_;
	my $mac = Net::ARP::arp_lookup( 'eth1', $$self{'ip'} );
$log->debug("Mac: $mac");
	return $mac;
} # end sub get_mac

1;
__END__
