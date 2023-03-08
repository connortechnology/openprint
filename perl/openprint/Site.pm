use strict;
package openprint::Site;
our @ISA = qw( openprint::Object );
require openprint::Object;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'sites';
$serial = 'sites_id_seq';

%fields = (
	id	        =>	'id',
	company_id	=>	'company_id',
	name      	=>	'name',
  created_on  => 'created_on',
  updated_on  => 'updated_on',
  deleted     => 'deleted',
);
%transforms = (
);
%defaults = (
	created_on			=>	q`'NOW()'`,
	updated_on			=>	q`'NOW()'`,
  deleted         =>  0,
);

1;
__END__
