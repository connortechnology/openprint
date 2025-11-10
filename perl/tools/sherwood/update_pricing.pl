#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Project;
require openprint::service;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;


$log = new logger( 'debug' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1] ? $ARGV[1] : $ARGV[0];
$sql_server{'password'} = $ARGV[2] ? $ARGV[2] : $ARGV[0];

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );
$openprint::Owner = new openprint::Company(102);

{
  my $ScorePerforating = openprint::Service->find_one(name=>'ScorePerforating');
  if ($ScorePerforating) {
    my $Perforating = $ScorePerforating->copy();
    my @prices = $ScorePerforating->Prices();
    $Perforating->name('Perforating');
    $Perforating->description('Perforating');
    my $st =  openprint::ServiceType->find_one(name=>'Perforating');
    $Perforating->servicetype_id($st->id()) if $st;
    $_ = $Perforating->save();
    die $_ if $_;
    foreach my $price (@prices) {
      $price = $price->copy();
      $price->service_id($Perforating->id());
      $price->save();
    }

    $ScorePerforating->name('Scoring');
    $ScorePerforating->description('Scoring');
    my $st =  openprint::ServiceType->find_one(name=>'Scoring');
    $ScorePerforating->servicetype_id($st->id()) if $st;
    $_ = $ScorePerforating->save();
    die $_ if $_;
  } else {
    print "ScorePerforating does not exist\n";
  }

  if (!openprint::Service->find_one(name=>'Perforating')) {
    if (my $Scoring = openprint::Service->find_one(name=>'Scoring')) {
      my $Perforating = $Scoring->copy();
      my @prices = $Scoring->Prices();
      $Perforating->name('Perforating');
      $Perforating->description('Perforating');
      my $st =  openprint::ServiceType->find_one(name=>'Perforating');
      $Perforating->servicetype_id($st->id()) if $st;
      $_ = $Perforating->save();
      die $_ if $_;
      foreach my $price (@prices) {
        $price = $price->copy();
        $price->service_id($Perforating->id());
        $price->save();
      }

    }
  }
}

{
  my $ScorePerforating = openprint::Service->find_one(name=>'ScorePerforatingMinimumCharge');
  if ($ScorePerforating) {
    my $Perforating = $ScorePerforating->copy();
    my @prices = $ScorePerforating->Prices();
    $Perforating->name('PerforatingMinimumCharge');
    $Perforating->description('Perforating Minimum Charge');
    my $st =  openprint::ServiceType->find_one(name=>'Perforating');
    $Perforating->servicetype_id($st->id()) if $st;
    $_ = $Perforating->save();
    die $_ if $_;
    foreach my $price (@prices) {
      $price = $price->copy();
      $price->service_id($Perforating->id());
      $price->save();
    }

    $ScorePerforating->name('ScoringMinimumCharge');
    $ScorePerforating->description('Scoring Minimum Charge');
    my $st =  openprint::ServiceType->find_one(name=>'Scoring');
    $ScorePerforating->servicetype_id($st->id()) if $st;
    $_ = $ScorePerforating->save();
    die $_ if $_;
  } else {
    print "ScorePerforating does not exist\n";
  }
  if (!openprint::Service->find_one(name=>'PerforatingMinimumCharge')) {
    if (my $Scoring = openprint::Service->find_one(name=>'ScoringMinimumCharge')) {
      my $Perforating = $Scoring->copy();
      my @prices = $Scoring->Prices();
      $Perforating->name('PerforatingMinimumCharge');
      $Perforating->description('Perforating Minimum Charge');
      my $st =  openprint::ServiceType->find_one(name=>'Perforating');
      $Perforating->servicetype_id($st->id()) if $st;
      $_ = $Perforating->save();
      die $_ if $_;
      foreach my $price (@prices) {
        $price = $price->copy();
        $price->service_id($Perforating->id());
        $price->save();
      }

    }
  }
}
{
  my $ScorePerforating = openprint::Service->find_one(name=>'ScorePerforationMakeReady');
  if ($ScorePerforating) {
    my $Perforating = $ScorePerforating->copy();
    my @prices = $ScorePerforating->Prices();
    $Perforating->name('PerforatingMakeReady');
    $Perforating->description('Perforating Make Ready');
    my $st =  openprint::ServiceType->find_one(name=>'Perforating');
    $Perforating->servicetype_id($st->id()) if $st;
    $_ = $Perforating->save();
    die $_ if $_;
    foreach my $price (@prices) {
      $price = $price->copy();
      $price->service_id($Perforating->id());
      $price->save();
    }

    $ScorePerforating->name('ScoringMakeReady');
    $ScorePerforating->description('Scoring Make Ready');
    my $st =  openprint::ServiceType->find_one(name=>'Scoring');
    $ScorePerforating->servicetype_id($st->id()) if $st;
    $_ = $ScorePerforating->save();
    die $_ if $_;
  } else {
    print "ScorePerforating does not exist\n";
  }
  if (!openprint::Service->find_one(name=>'PerforatingMakeReady')) {
    if (my $Scoring = openprint::Service->find_one(name=>'ScoringMakeReady')) {
      my $Perforating = $Scoring->copy();
      my @prices = $Scoring->Prices();
      $Perforating->name('PerforatingMakeReady');
      $Perforating->description('Perforating Make Ready');
      my $st =  openprint::ServiceType->find_one(name=>'Perforating');
      $Perforating->servicetype_id($st->id()) if $st;
      $_ = $Perforating->save();
      die $_ if $_;
      foreach my $price (@prices) {
        $price = $price->copy();
        $price->service_id($Perforating->id());
        $price->save();
      }

    }
  }
}

$dbh->do("DELETE FROM projecttemplate WHERE type='KnotchBound'");
$dbh->do("UPDATE projecttemplate SET type='PerfectBound', name='PerfectBound' WHERE type='PerfectBinding'");
$dbh->do("update service_types set name='Signature', url='prin/Signature.html', create_visible='N' where id=68");
1;
__END__
