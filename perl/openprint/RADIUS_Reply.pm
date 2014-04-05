use strict;
package openprint::RADIUS_Reply;
our @ISA = qw(openprint::Object);
use vars qw( $debug %fields %transforms %defaults $table $serial $dbh );
use vars qw( %attributes );


$debug = 0;
$table = 'radreply';
$serial = 'radreply_id_seq';
%fields = (
	id			=>	'id',
	username	=>	'username',
	attribute	=>	'attribute',
	op			=>	'op',
	value		=>	'value',
);

%attributes = (
	'Framed-IP-Address'		=>	'IP Address',
	'Framed-Route'			=>	'Router',
);

1;
__END__
