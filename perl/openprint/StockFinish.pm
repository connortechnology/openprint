use strict;
package openprint::StockFinish;
our @ISA = qw(openprint::Object);
use openprint ();

use vars qw( $table $serial %fields %transforms %defaults );

$table = 'paperfinishes';
$serial= 'paperfinish_id_seq';
%fields = (
	'id'	=>	'id',
	'shortname'	=>	'shortname',
	'longname'	=>	'longname',
);
%transforms = (
	'shortname' => [ 's/^\s+//', 's/\s+$//' ],
	'longname' => [ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
);

sub sort {
	shift if $_[0] eq 'openprint::StockFinish';
$openprint::log->debug("Sorting Finish");
	return sort { $$a{'shortname'} cmp $$b{'shortname'} } @_;
}# end sub sort

sub name {
	return $_[0]{'shortname'};
}

1;
__END__
