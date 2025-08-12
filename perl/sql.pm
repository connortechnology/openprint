use strict;
package sql;

# Provides some utility functions for doing SQL queries

use DBI ();
use Time::HiRes qw{ gettimeofday tv_interval }; 

use vars qw( $log $dbh $timing );
use openprint ();
*dbh = \$openprint::dbh;
*log = \$openprint::log;
use constant DEBUG => 1;
$timing = 1;

# This uses it's own dbh so as not to quash the global dbh.  This is so that we can easily open secondary db connections while maintaining the global one.
#
sub open_sql {
	my ( $l, %sql_server ) = @_;
	$l = $log if ! $l;
	my $new_dbh;
	
	my $dsn = "dbi:$sql_server{'driver'}:dbname=$sql_server{'database'};";
	$dsn .= "host=$sql_server{'host'}" if $sql_server{'host'};
	$dsn .= ";port=$sql_server{'port'}" if $sql_server{'port'};
	if ( ! ( $new_dbh = DBI->connect( $dsn, $sql_server{'login'}, $sql_server{'password'}, {AutoCommit=>1,pg_enable_utf8 => 1 } ) ) ) {
		$log->error("Unable to connect to database $sql_server{'database'}: " . DBI->errstr );
		return;
	} # end if
	#$log->info("Opened connection to $sql_server{'database'}.	Thread ID: " . $dbh->{'thread_id'});

	return $new_dbh;
} # end sub open_sql

sub execute_array {
	my ( $l, $d, $sql, @values ) = @_;
	my @return_array = ();
	my $print_sql = $sql;
	my $starttime;

	$l = $log if ! defined $l;
	$d = $dbh if ! $d;

	if ( $l and DEBUG ) {
		$print_sql = $sql;
		$print_sql =~ s/\?/\%s/g;
		$print_sql = sprintf($print_sql, @values);
		$starttime = [gettimeofday] if $timing;
	} # end if
	my $sth;
	if ( ! $d ) {
		$l->error( "No dbh $print_sql" ) if $l;
		return;
	} # end if
	if ( ! ( $sth = $d->prepare_cached($sql) ) ) {
		$l->error( "Error Preparing SQL: ($print_sql): " . $d->errstr ) if $l;
		return;
	} # end if
#$l->warn($sql);
	if ( ! $sth->execute(@values) ) {
		$l->error("SQL execution failed: ($print_sql):" . $d->errstr) if $l;
		return;
	} # end if
	if ( my $num_of_fields = $sth->{'NUM_OF_FIELDS'} ) {
		while ( my $ref = $sth->fetchrow_arrayref ) {
			push @return_array, @$ref;

			#for ( my $i = 0; $i < $num_of_fields; $i += 1 ) {
				#push @return_array, $$ref[$i];
			#} # end for
		} # end while
	} # end if
	$sth->finish();
	if ( $l and DEBUG ) {
		if ( $timing ) {
			$l->debug("SQL (".sprintf('%.4f', tv_interval($starttime)*1000)." usecs). ($print_sql) Results:".join(',',@return_array));
		} elsif ( @return_array ) {
			$l->debug("SQL ($print_sql) Results:".join(',',@return_array));
		} else {
			$l->debug("SQL ($print_sql) No Results:");
		} # end if
	} # end if

	return \@return_array;
} # end sub execute_array

sub execute_hash {
  my ( $l, $d, $sql, @values ) = @_;
  my @return_array = ();
  my $print_sql = $sql;
  my $starttime;

  $l = $log if ! defined $l;
  $d = $dbh if ! $d;

  if ( $l and DEBUG ) {
    $print_sql = $sql;
    $print_sql =~ s/\?/\%s/g;
    $print_sql = sprintf($print_sql, @values);
    $starttime = [gettimeofday] if $timing;
  } # end if
  my $sth;
  if ( ! $d ) {
    $l->error( "No dbh $print_sql" ) if $l;
    return;
  } # end if
  if ( ! ( $sth = $d->prepare_cached($sql) ) ) {
    $l->error( "Error Preparing SQL: ($print_sql): " . $d->errstr ) if $l;
    return;
  } # end if
#$l->warn($sql);
  if ( ! $sth->execute(@values) ) {
    $l->error("SQL execution failed: ($print_sql):" . $d->errstr) if $l;
    return;
  } # end if
  if ( my $num_of_fields = $sth->{'NUM_OF_FIELDS'} ) {
    while ( my $ref = $sth->fetchrow_hashref ) {
      push @return_array, $ref;
    } # end while
  } # end if
  $sth->finish();
  if ( $l and DEBUG ) {
    if ( $timing ) {
      $l->debug("SQL (".sprintf('%.4f', tv_interval($starttime)*1000)." usecs). ($print_sql) Results:".join(',',@return_array));
    } elsif ( @return_array ) {
      $l->debug("SQL ($print_sql) Results:".join(',',@return_array));
    } else {
      $l->debug("SQL ($print_sql) No Results:");
    } # end if
  } # end if

  return @return_array;
} # end sub execute_hash

