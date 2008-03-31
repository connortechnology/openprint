#!/usr/bin/perl -w
use lib qw( /etc/apache2/lib/perl );
use Linux::Inotify2;

use strict;

require sets;
my $source_path = $ARGV[0];
my $dest_path = $ARGV[1];

my $inotify = new Linux::Inotify2;
if ( 0 and $inotify and $inotify->watch( $source_path, IN_CREATE ) ) {
	while () {
		my @events = $inotify->read;
		if ( ! @events ) {
			print "Read error";
		} # end if
printf "mask\t%d\n", $_->mask foreach @events;
		
} # end while
} else {
# Command Line Params: 
# 1. Hot Folder to monitor
# 2.  Dest HotFolder
my @filenames;
if ( opendir DIRHANDLE, $source_path ) {
	@filenames = readdir DIRHANDLE;
	closedir DIRHANDLE;
} # end if

foreach my $file ( @filenames ) {
	# Will ignore ., .., any hidden file
	next if $file =~ /^\./; 
	if ( $file =~ /(.*)B\.(ppf)$/i ) {
		my $file_base = $1;
		my $extension = $2;
		my  $out_base = $file_base;
		$out_base =~ s/\./_/g;

		if ( sets::isin( $file_base.'A.'.$extension, @filenames ) ) {
			my @Back;
			if ( ! open ( FH, '< ' . $source_path.'/'.$file_base.'B.'.$extension ) ) {
				print "Error opening " . $source_path.'/'.$file_base."B.$extension\n" ;
				next;
			} # end if

			my $back_flag = 0;	
			while ( <FH> ) {
				$back_flag = 1 if ( $_ =~ /CIP3BeginBack/ );
				push @Back, $_ if ( $back_flag );
				last if $_ =~ /CIPEndBack/;
			} # end while
			close( FH );
			if ( ! @Back ) {
				print "No Back found in B file!\n";
				rename $source_path.'/'.$file_base.'B.'.$extension, $source_path.'/'.$file_base.'E.'.$extension;
				next;
			} # end if
			if ( ! open( A, '< '.$source_path.'/'.$file_base.'A.'.$extension ) ) {
				print "Error opening " . $source_path.'/'.$file_base."A.$extension\n" ;
				next;
			} # end if
			if ( ! open( M, '> '.$dest_path.'/'.$out_base.'M.'.$extension ) ) {
				print "Error opening " . $dest_path.'/'.$file_base."M.$extension\n" ;
				next;
			} # end if
			my $fileA = $file_base.'A';
			my $fileM = $file_base.'M';
			while ( <A> ) {
				my $line = $_;
				$line =~ s/$fileA/$fileM/g;
				if ( $line =~ /CIP3EndOfFile/ ) {
					foreach ( @Back ) {
						last if $_ =~ /CIP3EndOfFile/;
						print M $_;
					} # end foreach
				} # end if
				print M $line;
			} # end while
			close A;
			close M;
			unlink $source_path.'/'.$file_base.'A.'.$extension;
			unlink $source_path.'/'.$file_base.'B.'.$extension;

		} # end if
	} # end if
} # end foreach
} # end if inotify
1;
__END__


