use strict;
package openprint::Feed;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'feeds';
$serial = 'feeds_id_seq';

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'type'			=>	'type',
	'url'			=>	'url',
	'company_id'	=>	'company_id',
);

%defaults = (
	'company_id'	=>	q`$openprint::session{'company_id'}`,
);

1;
__END__
