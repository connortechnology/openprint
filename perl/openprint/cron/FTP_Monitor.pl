#!/usr/bin/perl -w
use lib qw( /etc/apache2/lib/perl );
use Linux::Inotify2;

use strict;

require sets;
my $source_path = $ARGV[0];

my $inotify = new Linux::Inotify2;
if ( $inotify and $inotify->watch( $source_path, IN_CREATE ) ) {
	while () {
		my @events = $inotify->read;
		if ( ! @events ) {
			print "Read error";
		} # end if

printf "mask\t%d\n", $_->mask foreach @events;
		
	} # end while
} # end if notify

1;
__END__


