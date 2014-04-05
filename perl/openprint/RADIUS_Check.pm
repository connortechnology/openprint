use strict;
package openprint::RADIUS_Check;
our @ISA = qw(openprint::Object);
use vars qw( $debug %fields %transforms %defaults $table $serial $dbh );
use vars qw( %attributes );


$debug = 0;
$table = 'radcheck';
$serial = 'radcheck_id_seq';
%fields = (
	id			=>	'id',
	username	=>	'username',
	attribute	=>	'attribute',
	op			=>	'op',
	value		=>	'value',
);

%attributes = (
	'Cleartext-Password'	=>	'Cleartext Password', 
);

1;
__END__