sub execute {
	my $results = execute_array(@_);
	return $results?@{$results}:();
}


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
	$log->debug("SQL (".(sprintf('%.4f', tv_interval($starttime)*1000) )." useconds). ($sql_statement) Results:".join(',',@return_array));
	
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

	my @command_places = ();
	my @command_values = ();
	foreach my $v ( @values ) {
		if ( ref $v eq 'ARRAY' ) {
			push @command_places, '?';
			push @command_values, '{'.join(',', map { $_ } @{$v} ).'}';
		} else {
			push @command_places, '?';
			push @command_values, $v;
		} # end if
	} # end foreach
	$command .= join(',', @command_places) .')';
	$print_command .= join(',', map { if( ref $_ eq 'ARRAY' ) { "{$_}"; } elsif( defined $_ ) { $_; } else {'undef';} } @command_values ) if @command_values;
	$print_command .= ')';

	my $sth;
	if ( ! ( $sth = $d->prepare($command) ) ) {
		$l->error( "Error Preparing SQL Statement: ($command):" . $d->errstr ) if $l;
		return $d->errstr;
	} # end if
	if ( ! $sth->execute(@command_values) ) {
		$l->error("SQL statement execution failed: ($print_command):" . $d->errstr) if $l;
		return $d->errstr;
	} # end if
	$l->debug(sprintf('SQL (%.4f usecs) (%s): ', tv_interval($starttime)*1000, $print_command ) ) if DEBUG and $l;
	return;
} # end sub insert

sub upsert {
	my ( $l, $d, $table, $insert_values, $upsert_condition, $upsert_values ) = @_;

	$d = $dbh if ! $d;
	$l = $log if ! $l;

  my %commands;
  my $starttime = [gettimeofday];
  if ( ref $insert_values eq 'HASH' ) {
    %commands = %$insert_values;
  } elsif ( ref $insert_values eq 'ARRAY' ) {
    %commands = @$insert_values;
  } # end if

	my @values = values %{$insert_values};

	# we can use push and pop in here, because we actually don't care about order, only pairing
	my $command = "INSERT INTO $table (".join( ',', keys %commands ).') VALUES (';
	my $print_command = $command;

	my @command_places = ();
	my @command_values = ();
	foreach my $v ( @values ) {
		if ( ref $v eq 'ARRAY' ) {
			push @command_places, '?';
			push @command_values, '{'.join(',', map { $_ } @{$v} ).'}';
		} else {
			push @command_places, '?';
			push @command_values, $v;
		} # end if
	} # end foreach
	$command .= join(',', @command_places) .')';
	$print_command .= join(',', map { if( ref $_ eq 'ARRAY' ) { "{$_}"; } elsif( defined $_ ) { $_; } else {'undef';} } @command_values ) if @command_values;
	$print_command .= ')';
  $command .= ' ON CONFLICT ('.join(',', @{$upsert_condition}).') DO UPDATE SET ';
  $command .= join(', ', map { $_.'=?' } keys %{$upsert_values});
  push @command_values, values %{$upsert_values};

	my $sth;
	if ( ! ( $sth = $d->prepare($command) ) ) {
		$l->error( "Error Preparing SQL Statement: ($command):" . $d->errstr ) if $l;
		return $d->errstr;
	} # end if
	if ( ! $sth->execute(@command_values) ) {
		$l->error("SQL statement execution failed: ($print_command):" . $d->errstr) if $l;
		return $d->errstr;
	} # end if
	$l->debug(sprintf('SQL (%.4f usecs) (%s): ', tv_interval($starttime)*1000, $print_command ) ) if DEBUG and $l;
	return;
} # end sub upsert

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
	my @values;
	foreach my $column ( keys %commands ) {
		push @columns, "$column = ?";
		if ( ref $commands{$column} eq 'ARRAY' ) {
			push @values, '{'.join(',', map { $_ } @{$commands{$column}} ).'}';
		} else {
			push @values, $commands{$column};
		} # end if
	} # end foreach
	$command .= join( ',', @columns );
	my @conditions = ();
	if ( ref $condition eq 'ARRAY' ) {
		@conditions = @$condition;
		$command .= ' WHERE ' . shift @conditions;
	} else {
		$command .= " WHERE $condition";
	} # end if
	my $print_command = $command;
	$print_command =~ s/\?/\%s/g;
	my $sth;
	if ( ! ( $sth = $d->prepare($command) ) ) {
		$log->error( 'Error Preparing SQL Statement: ('.sprintf($print_command, @values, map { defined $_ ? $_ : 'undef' } @conditions ).'):' . $d->errstr ) if $log;
		return $d->errstr;
	} # end if
	if ( ! $sth->execute( @values, @conditions ) ) {
		$log->error('SQL statement execution failed: ('.sprintf($print_command, @values, map { defined $_ ? $_ : 'undef' } @conditions ).'):' . $d->errstr) if $log;
		return $d->errstr;
	} # end if
	
	if ( $log ) {
		my $print_command;
		if ( $command and %commands and @conditions and values %commands ) {
			$command =~ s/\?/\%s/g;
			$print_command = sprintf($command, values %commands, @conditions );
		} # end if
		$log->debug( sprintf('SQL (%.4f usecs) (%s)', tv_interval( $starttime, [gettimeofday])*1000, $print_command ) );
	} # end if

	return;
} # end sub update

sub start_transaction {
	#my ( $caller, undef, $line ) = caller;
#$openprint::log->debug("Called start_transaction from $caller : $line");
	my $d = shift;
	$d = $dbh if ! $d;
	my $ac = $d->{AutoCommit};
	$d->{AutoCommit} = 0;
	return $ac;
} # end sub start_transaction

sub end_transaction {
	#my ( $caller, undef, $line ) = caller;
#$openprint::log->debug("Called end_transaction from $caller : $line");
	my ( $d, $ac ) = @_;
if ( ! defined $ac ) {
	$log->error("Undefined ac");
}
	$d = $dbh if ! $d;
	if ( $ac ) {
		#$log->debug("Committing");
		$d->commit();
	} # end if
	$d->{AutoCommit} = $ac;
} # end sub end_transaction

1;
__END__
