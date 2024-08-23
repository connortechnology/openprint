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
    q`^\[\w{3} \w{3} [ .:0-9]+\] \[ssl:warn\] \[pid [0-9]+\] AH[[:digit:]]{5}: Init: Name\-based SSL virtual hosts only work for clients with TLS server name indication support \(RFC 4366\)$`,
    q`^\[\w{3} \w{3} [ .:0-9]+\] \[mpm_(event|prefork):notice\] \[pid [0-9]+(:tid [0-9]+)?\] AH[[:digit:]]{5}: Apache\/[.[:digit:]]+ \(Ubuntu\) (mod_fcgid\/2\.3\.9 )?( PHP\/[.[:alnum:]-]+ )?(OpenSSL\/[.[:alnum:]]+ )?mod_apreq2\-[[:digit:].\/]+ mod_perl\/[\.[:digit:]]+ Perl\/v[\.[:digit:]]+ configured \-\- resuming normal operations$`,
    q`^\[\w{3} \w{3} [ .:0-9]+\] \[mpm_prefork:notice\] \[pid [0-9]+\] AH[[:digit:]]{5}: caught SIGTERM, shutting down$`,
		q`^\[\w{3} \w{3} [ .:0-9]{23}\] \[core:notice\] \[pid [0-9]+(:tid [0-9]+)?\] AH[[:digit:]]{5}: Command line: '\/usr\/sbin\/apache2'$`,
		q`^\[\w{3} \w{3} [ .:0-9]{23}\] \[(core|mpm_prefork):notice\] \[pid [0-9]+\] AH[[:digit:]]{5}: Graceful restart requested, doing restart$`,
		q`^\[\w{3} \w{3} [ .:0-9]{23}\] \[authz_core:debug\] \[pid [0-9]+(:tid [0-9]+)?\] mod_authz_core.c\([[:digit:]]+\): \[client [.[:digit:]:]+\] AH[[:digit:]]{5}: authorization result of (Require all granted|<RequireAny>): granted`,
		q`^\[\w{3} \w{3} [ .:0-9]{23}\] \[deflate:debug\] \[pid [0-9]+(:tid [0-9]+)?\]`,
		q`^\[\w{3} \w{3} [ .:0-9]{23}\] \[perl:debug\]`,
		q`^\[\w{3} \w{3} [ .:0-9]{23}\] \[:?debug]`,
		q`^\[\w{3} \w{3}  ?[0-9]{1,2} [:0-9]{8} \w+ \d{4}\] \[debug\]`,
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
