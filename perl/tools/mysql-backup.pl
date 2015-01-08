#!/usr/bin/perl
use warnings;
use Getopt::Long;
use lib '/var/www/testing/perl';
use strict;
require Date::Calc;
require DBI;
require sets;

my ($sec,$min,$hour, $mday, $mon, $year,$wday,$yday,$isdst) = localtime(time);
$mon++;
$year += 1900;

my $opts = {};
GetOptions($opts, 'help', 'host=s', 'path=s', 'days=s', 'debug=s', 'c=s', 'user=s', 'password=s' );

if ($opts->{help}) {
    usage();
    exit 0;
}
if ( $$opts{c} and ! -e $$opts{c} ) {
	die "Unable to find check file at $$opts{c}\n";
} # end if

my $path;
if ( ! $$opts{path} ) {
	$path = '/var/backups/postgres';
} else {
	$path = $$opts{path};
} # end if
if ( $$opts{host} ) {
	$path .= '/'.$$opts{host};
} # end if

if ( ! -d $path ) {
	mkdir($path) or die "Cannot make directory $path: $!";
} # end if

my @args = ();
my @dbs = @ARGV;
if ( ! @dbs ) {
	if ( $$opts{user} ) {
		push @args, "--user=$$opts{user}";
	} # end 
	if ( $$opts{password} ) {
		push @args, "--password=$$opts{password}";
	}

	if ( $$opts{host} and $$opts{host} ne 'local' ) {
		push @args, "-h $$opts{host}";
	} 
	$_ = `/usr/bin/mysql -B -N -e 'show databases' @args |grep -viE '(staging|performance_schema|information_schema)'`;
	die "Can't get db list: ($!)" if $?;
	@dbs = split "\n", $_;
} # end if
print "@dbs\n" if $$opts{debug};

foreach my $db ( @dbs ) {
	$db =~ s/^\s+//;
	$db =~ s/\s+$//;
	$db =~ s/\n//g;

	if ( ! -d "$path/$db/" ) {
		if ( ! mkdir "$path/$db/" ) {
			print STDERR "Can't make $path/$db/ reason: $!\n";
			next;
		}
	}

	system("mysqldump @args --events --opt --single-transaction $db | bzip2 > $path/$db/$year-$mon-$mday.sql.new.bz2");
	die "Can't dump $db" if $?;
	if ( ! rename( "$path/$db/$year-$mon-$mday.sql.new.bz2", "$path/$db/$year-$mon-$mday.sql.bz2" ) ) {
		print "ERror renaming $path/$db/$year-$mon-$mday.sql.new.bz2 to $path/$db/$year-$mon-$mday.sql.bz2 : $!\n";
		next;
	} # end if
	print "Done backing up $db\n" if $$opts{debug};

	if ( $$opts{days} ) {
		print "Cleaning up backups older than $$opts{days}days\n" if $$opts{debug};
		opendir DIRHANDLE, "$path/$db/" or die 'couldnt open db backup dir';
		my @files = readdir DIRHANDLE;
		closedir DIRHANDLE;
		foreach my $file ( @files ) {
			next if $file =~ /^\./;
			if ( $file =~ /^(\d\d\d\d)-(\d+)-(\d+).sql.bz2$/ ) {
				if ( Date::Calc::check_date( $1, $2, $3 ) ) {
					my $age = Date::Calc::Delta_Days( $1, $2, $3, $year, $mon, $mday );
					if ( $age > $$opts{days} ) {
						print "deleting $path/$db/$file\n" if $$opts{debug};
						unlink "$path/$db/$file";
						print STDERR "unable to unlink $path/$db/$file: $!\n" if $!;
					} elsif ( $$opts{debug} ) {
						print "Too new $path/$db/$file: $age days\n";
					} # end if too old
				} else {
					print STDERR "Invalid date $path/$db/$file\n";
				} # end if valid date
			} else {
				print STDERR "$path/$db/$file doesn't look like a backup\n";
			} # end if valid filename
		} # end foreach file
	} # end if days
} # end foreach database

sub usage {
	print <<EOH;

usage: db_backup [--help] 

The purpose of this script is to backup postgres databases using pg_dump

Command-line options:

	--help		Displays this message.
EOH
} # end sub usage

1;
__END__
