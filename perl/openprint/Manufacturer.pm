package openprint::Manufacturer;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use vars qw( $table $serial %fields %transforms %defaults );

$table = 'manufacturers';
$serial= 'manufacturers_id_seq';
%fields = (
    'id'    =>  'id',
    'name' =>  'name',
);
%transforms = (
    'name' => [ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
);

1;
__END__
