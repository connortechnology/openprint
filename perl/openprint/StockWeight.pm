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

sub sort_value {
	if ( ! exists $_[0]{'sort_value'} ) {
		$_[0]{'sort_value'} = $_[0]{'shortname'};
		$_[0]{'sort_value'} =~ s/[^\-\d\.]//g;
	} # end if
	return $_[0]{'sort_value'};
} # end sub sort_value

sub sort {
	shift if $_[0] eq 'openprint::StockWeight';
	return sort { $a->sort_value() <=> $b->sort_value() } @_;
} # end sub sort

sub name {
	$_[0]{'shortname'};
} # end sub name

1;
__END__
