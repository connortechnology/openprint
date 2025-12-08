#!/usr/bin/perl
use warnings;
use Getopt::Long;
use lib '/var/www/openprint/perl';
use strict;
require Date::Calc;
require DBI;
require sets;

my ($sec,$min,$hour, $mday, $mon, $year,$wday,$yday,$isdst) = localtime(time);
$mon++;
$year += 1900;

my $opts = {};
GetOptions($opts, 'help', 'host=s', 'path=s', 'days=s', 'debug=s', 'c=s', 'port=s' );

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

my @dbs = @ARGV;
if ( ! @dbs ) {
	my $command = join(' ',
			'/usr/bin/psql',
			( ( $$opts{host} and ( $$opts{host} ne 'local' ) ) ? ( '-h' , $$opts{host} ) : () ),
			( $$opts{port} ? ( '-p', $$opts{port} ) : () ),
			'-t', '-c', '"SELECT datname from pg_database"', '-d', 'template1',
			);
	$_ = `$command`;
	die "Can't get db list: ($!)" if $?;
	@dbs = split "\n", $_;
} # end if
print "@dbs\n" if $$opts{debug};

foreach my $db ( @dbs ) {
	$db =~ s/^\s+//;
	$db =~ s/\s+$//;
	next if $db =~ /^template\d/;
	next if $db eq 'postgres';
	my $dbh = DBI->connect("dbi:Pg:dbname=$db".($$opts{host}?';host='.$$opts{host}:'').($$opts{port}?';port='.$$opts{port}:''), 'postgres', undef, {AutoCommit=>1} );
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
		print "No database_info table in db $db tables:( @$tables )\n";
		next;
	} # end if

	my $row = $dbh->selectrow_hashref( 'SELECT * FROM database_info ORDER BY updated_on DESC LIMIT 1' );
	if ( ! $row ) {
		#print "Error loading row from database_info of $db " . $dbh->errstr()."\n";
		next;
	} # end if
	if ( $$row{backup} ) {
		print "Backing up $db to $path/$db/$year-$mon-$mday.sql.bz2\n" if $$opts{debug};
		if ( ! -e "$path/$db" ) {
			print "Making $path/$db ..\n" if $$opts{debug};
			if ( ! mkdir "$path/$db" ) {
				print "Unable to mkdir $path/$db .. skipping\n";
				next;
			} # end if
		} # end if
		my $command = join(' ',
				'pg_dump -b -Fc',
				( ( $$opts{host} and $$opts{host} ne 'local' ) ? ( '-h', $$opts{host} ) : () ),
				( $$opts{port} ? ( '-p', $$opts{port} ): () ),
				$db,
        '>', "$path/$db/$year-$mon-$mday.sql.new",
        # '|', 'bzip2',
				);
		#print "running $command\n";
		system($command);
		die "Can't dump $db" if $?;
		if ( ! rename( "$path/$db/$year-$mon-$mday.sql.new", "$path/$db/$year-$mon-$mday.sql" ) ) {
			print "ERror renaming $path/$db/$year-$mon-$mday.sql.new to $path/$db/$year-$mon-$mday.sql : $!\n";
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
				if ( $file =~ /^(\d\d\d\d)-(\d+)-(\d+).sql(.bz2)?$/ ) {
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
