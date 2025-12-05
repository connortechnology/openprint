#!/usr/bin/perl -w
use lib '/var/www/pqs/perl';
use strict;
use warnings;
use utf8;

require sql;
require logger;
require openprint::Object;
require openprint::Company;

require openprint;
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
my %options;

$openprint::Object::no_cache = 1;
$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[0] if ! $ARGV[2];
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2],
    'host'=>$ARGV[3] ? $ARGV[3] : 'localhost') );
die "not Connected\n" unless $dbh;

foreach my $company (openprint::Company->find()) {
  my $new_name = $company->transform(name=>$company->name());
  print "New name $new_name\n";
  utf8::encode($new_name);
  print "New name $new_name\n";
  if ($company->name() ne $new_name) {
    if (confirm("Change company name from $$company{name} to $new_name?", 'Y')) {
      $company->save({name=>$new_name});
    }
  }
}

sub confirm {
  my $prompt = shift;
  my $default = @_ ? lc shift : 'y';
  print $prompt ? $prompt : "Confirm? (Y|n)";
  if ( $options{y} ) {
    print "Y\n";
    return 1;
  }
  if ( $options{n} ) {
    print "N\n";
    return 0;
  }
  $_=<STDIN>; chomp;
  return 1 if $_ and ( lc($_) eq 'y');
  return 1 if (!$_) and (lc $default eq 'y');
  return 0;
}
$dbh->disconnect();
1;
__END__
