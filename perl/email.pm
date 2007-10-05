package email;

use strict;

require sql;

my $dbh;

sub db_connect {
	my ( $r, $log ) = @_;
	my %info = (
		'host'		=>	$r->dir_config('mail_db_hostname'),
		'database'	=>	$r->dir_config('mail_db_name'),
		'login'		=>	$r->dir_config('mail_db_username'),
		'password'	=>	$r->dir_config('mail_db_password'),
		'driver'	=>	$r->dir_config('mail_db_driver'),
	);
	return $dbh = sql::open_sql( $log, %info );
} # end sub connect

sub set_password {
    my ( $r, $log, $email, $password ) = @_;

    db_connect( $r, $log ) if ! $dbh;

    sql::update( $log, $dbh, 'mailbox', ['username=?', $email], 'password', $password );
} # end sub set_password



sub get_vacation {
	my ( $r, $log, $email ) = @_;

	db_connect( $r, $log ) if ! $dbh; 

	my ( $subject, $message ) = sql::execute( $log, $dbh, q{SELECT subject, body FROM vacation WHERE email=?}, $email );
	if ( $message or $subject ) {
		return 1, $subject, $message;
	} # end if
} # end sub get_vacation

sub start_vacation {
	my ( $r, $log, $email, $subject, $message ) = @_;

	db_connect( $r, $log ) if ! $dbh; 

	$email =~ /(.*)\@.*/;
	my $autoreply_address = $1.'@'.$r->dir_config('mail_autoreply_domain');

	sql::execute( $log, $dbh, q{DELETE FROM vacation_cache WHERE to_email=?}, $email );
	sql::execute( $log, $dbh, q{DELETE FROM vacation WHERE email=?}, $email );
	sql::insert( $log, $dbh, 'vacation', 
		'email',	$email,
		'subject',	$subject,
		'body',		$message,
		'domain',	$autoreply_address,
		'created',	'NOW()',
		);
	my @aliases;
	( $_ ) = sql::execute( $log, $dbh, q{SELECT goto FROM alias WHERE address=?}, $email );
	foreach my $alias ( split( ',', $_ ) ) {
		push @aliases, $alias unless $alias =~ /autoreply/;
	} # end foreach alias
	push @aliases, $autoreply_address;
	sql::update( $log, $dbh, 'alias', "address='$email'", 'goto', join(',', @aliases ), 'modified', 'NOW()' );

} # end sub set_vacation

sub stop_vacation {
	my ( $r, $log, $email ) = @_;

	db_connect( $r, $log ) if ! $dbh; 

	sql::execute( $log, $dbh, q{DELETE FROM vacation_cache WHERE to_email=?}, $email );
	sql::execute( $log, $dbh, q{DELETE FROM vacation WHERE email=?}, $email );

	my @aliases;
	( $_ ) = sql::execute( $log, $dbh, q{SELECT goto FROM alias WHERE address=?}, $email );
	foreach my $alias ( split( ',', $_ ) ) {
		push @aliases, $alias unless $alias =~ /autoreply/;
	} # end foreach alias
	sql::update( $log, $dbh, 'alias', "address='$email'", 'goto', join(',', @aliases ), 'modified', 'NOW()' );

} # end sub stop_vacation

1;
__END__
