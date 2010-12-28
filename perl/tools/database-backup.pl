#!/usr/bin/perl
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
GetOptions($opts, 'help', 'host=s', 'path=s', 'days=s', 'debug=s' );

if ($opts->{help}) {
    usage();
    exit 0;
}
if ( ! $$opts{'path'} ) {
	# error
	die "Must specify path";
} # end if

if ( ! -d "$$opts{path}/$$opts{host}" ) {
	`mkdir $$opts{path}/$$opts{host}` or die "Cannot make directory $$opts{path}/$$opts{host}";
} # end if

my @dbs = @ARGV;
if ( ! @dbs ) {
	if ( $$opts{host} and $$opts{host} ne 'local' ) {
		$_ = `/usr/bin/psql -h $$opts{host} -t -c "SELECT datname from pg_database" -d template1`;
	} else {
		$_ = `/usr/bin/psql -t -c "SELECT datname from pg_database" -d template1`;
	} # end if
	die "Can't get db list: ($!)" if $?;
	@dbs = split "\n", $_;
} # end if

foreach my $db ( @dbs ) {
	$db =~ s/^\s*([\w\-]*)\s*$/$1/;
	next if $db =~ /template\d/;
	next if $db eq 'postgres';
	my $dbh = DBI->connect("dbi:Pg:dbname=$db;".($$opts{host}?'host='.$$opts{host}:''), 'postgres', undef, {AutoCommit=>1} );
	if ( ! $dbh ) {
		print "Unable to connect to $db\n";
		next;
	} # end if
	my $tables = $dbh->selectcol_arrayref( q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	if ( ! $tables ) {
		print "Error loading tables from $db " . $dbh->errstr()."\n";
		next;
	} # end if
	
	if ( ! sets::isin( 'database_info', $tables ) ) {
		print "No database_info table in $db @$tables\n";
		next;
	} # end if
	my $row = $dbh->selectrow_hashref( q{SELECT backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
	if ( ! $row ) {
		print "Error loading row from database_info of $db " . $dbh->errstr()."\n";
		next;
	} # end if
	if ( $$row{'backup'} ) {
		print "Backing up $db to $$opts{path}/$$opts{host}/$db/$year-$mon-$mday.sql.bz2\n" if $$opts{'debug'};
		if ( ! -e "$$opts{path}/$$opts{host}/$db" ) {
			print "Making $$opts{path}/$$opts{host}/$db ..\n" if $$opts{'debug'};
			if ( ! `mkdir $$opts{path}/$$opts{host}/$db` ) {
				print "Unable to mkdir $$opts{path}/$$opts{host}/$db .. skipping\n";
				next;
			} # end if
		} # end if
		if ( $$opts{host} and $$opts{host} ne 'local' ) {
			`pg_dump -h $$opts{host} $db | bzip2 > $$opts{path}/$$opts{host}/$db/$year-$mon-$mday.sql.new.bz2`;
		} else {
			`pg_dump $db | bzip2 > $$opts{path}/$$opts{host}/$db/$year-$mon-$mday.sql.new.bz2`;
		} # end if
		die "Can't dump $db" if $?;
		`mv $$opts{path}/$$opts{host}/$db/$year-$mon-$mday.sql.new.bz2 $$opts{path}/$$opts{host}/$db/$year-$mon-$mday.sql.bz2`;
		print "Done backing up $db\n" if $$opts{'debug'};

		if ( $$opts{'days'} ) {
			print "Cleaning up backups older than $$opts{'days'}days\n" if $$opts{'debug'};
			opendir DIRHANDLE, "$$opts{path}/$$opts{host}/$db/" or die 'couldnt open db backup dir';
			my @files = readdir DIRHANDLE;
			closedir DIRHANDLE;
			foreach my $file ( @files ) {
				next if $file =~ /^\./;
				if ( $file =~ /^(\d\d\d\d)-(\d+)-(\d+).sql.bz2$/ ) {
					if ( Date::Calc::check_date( $1, $2, $3 ) ) {
						my $age = Date::Calc::Delta_Days( $1, $2, $3, $year, $mon, $mday );
						if ( $age > $$opts{'days'} ) {
							print "deleting $$opts{path}/$$opts{host}/$db/$file\n" if $$opts{'debug'};
							unlink "$$opts{path}/$$opts{host}/$db/$file";
							print STDERR "unable to unlink $$opts{path}/$$opts{host}/$db/$file: $!\n" if $!;
						} elsif ( $$opts{'debug'} ) {
							print "Too new $$opts{path}/$$opts{host}/$db/$file: $age days\n";
						} # end if too old
					} else {
						print STDERR "Invalid date $$opts{path}/$$opts{host}/$db/$file\n";
					} # end if valid date
				} else {
					print STDERR "$$opts{path}/$$opts{host}/$db/$file doesn't look like a backup\n";
				} # end if valid filename
			} # end foreach file
		} # end if days
	} # end if 
	$dbh->disconnect();
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
