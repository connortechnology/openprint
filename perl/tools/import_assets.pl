#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;
use warnings;
use File::Basename qw(basename);

require configuration;
require sets;
require sql;
require logger;
require openprint::Asset;
require openprint::Photo_Album;
require openprint::Photo_in_Album;
use Getopt::Long;
use File::Slurp;
use Digest::MD5;

use openprint ();
use vars qw($log $dbh %config %session);
*dbh = \$openprint::dbh;
*log = \$openprint::log;
*config = \%openprint::config;
*session = \%openprint::session;

my $program = 'video_assets.pl';
$log = logger->new('debug');
my $opts = {};
GetOptions($opts, 'help', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','debug=s','daemon', 'AssetPath=s', 'add=s');

if ($opts->{help}) {
    usage();
    exit 0;
}
if ( $opts->{debug}) {
    $$log{level} = $opts->{debug};
}

unless ($opts->{db_name}) {
    print STDERR "$program: missing required --db_name parameter\n";
    exit 1;
}
$opts->{db_user} = $opts->{db_name} if ! $opts->{db_user};
$opts->{db_pass} = $opts->{db_name} if ! $opts->{db_pass};

$dbh = sql::open_sql( $log,
        'host'      => $opts->{db_host},
        'database'  => $opts->{db_name},
        'driver'    => 'Pg',
        'login'     => $opts->{db_user},
        'password'  => $opts->{db_pass},
        );

die 'Error opening db' if ! $dbh;
configuration::init();
configuration::merge($opts);

if ( $$opts{add} ) {
	add( $$opts{add} );
} # end if
#scan();

if ( $$opts{daemon} ) {
	use Linux::Inotify2;
	my $notifier = Linux::Inotify2->new();
	my $watch = $notifier->watch($config{AssetPath}, IN_CLOSE, \&event );

	1 while $notifier->poll;
} # end if
$dbh->disconnect();

sub event {
	my ( $e ) = shift;
	$log->debug( $e->print() );
	scan();
}

sub scan {
	foreach my $Asset ( openprint::Asset->find( ) ) {
		next if ! $Asset->is_video();

		if ( $Asset->source() ) {
			if ( ! -e $Asset->on_disk_path() ) {
				my $blob = File::Slurp::read_file( $Asset->source() );
				if ( ! File::Slurp::write_file($Asset->on_disk_path(), { atomic => 1, err_mode=>'carp' }, $blob ) ) {
					return 'There was an error saving file ' . $_[0].' to ' . $Asset->on_disk_path() . ": $!<br/>";
				} # end if
			} # end if
		} # end if

		foreach my $type ( 'mp4','ogg','webm' ) {
			my $path = $Asset->video_path($type);

			# Next if already generating
			next if -e $path.'.part';
			# If video exists, will not generate
			$Asset->generate_video($type);
			if ( ! -e $path ) {
				$log->error("Was unsuccessful in generating video at $path");
			} # en dif
		} # end foreach $type
		my $new_filename = openprint::Asset->transform( 'filename', $Asset->filename() );

		if ( $Asset->filename() ne $new_filename ) {
			my $old_path = $Asset->on_disk_path();
	
			foreach my $type ( 'mp4','ogg','webm' ) {
				my $path = $Asset->video_path($type);
				my $new_path = openprint::Asset->transform( 'filename', $path );
				rename( $path, $new_path );
			} # end foreach
			$Asset->save({filename=>$new_filename});
			rename( $old_path, $Asset->on_disk_path() );
		} # end if
	} # end foreach Asset
} # end sub scan

sub add {
	my ( $path, $Album ) = @_;

	if ( -d $path ) {
		$log->debug("Path $path is a directory, recursing.");

		my @filenames;
		if ( opendir DIRHANDLE, $_[0] ) {
			@filenames = readdir DIRHANDLE;
			closedir DIRHANDLE;
		} else {
			$log->error( "Cannot open $_[0]" );
			return;
		} # end if
		$Album = openprint::Photo_Album->find_one( name=>$path ) if ! $Album;
		if ( ! $Album ) {
			$log->debug("Adding album $path");
			$Album = new openprint::Photo_Album();
			$Album->save({name=>$path});
		} else {
			$log->debug("Have album $$Album{name}");
		} # end if
		foreach my $file ( @filenames ) {
			next if $file =~ /^\./;
			add( $path.'/'.$file, $Album );
		} # end foreach
	} else {
		if ( 0 and my $Asset = openprint::Asset->find_one(source=>$path) ) {
			if ( -e $Asset->on_disk_path() ) {
				$log->debug("$_[0] already exists.\n");	
				return;
			} # end if
			my $filename = basename($_[0]);
			if ( $Asset->filename() ne $Asset->transform('filename', $Asset->filename() ) ) {
				my $old = $Asset->on_disk_path();
				$Asset->save({filename=>$Asset->filename()});
				rename( $old,  $Asset->on_disk_path() );
			} # end if
				
			$Asset->fetch();
			return;
		} # end if
		my $blob = File::Slurp::read_file( $path );
		my $md5 = Digest::MD5::md5_base64( $blob );
		if ( ! $md5 ) {
			return "Unable to MD5?";
		} # end if
		my $Asset = openprint::Asset->find_one( md5 => $md5 );
		if ( ! $Asset ) {
			$log->debug("Creating new asset");
			$Asset = new openprint::Asset();

			my $filename = basename($_[0]);
			$_ = $Asset->save({ filename=>$filename, md5=>$md5, name=>$filename, source=>$path });
			return $_ if $_;

			if ( ! File::Slurp::write_file($Asset->on_disk_path(), { atomic => 1, err_mode=>'carp' }, $blob ) ) {
				return 'There was an error saving file ' . $path.' to ' . $Asset->on_disk_path() . ": $!<br/>";
			} # end if

			$_ = $Asset->save();
			return $_ if $_;

		} else {
			$log->debug("Found existing asset $$Asset{id} with hash $md5");
			if ( ! $Asset->source() ) {
				$Asset->save({source=>$path});
			} # end if
			if ( ! -e $Asset->on_disk_path() ) {
				if ( ! File::Slurp::write_file($Asset->on_disk_path(), { atomic => 1, err_mode=>'carp' }, $blob ) ) {
					return 'There was an error saving file ' . $path.' to ' . $Asset->on_disk_path() . ": $!<br/>";
				} # end if
			} # end if
		} # end if
			if ( ! openprint::Photo_in_Album->find(asset_id=>$$Asset{id}) ) {
				my $PA = new openprint::Photo_in_Album();
				$log->debug("Adding to album: $$Asset{name}");
				$PA->save({album_id=>$$Album{id}, asset_id=>$$Asset{id}});
			} else {
				$log->debug("Already in album.");
			}
	} # end if
} # end sub add

sub usage {
	print <<EOH;

usage: $program [--help] [--db_name \$db_name] [--db_host \$db_host] [--db_user \$db_user] [--db_pass \$db_pass] filename

The purpose of this script is to convert uploaded videos to their various 
web formats.

Command-line options:

	--help		Displays this message.

	--db_host	The hostname of the machine on which the database resides.

	--db_name	The name of the database.
	
	--db_user	The name of the user to use when connecting to the database.

	--db_pass	The password to use when connecting to the database.

    --AssetPath    File to store the session count in.
	
	--add		File to import

EOH
}
1;
__END__
