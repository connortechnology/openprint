#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;
use sets;

use constant DEBUG => 0;

die if ! $ARGV[0];

sub clean_dir {
	my $path = $_[0];

	my @dir;
	if ( opendir DIRHANDLE, $path ) {
		@dir = readdir DIRHANDLE;
		closedir DIRHANDLE;
	} else {
		print "Cannot open dir $path \n";
		return;
	} # end if
	@dir = map { sets::isin( $_ , [ '.', '..', '.DS_Store', '._.DS_Store' ] ) ? () : $_ } @dir;
	if ( @dir == 1 and $dir[0] eq '.AppleDouble' ) {
		print "Found directory with only .AppleDouble, doing rm -r $path\n";
		`rm -r "$path"`;
		return;
	} else {
		print "contents: @dir\n";
	}
	foreach my $file ( @dir ) {
		next if $file =~ /^\./;
	
		if ( -d $path.'/'.$file ) {
		print "Recursing into $path / $file\n";
		clean_dir ( $path.'/'.$file );
		}
	}
	
} # end sub clean_dir
clean_dir( $ARGV[0] );


1;
__END__
