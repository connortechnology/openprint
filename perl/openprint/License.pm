use strict;
package openprint::License;
our @ISA = qw(openprint::Object);

require openprint::License_Host;
require openprint::Software;

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );
$debug = 0;
$table = 'licenses';
$serial='licenses_id_seq';
%fields = (
		id			=>	'id',
		serialkey	=>	'serialkey',
		max_uses		=> 'max_uses',
		purchased_on	=>	'purchased_on',
		expires_on		=>	'expires_on',
		software_id		=>	'software_id',
		software		=>	undef,
		comment         =>	'comment',
		created_on		=>	'created_on',
		updated_on		=>	'updated_on',
		);
%find_fields = (
	host_id	=>	'id IN (SELECT license_id FROM license_hosts where host_id=?)',
);
%transforms = (
		serialkey	=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
		comment		=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
		);
%defaults = (
	created_on	=>	q`'NOW'`,
	updated_on	=>	q`'NOW'`,
	serialkey	=>	undef,
	max_uses	=>	1,
	purchased_on	=>	undef,
	expires_on		=>	undef,
	software_id		=>	undef,
);
sub software {
	if ( @_ > 1 ) {
		my $Software = openprint::Software->find_one('name lc'=> lc openprint::Software->transform('name',$_[1]) );
		if ( ! $Software ) {
			$Software = new openprint::Software();
			$Software->save({name=>$_[1]});
		} # end if
		$_[0]{software_id} = $Software->id();
		$_[0]{software} = $Software->name();
	}
	if ( ! $_[0]{software} ) {
		$_[0]{software} = new openprint::Software( $_[0]{software_id} )->name();
	} # end if
	return $_[0]{software};
} # end sub software

sub Hosts {
	return map { $_->Host() } openprint::License_Host->find(license_id=>$_[0]{id});
} # end sub Hosts

1;
__END__
