use strict;
use openprint;

package pagination;

sub defaults {
	my ( $uri ) = @_;
	$openprint::session{$uri.'?paging_per_page'} = 5;
	$openprint::session{$uri.'?paging_page'} = 0;
} # end sub defaults

1;
__END__
