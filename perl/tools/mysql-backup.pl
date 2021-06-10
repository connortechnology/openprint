#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$mon++;
$year += 1900;

my $opts = {};
GetOptions($opts,
  'databases=s',
  'days=s',
  'debug=s',
  'defaults-file=s',
  'events',
  'help',
  'host=s',
  'password=s',
  'path=s',
  'tables=s',
  'type=s',
  'user=s',
);

if ($opts->{help}) {
  usage();
  exit 0;
}


if ( $$opts{c} and ! -e $$opts{c} ) {
	die "Unable to find check file at $$opts{c}\n";
} # end if

my $path;
if (!$$opts{path}) {
	$path = '/var/backups/mysql';
} else {
	$path = $$opts{path};
} # end if
if ($$opts{host}) {
	$path .= '/'.$$opts{host};
} # end if

if (!-d $path) {
	mkdir($path) or die "Cannot make directory $path: $!";
} # end if

my @args = ();
push @args, ' --defaults-file='.$$opts{'defaults-file'} if $$opts{'defaults-file'};
push @args, ' --user='.$$opts{user} if $$opts{user};
push @args, ' --password='.$$opts{password} if $$opts{password};
push @args, ' -h '.$$opts{host} if $$opts{host} and ($$opts{host} ne 'local');

my @dbs = $$opts{databases} ? split(/,/, $$opts{databases}) : @ARGV;
if (!@dbs) {
	$_ = `/usr/bin/mysql @args -B -N -e 'show databases' | grep -viE '(staging|performance_schema|information_schema)'`;
	die "Can't get db list: ($!)" if $?;
	@dbs = split "\n", $_;
} # end if
print "@dbs\n" if $$opts{debug};

push @args, ' --tables='.$$opts{tables} if $$opts{tables};
push @args, ' --tables='.$$opts{events} if $$opts{events};

foreach my $db (@dbs) {
	$db =~ s/^\s+//;
	$db =~ s/\s+$//;
	$db =~ s/\n//g;

	if (! -d "$path/$db/") {
		if (!mkdir "$path/$db/") {
			print STDERR "Can't make $path/$db/ reason: $!\n";
			next;
		}
	}

  do_backup($db, $$opts{type}, @args);

	if ($$opts{days}) {
    require Date::Calc;
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

sub do_backup {
  my ($db, $type, @args) = @_;
  my $db_tmp_file = "$path/$db/$year-$mon-$mday.$type.sql.new.bz2";
  my $db_final_file = "$path/$db/$year-$mon-$mday.$type.sql.bz2";
  if ($type eq 'structure') {
    system("mysqldump @args --no-data --opt --single-transaction $db | bzip2 > $db_tmp_file");
  } elsif ($type eq 'data') {
    system("mysqldump @args --no-create-db --opt --single-transaction $db | bzip2 > $db_tmp_file");
  } else { #full
    system("mysqldump @args --opt --single-transaction $db | bzip2 > $db_tmp_file");
  }
	die "Can't dump $db" if $?;
	if (!rename($db_tmp_file, $db_final_file)) {
		print "Error renaming $db_tmp_file to $db_final_file : $!\n";
		return;
	} # end if
	print "Done backing up $db\n" if $$opts{debug};
}

sub usage {
	print <<EOH;

usage: db_backup.pl [--help] 

The purpose of this script is to backup postgres databases using pg_dump

Command-line options:

	--help		          Displays this message.
  --host=s            hostname of the database server if remote
  --path=s            path to where to store the backups. Backups will be placed in a subdirectory as path/db/
  --databases=s       comma separated database list
  --days=s            how many days to keep backups
  --debug=s           turn on debugging
  --events            whether to pass --events to mysqldump to dump event scheduler data
  --c=s               look for a an existing file before performing backup
  --user=s            username to use when connecting to db server
  --password=s        password to use when conneting to db server
  --defaults-file=s   path to mysql defaults file
EOH
} # end sub usage

1;
__END__
