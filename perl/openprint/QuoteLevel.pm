package openprint::QuoteLevel;
@ISA = qw(openprint::Object);

use strict;

require sql;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'quotelevels';
$serial = 'quotelevels_id_seq';

%fields = ( 
	'id'	=>	'id',
	'name'=>'name',
 );
%transforms = ();
%defaults = ();

1;
__END__
