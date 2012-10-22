#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::PaperInventory;
require openprint::File;
require openprint::Project;

use openprint ();
use vars qw( $log $dbh %config %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>'database') );
die "Unable to connect to db." if ! $dbh;
configuration::init_cache($log,$dbh);
foreach my $archive_dir ( split( ',', $config{'Archive Directories'} ) ) {
	get_files($archive_dir,'');
} # end foreach archive_dir

sub get_files {
	my ( $archive, $path ) = @_;
	my @filenames;
    if ( opendir DIRHANDLE, $archive.'/'.$path ) {
        @filenames = readdir DIRHANDLE;
        closedir DIRHANDLE;
    } else {
        $log->error( "Cannot open $archive/$path" );
		return;
    } # end if
	foreach my $file ( @filenames ) {
		next if $file =~ /^\./;
		if ( -d $archive.'/'.$path.'/'.$file ) {
			get_files( $archive, $path.'/'.$file );
		} elsif ( my ($docket) = $file =~ /^(\d+).+\.bkf$/ ) {
			next if ! $docket;
			my $Project = openprint::Project->find_one( docket=>$docket );
			if ( $Project ) {
				next if openprint::File->find_one( project_id=>$Project->id(), filename=>$path.'/'.$file, archive=>$archive );

				my $File = new openprint::File();
				$_ = $File->save({
					project_id	=>	$Project->id(),
					filename	=>	$path.'/'.$file,
					archive		=>	$archive,
				});
				$log->error($_) if $_;
			#} else {
				#$log->error("No project found for docket $docket!");
			} # end if Project
		} # end if
	} # end foreach file
} # end sub get_files

	
$dbh->disconnect();
1;
__END__
