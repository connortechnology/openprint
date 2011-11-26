use strict;
require openprint::Object;
require openprint::Object_Asset;
use Net::ARP;
use Net::Ping;
use IO::Interface::Simple;

package openprint::Host_Notification;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table @identified_by %fields %transforms %defaults );
$debug = 1;
$table = 'host_notifications';
@identified_by = ( 'host_id','user_id' );

%fields = (
	'host_id'			=>	'host_id',
	'user_id'			=>	'user_id',
);

package openprint::Host_Type;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table $serial %fields %transforms %defaults %types );
$debug = 1;
$table = 'host_types';
$serial = 'host_types_id_seq';
%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
);
%transforms = (
    'name'  =>  [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);

package openprint::Host;
our @ISA = qw( openprint::Object );

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
	'type_id'		=>	'type_id',
	'type'			=>	undef,
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
	'type_id'	=>	undef,
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

sub Type {
	return new openprint::Host_Type( $_[0]{type_id} );
} # end sub Type

sub type {
$openprint::log->debug("type: @_");
	if ( @_ > 1 ) {
		my $Type = openprint::Host_Type->find_one('name lc'=> lc $_[1] );
		if ( ! $Type ) {
			$Type = new openprint::Host_Type();
			$Type->save({'name'=>$_[1]});
		} # end if
		$_[0]{'type_id'} = $Type->id();
		$_[0]{'type'} = $Type->name();
	}
	if ( ! exists $_[0]{'type'} ) {
		$_[0]{'type'} = new openprint::Host_Type( $_[0]{'type_id'} )->name();
	} # end if
	return $_[0]{'type'};
} # end sub type

sub Assets {
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

1;
__END__
