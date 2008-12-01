#!/usr/bin/perl
use strict;

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
	if ( $db !~ /^template\d$/ ) {
		print "Backing up $db\n";
		if ( ! -d "$path/$host/$db" ) {
			`mkdir $path/$host/$db` or next;
		} # end if
		if ( $host and $host ne 'local' ) {
			`pg_dump -h $host $db | bzip2 > $path/$host/$db/$year-$mon-$mday.sql.new.bz2`;
		} else {
			`pg_dump $db | bzip2 > $path/$host/$db/$year-$mon-$mday.sql.new.bz2`;
		} # end if
		die "Can't dump $db" if $?;
		`mv $path/$host/$db/$year-$mon-$mday.sql.new.bz2 $path/$host/$db/$year-$mon-$mday.sql.bz2`;

		opendir DIRHANDLE, "$path/$host/$db/";
		my @files = readdir DIRHANDLE;
		closedir DIRHANDLE;
		foreach my $file ( @files ) {
			if ( $file =~ /(\d\d\d\d)-(\d\d)-(\d\d).sql.bz2/ ) {
				if ( Date::Calc::check_date( $1, $2, $3 ) ) {
					if ( Date::Calc::Delta_Days( $year, $mon, $mday, $1, $2, $3 ) > 30 ) {
						unlink "$path/$host/$db/$file";
					} # end if too old
				} # end if valid date
			} # end if valid filename
		} # end foreach file
	} # end if not template
} # end foreach database

1;
__END__
