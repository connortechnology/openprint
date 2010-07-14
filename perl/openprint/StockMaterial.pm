package openprint::StockMaterial;
@ISA = qw(openprint::Object);

use strict;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'StockMaterials';
$serial= 'stockmaterials_id_seq';
%fields = ( 'name'=>'name' );
%transforms = ();
%defaults = ();

1;
__END__
