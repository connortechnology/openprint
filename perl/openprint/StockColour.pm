use strict;
package openprint::StockColour;
our @ISA = qw(openprint::Object);

use vars qw( $table $serial %fields %transforms %defaults );

$table = 'papercolours';
$serial= 'papercolour_id_seq';
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

sub sort {
	shift if $_[0] eq 'openprint::StockColour';
	return sort { $$a{'shortname'} cmp $$b{'shortname'} } @_;
}# end sub sort

sub name {
	return $_[0]{'shortname'};
} # end sub name
1;
__END__
