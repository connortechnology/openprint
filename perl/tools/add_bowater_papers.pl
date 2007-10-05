#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Paper;
require openprint::Pricelist;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'point-one';
$sql_server{'password'} = 'point-1';

$dbh = sql::open_sql( $log, %sql_server );

my $Paper = new openprint::Paper();
$Paper->name('#4 BOBRITE 80');
$Paper->finish('Coated 2 Sides');
$Paper->colour('White (80)');
$Paper->weight('38lb');
$Paper->gsm(56);
$Paper->type('Roll');
$Paper->grade(4);
$Paper->quality('new');
$Paper->grain_direction('Long');
$Paper->basis_width(25);
$Paper->basis_height(38);
$Paper->calliper(0.002);
$Paper->multipart( 0 );
$Paper->cuttable( 1 );
$Paper->doublesided( 1 );
$Paper->perfecting( 0 );
$Paper->taxexempt1( 0 );
$Paper->taxexempt2( 0 );
$Paper->score_required( 0 );
$Paper->manufacturer( 'APP' );
$Paper->owner_id( 6 );
@{$$Paper{'recommendations'}} = ( 'Brochures','Flyers','MultiPagePublication','PressSheetCombination','ScratchPads','Covers','Inserts','Custom','Letterhead','Posters' );

foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(52.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(51.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if

delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('40lb');
$Paper->gsm(60);
$Paper->calliper(0.00204);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(51.5/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(50.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('45lb');
$Paper->gsm(67);
$Paper->calliper(0.00225);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(48.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(47.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('50lb');
$Paper->gsm(74);
$Paper->calliper(0.0025);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(47.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(46.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('60lb');
$Paper->gsm(89);
$Paper->calliper(0.0031);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(47.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(46.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if

# BOBRITE 76
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->name('#3 BOBRITE 76');
$Paper->weight('38lb');
$Paper->gsm(56);
$Paper->calliper(0.0020);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(50.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(49.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('40lb');
$Paper->gsm(60);
$Paper->calliper(0.0021);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(48.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(47.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('45lb');
$Paper->gsm(67);
$Paper->calliper(0.00227);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(46.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(45.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('50lb');
$Paper->gsm(74);
$Paper->calliper(0.00260);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(45.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(44.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('60lb');
$Paper->gsm(89);
$Paper->calliper(0.00311);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(45.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(43.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->name( '#5 BOGLOSS  (72 Bright)');
$Paper->weight('32lb');
$Paper->gsm(47);
$Paper->calliper(0.0019);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(54.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(53.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('34lb');
$Paper->gsm(50);
$Paper->calliper(0.00195);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(52.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(51.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('36lb');
$Paper->gsm(53);
$Paper->calliper(0.002);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(49.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(48.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('38lb');
$Paper->gsm(56);
$Paper->calliper(0.002);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(47.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(46.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('40lb');
$Paper->gsm(60);
$Paper->calliper(0.0021);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(45.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(44.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('45lb');
$Paper->gsm(67);
$Paper->calliper(0.0024);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(44.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(43.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('50lb');
$Paper->gsm(74);
$Paper->calliper(0.00265);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(43.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(42.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('60lb');
$Paper->gsm(89);
$Paper->calliper(0.00315);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(43.9/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(42.9/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->name('#3 BOMAX 84');
$Paper->weight('40lb');
$Paper->gsm(60);
$Paper->calliper(0.002);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(57.5/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(56.5/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('45lb');
$Paper->gsm(67);
$Paper->calliper(0.0024);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(54.5/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(53.5/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('50lb');
$Paper->gsm(74);
$Paper->calliper(0.0026);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(52.5/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(51.5/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('60lb');
$Paper->gsm(89);
$Paper->calliper(0.0031);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(49.5/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(48.5/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
delete $$Paper{id};
delete $$Paper{Prices};

$Paper->weight('70lb');
$Paper->gsm(104);
$Paper->calliper(0.0036);
foreach my $Pricelist ( openprint::Pricelist::find() ) {
	my $P1 = new openprint::PaperPrice();
	$P1->PricelistIndex($Pricelist->id());
	$P1->Min(1);
	$P1->Max(120000);
	$P1->Units('Per 100lbs');
	$P1->Cost(49.5/.94);
	$P1->Markup(10);
	$P1->Discountable('N');

	push @{$$Paper{'Prices'}}, $P1;

	my $P2 = new openprint::PaperPrice();
	$P2->PricelistIndex($Pricelist->id());
	$P2->Min(120001);
	$P2->Units('Per 100lbs');
	$P2->Cost(48.5/.94);
	$P2->Markup(10);
	$P2->Discountable('N');
	push @{$$Paper{'Prices'}}, $P2;
} # end foreach
$_ = $Paper->save();
if ( $_ ) {
	$log->error($_);
} # end if
