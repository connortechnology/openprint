use strict;
package openprint::Blacklist;
our @ISA = qw(openprint::Object);
require openprint::Object;
require openprint::Host;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;

$table = 'blacklist';
$serial = '';

%fields = (
	'id'			=>	'ip',
	'ip'			=>	'ip',
	'count'			=>	'count',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'host_id'		=>	'host_id',
);

%transforms = (
);

%defaults = (
	'host_id'	=>	undef,
);

sub Host {
	if ( ! $_[0]{'host_id'} ) {
		my $Host = openprint::Host->find_one('ip'=>$_[0]{'ip'});
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
