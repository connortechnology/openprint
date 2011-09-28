use strict;
package openprint::RADIUS_Check;
our @ISA = qw(openprint::Object);
use vars qw( $debug %fields %transforms %defaults $table $serial $dbh );

$debug=0;
$table = 'radcheck';
$serial = 'radcheck_id_seq';
%fields = (
	'id'	=>	'id',
	'username'	=>	'username',
	'attribute'	=>	'attribute',
	'op'		=>	'op',
	'value'		=>	'value',
);

1;
__END__
