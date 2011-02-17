use strict;
package openprint::News;
our @ISA = qw( openprint::Object );

use vars qw( $table $serial %fields %transforms %defaults );

$table = 'news';
$serial = 'news_id_seq';
%fields = (
	'id'	=>	'id',
	'created_on'	=>	'created_on',
	'owner_id'		=>	'owner_id',
	'creator_id'	=>	'creator_id',
	'source_id'		=>	'source_id',
	'source_type'	=>	'source_type',
	'description'	=>	'description',
);

%defaults = (
	'created_on'	=>	q`'NOW()'`,
);
