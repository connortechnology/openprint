#!/usr/bin/perl
use strict;
require Date::Calc;
require DBI;

my ($sec,$min,$hour, $mday, $mon, $year,$wday,$yday,$isdst) = localtime(time);
$mon++;
$year += 1900;

my ( $path, $host, @dbs ) = @ARGV;

if ( ! -d "$path/$host" ) {
	`mkdir $path/$host` or die "Cannot make directory $path/$host";
} # end if

if ( ! @dbs ) {
	if ( $host and $host ne 'local' ) {
		$_ = `/usr/bin/psql -h $host -t -c "SELECT datname from pg_database" -d template1`;
	} else {
		$_ = `/usr/bin/psql -t -c "SELECT datname from pg_database" -d template1`;
	} # end if
	die "Can't get db list: ($!)" if $?;
	@dbs = split "\n", $_;
} # end if

foreach my $db ( @dbs ) {
	$db =~ s/^\s*([\w\-]*)\s*$/$1/;
	next if $db =~ /template\d/;
	my $dbh = DBI->connect("dbi:Pg:dbname=$db;".($host?'host='.$host:''), 'postgres', undef, {AutoCommit=>1} );
	if ( ! $dbh ) {
		print "Unable to connect to $db\n";
		next;
	} # end if
	my $row = $dbh->selectrow_hashref( q{SELECT backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
	if ( ! $row ) {
		print "Error loading row from database_info of $db " . $dbh->errstr()."\n";
		next;
	} # end if
	if ( $$row{'backup'} ) {
		print "Backing up $db\n";
		if ( ! -e "$path/$host/$db" ) {
			if ( ! `mkdir $path/$host/$db` ) {
				print "Unable to mkdir $path/$host/$db .. skipping\n";
				next;
			} # end if
		} # end if
		if ( $host and $host ne 'local' ) {
			`pg_dump -h $host $db | bzip2 > $path/$host/$db/$year-$mon-$mday.sql.new.bz2`;
		} else {
			`pg_dump $db | bzip2 > $path/$host/$db/$year-$mon-$mday.sql.new.bz2`;
		} # end if
		die "Can't dump $db" if $?;
		`mv $path/$host/$db/$year-$mon-$mday.sql.new.bz2 $path/$host/$db/$year-$mon-$mday.sql.bz2`;

		opendir DIRHANDLE, "$path/$host/$db/" or die 'couldnt open db backup dir';
		my @files = readdir DIRHANDLE;
		closedir DIRHANDLE;
		foreach my $file ( @files ) {
			if ( $file =~ /(\d\d\d\d)-(\d+)-(\d+).sql.bz2/ ) {
				if ( Date::Calc::check_date( $1, $2, $3 ) ) {
					if ( Date::Calc::Delta_Days( $year, $mon, $mday, $1, $2, $3 ) > 30 ) {
						unlink "$path/$host/$db/$file";
					} # end if too old
				} # end if valid date
			} # end if valid filename
		} # end foreach file
	} # end if 
	$dbh->disconnect();
} # end foreach database

1;
__END__
