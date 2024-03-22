#!/usr/bin/perl
use 5.10.0;
@INC = ( '/etc/apache2/lib/perl', @INC );
use strict;
#use warnings;
use bytes;
#use utf8;

require sql;
require configuration;
require logger;
require misc;
require openprint;
require openprint::User;


use Crypt::CBC;

use constant KEY => 'Pr1ntQu0t3s';

sub get_crypt {
    # added keysize to hash, since new versions of Crypt::CBC require it.
    return Crypt::CBC->new( {
            key            => KEY,
            keysize        => length KEY,
            cipher         => 'Blowfish',
            #regenerate_key => 0,
            literal_key   => 1,
            padding        => 'space',
            prepend_iv     => 0,
            iv             => '$KJh#(}q',
    } );
}

sub unescape {
  my ($decode) = @_;

  return undef if !defined $decode;

  $decode =~ tr/+/ /;
  $decode =~ s/%([0-9a-fA-F]{2})/pack('c', hex $1)/ge;
  return $decode;
}

my $log = $openprint::log = new logger( 'debug' );

my ( $database, $host, $login, $password ) = @ARGV;
die "No database\n" if !$database;

my %sql_server;
$sql_server{'database'} = $database;
$sql_server{'driver'}   = 'Pg';
$sql_server{'host'}   = $host;
$sql_server{'login'}    = $login;
$sql_server{'password'} = $password;

my $dbh = $openprint::dbh = sql::open_sql( $log, %sql_server );

my $crypt = get_crypt();
foreach my $user (openprint::User->find()) {
  print "Decrypting password for $$user{id} $$user{email} $$user{password} .. \n";
  if ($$user{password} =~ /\%/) {
    eval {
    print "Decrypting password for $$user{id} $$user{email} $$user{password} .. ".$crypt->decrypt(unescape($user->password()))."\n";
      $user->save({password=>$crypt->decrypt(unescape($user->password()))});
    };
  }
} # end while

$dbh->disconnect();
