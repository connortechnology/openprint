package sql;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(open_sql sql_statement update insert run_query execute );

# Provides some utility functions for doing SQL queries

use DBI;
use Time::HiRes qw{ time gettimeofday tv_interval }; 
use strict;

use vars qw( $log $dbh $debug );
$debug = 1;

sub open_sql {
	my ( $l, %sql_server ) = @_;
	$log = $l;
	
	my $dsn = "dbi:$sql_server{'driver'}:dbname=$sql_server{'database'};";
	$dsn .= "host=$sql_server{'host'}" if $sql_server{'host'};
	if ( ! ( $dbh = DBI->connect( $dsn, $sql_server{'login'}, $sql_server{'password'}, {AutoCommit=>1} ) ) ) {
		die $log->crit("Unable to connect to database $sql_server{'database'}: " . DBI->errstr );
	} # end if
	#$log->info("Opened connection to $sql_server{'database'}.	Thread ID: " . $dbh->{'thread_id'});

	return $dbh;
} # end sub open_sql

sub execute {
	my ( $l, $d, $sql, @values ) = @_;
	my @return_array = ();
	my $print_sql = '';
	my $starttime;

	$l = $log if ! defined $l;
	$d = $dbh if ! $d;

	if ( $l and $debug ) {
		$print_sql = $sql;
		$print_sql =~ s/\?/\%s/g;
		$print_sql = sprintf($print_sql, @values);
		$starttime = gettimeofday();
	} # end if
	my $sth;
	if ( ! ( $sth = $d->prepare_cached($sql) ) ) {
		$l->error( "Error Preparing SQL: ($print_sql): " . $d->errstr ) if $l;
		return;
	} # end if
	if ( ! $sth->execute(@values) ) {
		$l->error("SQL execution failed: ($print_sql):" . $d->errstr) if $l;
		return;
	} # end if
	if ( my $num_of_fields = $sth->{'NUM_OF_FIELDS'} ) {
		while ( my $ref = $sth->fetchrow_arrayref ) {
			for ( my $i = 0; $i < $num_of_fields; $i += 1 ) {
				push( @return_array, $$ref[$i] );
			} # end for
		} # end while
	} # end if
	$sth->finish(); # unneccessary
	if ( $l and $debug ) {
		$l->debug("SQL (".sprintf('%.4f', tv_interval( [$starttime])*1000)." usecs). ($print_sql) Results:".join(',',@return_array));
	} # end if

	return @return_array;
} # end sub execute


sub run_query {
	# Receives database to connect to, and SQL statement to be
	# sent to it, returns the values returned by the server.
	my ( $log, $dbh, $sql_statement ) = @_;
	my ( @return_array, $num_of_fields, $ref );

	my $starttime = [gettimeofday];
	my $sth = $dbh->prepare($sql_statement) or $log->error( "Error Preparing SQL Statement: ($sql_statement): " . $dbh->errstr );
	if ( ! $sth or ! $sth->execute() ) {
		$log->error("SQL statement execution failed: ($sql_statement):" . $dbh->errstr);
		return ( -1, $dbh->errstr );
	} # end if
	$num_of_fields = $sth->{'NUM_OF_FIELDS'};
	while ( $num_of_fields and $ref = $sth->fetchrow_arrayref) {
		for ( my $i = 0; $i < $num_of_fields; $i += 1 ) {
			#$$ref[$i] =~ s/^\s*(.*?)\s*$/$1/m;	# This should strip out leading and trailing whitespace
			push( @return_array, $$ref[$i] );
		} # end for
	} # end while
	#$sth->finish(); # unneccessary
	$log->debug("SQL (".(sprintf('%.4f', tv_interval( $starttime, [gettimeofday])*1000) )." useconds). ($sql_statement) Results:".join(',',@return_array));
	
	return ( $num_of_fields, @return_array );
} # end sub run_query

