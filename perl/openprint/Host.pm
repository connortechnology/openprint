package openprint::Host;
@ISA = qw( openprint::Object );
require openprint::Object;
use strict;

my $debug = 1;
use vars qw( $log $dbh $table $serial %fields %tansforms %defaults %types );
$table = 'hosts';
$serial = 'hosts_id_seq';
%fields = (
	'id'	=>	'id',
	'ip'	=>	'ip',
	'hostname'		=>	'hostname',
	'mac'	=>	'mac',	
	'block'	=>	'block',
);
%defaults = (
	'block'	=>	0,
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
	return;
} # end sub resolve

1;
__END__
