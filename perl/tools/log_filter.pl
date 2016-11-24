#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;

use File::Basename qw(basename);
use Getopt::Long ();

my $program = basename($0);

my $opts = {};
Getopt::Long::GetOptions($opts, 'help', 'debug' );

if ($opts->{help}) {
	usage();
	exit 0;
} # end if

my @whitelist = (
        q`^\[\w{3} \w{3} [ .:0-9]+\] \[mpm_prefork:notice\] \[pid [0-9]+\] AH[[:digit:]]{5}: Apache\/2\.4\.18 \(Ubuntu\) (mod_fcgid\/2\.3\.9 )?OpenSSL\/1\.0\.2g mod_apreq2-20090110\/2\.8\.0 mod_perl\/2\.0\.9 Perl\/v5\.22\.1 configured \-\- resuming normal operations$`,
        q`^\[\w{3} \w{3} [ .:0-9]+\] \[mpm_prefork:notice\] \[pid [0-9]+\] AH[[:digit:]]{5}: caught SIGTERM, shutting down$`,
		q`^\[\w{3} \w{3} [ .:0-9]{23}\] \[core:notice\] \[pid [0-9]+\] AH[[:digit:]]{5}: Command line: '\/usr\/sbin\/apache2'$`,
		q`^QFont::setPixelSize: Pixel size <= 0 \(0\)`,
);
 

while (<>) {
	my $input = $_;
	my $whitelisted = 0;
	#print $input if $$opts{debug};
	foreach my $line ( @whitelist ) {
		print "testing $line " if $$opts{debug};
		if ( $input =~ /$line/ ) {
			print "matched\n" if $$opts{debug};;
			$whitelisted = 1;
			# Is whitelisted
			last;
		} else {
			print "not matched\n" if $$opts{debug};;
		}
	} # end foreach
	if ( ! $whitelisted ) {
		print $input;
	}

} # end while input

sub usage {
	print <<EOH;

usage: log-filter.pl < input [--help] 

The purpose of this script is to filter out good lines from log files leaving the dubious messages behind

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

1;
__END__
