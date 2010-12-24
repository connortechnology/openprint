use strict;
package openprint::Blacklist;
our @ISA = qw(openprint::Object);
require openprint::Object;
require openprint::Host;

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );

$debug = 1;
$serial = 'blacklist_id_seq';
$table = 'blacklist';

%fields = (
	'id'			=>	'id',
	'ip'			=>	'ip',
	'count'			=>	'count',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'host_id'		=>	'host_id',
	'mac'			=>	undef,
);
%find_fields = (
	'mac'			=>	'SELECT mac FROM hosts WHERE hosts.id = blacklist.host_id',
	'hostname'		=>	'(SELECT hostname FROM hosts WHERE hosts.id = blacklist.host_id)',
);

%transforms = (
);

%defaults = (
	'ip'		=>	undef,
	'host_id'	=>	undef,
);

sub mac {
	my $Host = $_[0]->Host();
	if ( @_ > 1 ) {
		$Host->save({'mac'=>[$_[1]]});
	} # end if
	return $Host->mac();
} # end sub mac

sub Host {
	if ( ! $_[0]{'host_id'} ) {
		my $Host;
		if ( $_[0]{'ip'} ) {
			$Host = openprint::Host->find_one('ip'=>$_[0]{'ip'});
		} else {
			# if no ip address, then we are saving based on a mac.  So create a host entry, which will be filled in later.
			$Host = new openprint::Host();
			$Host->save();
		} # end if
		if ( ! $Host ) {
			$Host = new openprint::Host();
			$Host->save({'ip'=>$_[0]{'ip'}});
		} # endif	
		$_[0]->save({'host_id'=>$Host->id()});
	} # end if
		
	return new openprint::Host( $_[0]{'host_id'} );
} # end sub Host

1;
__END__
