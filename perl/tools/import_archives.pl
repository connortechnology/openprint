#!/usr/bin/perl -w
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::File;
require openprint::Project;

use openprint ();
use vars qw( $log $dbh %config %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>'database') );
die "Unable to connect to db." if ! $dbh;
configuration::init();
configuration::from_file('/etc/openprint/import_archives.conf');
$log = new logger( {file=>$config{log_file}, level=>$config{log_level}} );


foreach my $archive_dir ( split( ',', $config{'Archive_Directories'} ) ) {
	$log->error("Checking in $archive_dir");
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
			$log->debug("descending into $archive.'/'.$path.'/'.$file " );
			get_files( $archive, $path.'/'.$file );
		} elsif ( my ($docket) = $file =~ /^(\d+).+\.bkf$/ ) {
$log->debug("Got bkf at $file" );
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
		} elsif ( my ($docket) = $file =~ /^(\d+).+\.tar.bz2$/ ) {
$log->debug("Got tar.bz2 at $file" );
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
			}
		} else {
$log->debug("Unknown archive at $archive/$path/$file" );
		} # end if
	} # end foreach file
} # end sub get_files

	
$dbh->disconnect();
1;
__END__
