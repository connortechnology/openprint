package openprint::StockGroup;
@ISA = qw(openprint::Object);

use strict;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'stockgroups';
$serial = 'stockgroups_id_seq';

%fields = ( 
	'id'	=>	'id',
	'name'=>'name',
);
%transforms = ();
%defaults = ();

1;
__END__
