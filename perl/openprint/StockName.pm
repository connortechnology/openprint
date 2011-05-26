package openprint::StockName;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $table $serial %fields %transforms %defaults );

$table = 'papernames';
$serial= 'papername_id_seq';
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
	shift if $_[0] eq 'openprint::StockName';
	return sort { $$a{'shortname'} cmp $$b{'shortname'} } @_;
}# end sub sort
1;
__END__
