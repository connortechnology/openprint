#!/usr/bin/perl
use strict;
use warnings;

use IPC::Open2;

use constant AGENT => '/opt/Promise/WebPAMPRO/Agent/bin/cliib';

if ( ! -e AGENT ) {
	die "Agent does not exist.";
}

my ( $in, $out );
my $pid = open2( $out, $in, AGENT ) or die "Can't run " . AGENT. " $!";

print $in, "smart -a list -v\n";

while( <$out> ) {
	print $_;
}

print $in "exit\n";

waitpid($pid, 0);


1;
__END__
