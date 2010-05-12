#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sets;

print "testing max_index...\n";
my $max_index = sets::max_index( 1, 2, 200, 3, 4, 5 );
if ( $max_index != 2 ) {
  print "Error: sets::max_index returned $max_index instead of 2.\n";
} else {
	print "Success!\n";
} # end if

my $max_index = sets::max_index( [ 1, 2, 3, 200, 4, 5 ] );
if ( $max_index != 3 ) {
  print "Error: sets::max_index returned $max_index instead of 3.\n";
} else {
	print "Success!\n";
} # end if

1;
__END__
