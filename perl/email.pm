use strict;
package email;

use openprint ();
use warnings;
use vars qw( %config $log );
*log = \$openprint::log;
*config = \%openprint::config;

require sql;

my $dbh;

sub db_connect {
	if ( $config{mail_db_name} ) {
# Fairly important to us the config hash.  r->dir_config causes crashes
		$dbh = sql::open_sql( $openprint::log, 
				(
				 'host'		=>	$config{mail_db_hostname},
				 'database'	=>	$config{mail_db_name},
				 'login'	=>	$config{mail_db_username},
				 'password'	=>	$config{mail_db_password},
				 'driver'	=>	$config{mail_db_driver},
				) );
	} # end if;
	return $dbh;
} # end sub connect

sub set_password {
    my ( $email, $password ) = @_;

    $dbh = db_connect() if ! $dbh;

    sql::update( $log, $dbh, 'mailbox', ['username=?', $email], 'password', $password );
} # end sub set_password

sub get_vacation {
	my ( $email ) = @_;

	$dbh = db_connect() if ! $dbh; 
	if ( $dbh ) {
		my ( $subject, $message, $system_emails ) = sql::execute( $log, $dbh, q{SELECT subject, body, system_emails FROM vacation WHERE email=?}, $email );
		if ( $message or $subject ) {
			return 1, $subject, $message, $system_emails;
		} # end if
	} # end if
	return;	
} # end sub get_vacation

sub get_vacation_entry {
    my ( $email ) = @_;

    $dbh = db_connect() if ! $dbh;
    if ( $dbh ) {
		my $data = $dbh->selectall_arrayref( 'SELECT * FROM vacation WHERE email=?', { Slice => {} }, $email );
		if ( $data and @{$data} ) {
			return $data[0];
		}
    } # end if
    return;
} # end sub get_vacation


sub start_vacation {
	my ( $email, $subject, $message, $system_emails ) = @_;

	$dbh = db_connect() if ! $dbh; 

	$email =~ /(.*)\@.*/;
	my $autoreply_address = $1.'@'.$config{mail_autoreply_domain};

	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE vacation IN ACCESS EXCLUSIVE MODE' ) or $log->error( $dbh->errstr );
	sql::execute( $log, $dbh, q{DELETE FROM vacation_cache WHERE to_email=?}, $email );
	sql::execute( $log, $dbh, q{DELETE FROM vacation WHERE email=?}, $email );
	sql::insert( $log, $dbh, 'vacation', 
		'email',	$email,
		'subject',	$subject,
		'body',		$message,
		'domain',	$autoreply_address,
		'system_emails',	$system_emails,
		'created',	'NOW()',
		);
	my @aliases;
	( $_ ) = sql::execute( $log, $dbh, q{SELECT goto FROM alias WHERE address=?}, $email );
	foreach my $alias ( split( ',', $_ ) ) {
		push @aliases, $alias unless $alias =~ /autoreply/;
	} # end foreach alias
	push @aliases, $autoreply_address;
	sql::update( $log, $dbh, 'alias', ['address=?', $email], 'goto', join(',', @aliases ), 'modified', 'NOW()' );
	sql::end_transaction( $dbh, $ac );

} # end sub set_vacation

sub stop_vacation {
	my ( $email ) = @_;

	$dbh = db_connect() if ! $dbh; 

	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE vacation IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
	sql::execute( $log, $dbh, q{DELETE FROM vacation_cache WHERE to_email=?}, $email );
	sql::execute( $log, $dbh, q{DELETE FROM vacation WHERE email=?}, $email );

	my @aliases;
	( $_ ) = sql::execute( $log, $dbh, q{SELECT goto FROM alias WHERE address=?}, $email );
	if ( $_ ) {
	foreach my $alias ( split( ',', $_ ) ) {
		push @aliases, $alias unless $alias =~ /autoreply/;
	} # end foreach alias
	sql::update( $log, $dbh, 'alias', ['address=?', $email], 'goto', join(',', @aliases ), 'modified', 'NOW()' );
	} # en dif
	sql::end_transaction( $dbh, $ac );

} # end sub stop_vacation

sub aliases {
	my ( $email, @new ) = @_;

	my @aliases;
	my $auto_alias = '';
	my $me = '';
	if ( ( $_ ) = sql::execute( $log, $dbh, q{SELECT goto FROM alias WHERE address=?}, $email ) ) {
		foreach my $alias ( split( ',', $_ ) ) {
			$alias =~ s/\n//g;
			$alias =~ s/\r//g;
			if ( $alias =~ /autoreply/ ) {
				$auto_alias = $alias;
			} elsif ( $alias eq $email ) {
				$me = $alias;
			} elsif ( ! $alias ) {

			} else {
				push @aliases, $alias;
			} # end if
		} # end foreach alias
	} # end if
	if ( @new ) {
		@aliases = ();
		foreach my $alias ( @new ) {
			$alias =~ s/\n//g;
			$alias =~ s/\r//g;
			next if ! $alias;
			next if $alias eq $email;
			next if $alias =~ /autoreply/;
			push @aliases, $alias;
		} # end foreach
		push @aliases, $auto_alias if $auto_alias;
		push @aliases, $me if $me;
		sql::update( $log, $dbh, 'alias', ['address=?', $email], 'goto', join(',', @aliases ), 'modified', 'NOW()' );
	} # end if
	return @aliases;
} # end sub get_aliases

sub domains {
	$dbh = email::db_connect() if ! $dbh;
	if ( ! $dbh ) {
		$openprint::log->debug("No connection to mail database");
		return ();
	} # end if;
	my $domains = $dbh->selectall_arrayref( 'SELECT * FROM domain', { Slice => {} } );
	if ( $domains ) {
		return map { $$_{domain} } @{$domains};
	}  # end if
	$openprint::log->debug("No domains found");
	return ();
} # end sub domains

1;
__END__
