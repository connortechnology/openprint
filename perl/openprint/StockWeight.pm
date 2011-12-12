use strict;
package openprint::StockWeight;
our @ISA = qw(openprint::Object);

use vars qw( $table $serial %fields %transforms %defaults );

$table = 'stockweights';
$serial= 'stockweights_id_seq';
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
	shift if $_[0] eq 'openprint::StockWeight';
$openprint::log->debug("Sorting Weight");
	return sort { 
		my $a_name = $$a{'name'};
		$a_name =~ s/\D//g;
		my $b_name = $$b{'name'};
		$b_name =~ s/\D//g;
	
		$a_name <=> $b_name } @_;
}# end sub sort

1;
__END__
