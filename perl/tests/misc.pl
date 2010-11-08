#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;
use misc;
# test add_delta_business_days 

my @friday = ( 2010, 11, 5 );
my @should_be_friday = misc::add_delta_business_days( @friday, 0 );
if ( $should_be_friday[2] != 5 ) {
	die "Adding 0 did not work.";
} # end if
my @should_be_monday = misc::add_delta_business_days( @friday, 1 );
if ( $should_be_monday[2] != 8 ) {
	die "Adding 1 did not work. Day is ";
} # end if

1;
__END__

