package openprint::StockBrand;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $table $serial %fields %transforms %defaults );

$table = 'stocknames';
$serial= 'stockname_id_seq';
%fields = (
    'id'    =>  'id',
    'name' =>  'name',
);
%transforms = (
    'name' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
);

sub sort {
	shift if $_[0] eq 'openprint::StockBrand';
	return sort { $$a{'name'} cmp $$b{'name'} } @_;
}# end sub sort
1;
__END__
