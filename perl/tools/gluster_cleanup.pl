#!/usr/bin/perl -w
use strict;

my $brick = '';

foreach my $line ( `gluster volume heal 48TB info` ) {
	chomp $line;
	print $line;
	if ( $line =~ /^<gfid:([a-f0-9]{2})([a-f0-9]{2})([a-f0-9\-]+)>/ ) {

		my $file = "$brick/.glusterfs/$1/$2/$1$2$3";
		if ( -e $file ) {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
					$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
			if ( $nlink == 1 ) {
				print " Orphaned: delete.";
				unlink $file;
			} else {
				print " ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks)";
			}
		} else {
			print "$file does not exist at $file";
		}
	} elsif ( $line =~ /Brick ([[:alnum:]]+):([\/[:alnum:]]+)/ ) {
		$brick = $2;
	} else {
		print " no match";
	}
	print "\n";
}
