package openprint::StockWeight;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $table $serial %fields %transforms %defaults );

$table = 'paperweights';
$serial= 'paperweight_id_seq';
%fields = (
    'id'    =>  'id',
    'shortname' =>  'shortname',
    'longname'  =>  'longname',
);
%transforms = (
    'shortname' => [ 's/^\s+//', 's/\s+$//' ],
    'longname' => [ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
);

1;
__END__