# makes the code for inserting into the db nicer by building the SQL statement for us.
sub insert {
	my ( $l, $d, $table ) = splice @_, 0, 3;

	$d = $dbh if ! $d;
	$l = $log if ! $l;

	my $starttime = [gettimeofday];
	my %commands = ();
	if ( @_ == 1 ) {
		my $data = shift;
		if ( ref $data eq 'HASH' ) {
			%commands = %$data;
		} elsif ( ref $data eq 'ARRAY' ) {
			%commands = @$data;
		} # end if
	} else {
		%commands = @_;
	} # end if

	my @values = values %commands;

	# we can use push and pop in here, because we actually don't acre about order, only pairing
	my $command = "INSERT INTO $table (".join( ',', keys %commands ).') VALUES (';
	my $print_command = $command;
	$print_command .= join(',', map { defined $_ ? $_ : 'undef' } @values ) if @values;
	$print_command .= ')';

	$command .= join(',', map { '?' } @values ).')';
	my $sth;
	if ( ! ( $sth = $d->prepare($command) ) ) {
		$l->error( "Error Preparing SQL Statement: ($command):" . $d->errstr ) if $l;
		return $d->errstr;
	} # end if
	if ( ! $sth->execute(values %commands) ) {
		$l->error("SQL statement execution failed: ($print_command):" . $d->errstr) if $l;
		return $d->errstr;
	} # end if
	$l->debug(sprintf('SQL (%.4f usecs) (%s): ', tv_interval($starttime, [gettimeofday])*1000, $print_command ) ) if $l;
	return;
} # end sub insert

sub update {
	my ( $l, $d, $table, $condition ) = splice @_,0,4;

	$d = $dbh if ! $d;

	my $starttime = [gettimeofday];
	my %commands = ();
	if ( @_ == 1 ) {
		my $data = shift;
		if ( ref $data eq 'HASH' ) {
			%commands = %$data;
		} elsif ( ref $data eq 'ARRAY' ) {
			%commands = @$data;
		} # end if
	} else {
		%commands = @_;
	} # end if

	my $command = "UPDATE $table SET ";
	my @columns;
	foreach my $column ( keys %commands ) {
		push @columns, "$column = ?";
	} # end foreach
	$command .= join( ',', @columns );
	my @conditions = ();
	if ( ref $condition eq 'ARRAY' ) {
		@conditions = @$condition;
		$command .= ' WHERE ' . shift @conditions;
	} else {
		$command .= " WHERE $condition";
	} # end if
	my $sth;
	if ( ! ( $sth = $d->prepare($command) ) ) {
		$log->error( 'Error Preparing SQL Statement: ('.sprintf($print_command, values %commands, map { defined $_ ? $_ : 'undef' } @conditions ).'):' . $d->errstr ) if $log;
		return $d->errstr;
	} # end if
	if ( ! $sth->execute( values %commands, @conditions ) ) {
		$log->error('SQL statement execution failed: ('.sprintf($print_command, values %commands, map { defined $_ ? $_ : 'undef' } @conditions ).'):' . $d->errstr) if $log;
		return $d->errstr;
	} # end if
	
	if ( $log ) {
		my $print_command;
		if ( $command and %commands and @conditions ) {
			$command =~ s/\?/\%s/g;
			$print_command = sprintf($command, values %commands, @conditions );
		} # end if
		$log->debug( sprintf('SQL (%.4f usecs) (%s)', tv_interval( $starttime, [gettimeofday])*1000, $print_command ) );
	} # end if

	return;
} # end sub update

sub start_transaction {
	my $dbh = shift;
	my $ac = $dbh->{AutoCommit};
	$dbh->{AutoCommit} = 0;
	return $ac;
} # end sub start_transaction

sub end_transaction {
	my ( $dbh, $ac ) = @_;
	$dbh->commit() if $ac;
	$dbh->{AutoCommit} = $ac;
} # end sub end_transaction


1;

__END__

