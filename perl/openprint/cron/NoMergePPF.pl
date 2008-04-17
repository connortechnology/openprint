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
		if ( $file =~ /(.*)\.ppf$/i ) {
			my $file_base = $1;
			my $out_base = $file_base;
			$out_base =~ s/\./_/g;

			if ( ! open ( IN, '< ' . $source_path.'/'.$file ) ) {
				print "Error opening " . $source_path.'/'.$file."\n" ;
				next;
			} # end if

			if ( ! open( OUT, '> '.$dest_path.'/'.$out_base.'.ppf' ) ) {
				print "Error opening " . $dest_path.'/'.$out_base.".ppf\n" ;
				next;
			} # end if

			my ( $docket, $ppo, $name, $sig, $side ) = $file_base =~ /(\d\d\d\d\d)(\w\w)_?(.*?)Sg(\d\d)Sd\.(\w)/i;
print "File: $file Docket $docket, Operattor: $ppo, Name: $name, Sig: $sig, $side\n";
			while ( <IN> ) {
				my $line = $_;
				if ( $line =~ /^\/CIP3AdmSheetName \(Sheet (\d*)\) def/ ) {
					$line = sprintf("/CIP3AdmSheetName (Sig#%dSheet#%d)\r\n", 1*$sig, $1 );
				} # end if

				print OUT $line;
			} # end while
			close IN;
			close OUT;
			unlink $source_path.'/'.$file;
		} # end if
	} # end foreach
} # end if inotify
1;
__END__


