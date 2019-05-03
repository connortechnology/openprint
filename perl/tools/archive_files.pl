#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;
use warnings;

require sql;
require logger;
require openprint::Object;
require openprint::File;
require openprint::Project;
require File::Compare;
use Getopt::Long;

use openprint ();
use vars qw( $log $dbh %config %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

my $opts = {};
GetOptions($opts, 'help', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','debug=s','path=s');

if ($opts->{help}) {
    usage();
    exit 0;
}

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
configuration::init();
configuration::merge( $opts );
configuration::from_file('/etc/openprint/archive_files.conf');
$log = new logger( {file=>$config{log_file}, level=>$config{log_level}} );

my $die = 0;
foreach my $param ( 'db_name','db_user','db_pass' ) {
    if ( ! $config{$param} ) {
        $log->error("archive_files: missing required --$param parameter");
		$die = 1;
    }
} # end foreach required-param
die "Missing required parameters" if $die;

$dbh = sql::open_sql( $log, 
		database=>$config{db_name},
		driver=>'Pg',
		login=>$config{db_user},
		password=>$config{db_pass}, 
		host=>$config{db_host} );
die "Unable to connect to db." if ! $dbh;
configuration::from_db();
my $die = 0;
foreach my $param ( 'Archive_Directories' ) {
    if ( ! $config{$param} ) {
        $log->error("archive_files: missing required --$param parameter");
		$die = 1;
    }
} # end foreach required-param
die "Missing required parameters" if $die;

foreach my $archive_dir ( split( ',', $config{'Archive_Directories'} ) ) {
	$log->info("Checking in $archive_dir". ( $config{path} ? ", starting in $config{path}" : '' ));
	process_dir($archive_dir,$config{path} ? $config{path} : '');
} # end foreach archive_dir

sub process_dir {
	my ( $archive, $path ) = @_;

	my @filenames;
    if ( opendir DIRHANDLE, join('/', $archive, $path) ) {
        @filenames = readdir DIRHANDLE;
        closedir DIRHANDLE;
    } else {
        $log->error( "Cannot open $archive/$path" );
		return;
    } # end if

	foreach my $file ( @filenames ) {
		next if $file =~ /^\./;

		my $docket;

		if ( -d join('/', $archive, $path, $file) ) {
			$log->debug("descending into $archive/$path/$file");
			process_dir( $archive, $path.'/'.$file );
		} elsif ( my ($bkf) = $file =~ /^(\d+.+\.bkf)\.bz2$/ ) {
$log->debug("Got bkf.bz2 at $file" );
			if ( sets::isin($bkf, @filenames) ) {
				$log->debug("Found both .bz2 and .bkf for $bkf");
				if ( ! -e "$archive/$path/$bkf.blah" ) {
					`bunzip2 < "$archive/$path/$bkf.bz2" > "$archive/$path/$bkf.blah"`;
					if ( $? ) {
						$log->error("ERror bunzipping $bkf.bz2. May be corrupt, delete?");
						$_ = <>;
						if ( $_ eq 'Y' or $_ eq 'y' ) {
							unlink("$bkf.bz2");
						}
						next;

					}
				}
				`diff "$archive/$path/$bkf" "$archive/$path/$bkf.blah"`;
				if ( ! $? ) {
					$log->debug("bz2 for $bkf is valid.");
					unlink "$archive/$path/$bkf";

					($docket) = $bkf =~ /^(\d+).+\.bkf$/;
					my $Project = openprint::Project->find_one( docket=>$docket );
					if ( $Project ) {
						my $File1 = openprint::File->find_one( project_id=>$Project->id(), filename=>$path.'/'.$bkf, archive=>$archive );
						my $File2 = openprint::File->find_one( project_id=>$Project->id(), filename=>"$path/$bkf.bz2", archive=>$archive );
						if ( $File1 ) {
							if ( $File2 ) {
								$File1->delete();
							} else {
								$File1->save({filename=>"$path/$bkf.bz2"});
							}
						} elsif ( ! $File2 ) {
							$File2 = new openprint::File();
							$_ = $File2->save({
									project_id  =>  $Project->id(),
									filename    =>  $path.'/'.$file.'.bkf',
									archive     =>  $archive,
									});
						}
					} # end if Project
				} else {
					$log->warn("bz2 for $archive/$path/$bkf is not valid. Please clean manually");
				}
				unlink "$archive/$path/$bkf.blah";
			}
		} elsif ( my ($bkf) = $file =~ /^(\d+.+\.bkf)$/ ) {
			my $full_path = join('/', $archive, $path, $file);

			if ( ! -e $full_path ) {
				$log->debug("File $full_path does not exist, probably already cleaned");
				next;
			}
			my $mtime = (stat($full_path))[9];
			my $age = time - $mtime;
			if ( $age < 60*60*24*365 ) {
				$log->debug("File is more than a year old, should bzip2 it");
			}
			
			($docket) = $bkf =~ /^(\d+).+\.bkf$/;
			if ( $docket ) {
				foreach my $Project ( openprint::Project->find( docket=>$docket ) ) {
					next if openprint::File->find_one( project_id=>$Project->id(), filename=>$path.'/'.$file, archive=>$archive );

					my $File = new openprint::File();
					$_ = $File->save({
						project_id	=>	$Project->id(),
						filename	=>	$path.'/'.$file,
						archive		=>	$archive,
					});
					$log->error($_) if $_;
				} # end foreach Project
			} # end if docket
		} else {
$log->debug("Unknown archive at $archive/$path/$file" ) if $path =~ /Group/;
		} # end if
	} # end foreach file
} # end sub process_dir

$dbh->disconnect();
1;
__END__
