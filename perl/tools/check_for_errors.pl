#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;
use warnings;

require sql;
require logger;
require openprint::Object;
require openprint::Company;
require openprint::User;
require openprint::Project;
require openprint::Quote;
require openprint::Order;
require openprint::Fold;
require openprint::ScheduledJob;
require openprint::Pricelist;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
die "No dbh" if ! $dbh;
	
my @defaultPricelist = openprint::Pricelist->find('name'=>'default');
my $default;
if ( ! @defaultPricelist ) {
	$log->warn("There is no default Pricelist");
} else {
	$default = $defaultPricelist[0];
} # end if

foreach my $Paper ( openprint::Paper->find('supplied'=>'N') ) {

	# Only quotable stock needs to have prices
	next if ! $Paper->recommendations();

	foreach my $Pricelist ( openprint::Pricelist->find() ) {
		if ( ! openprint::PaperPrice->find('paper_id'=>$$Paper{id}, 'pricelist_id'=>$$Pricelist{id}) ) {
			$log->warn ( 'Paper ' . $Paper->to_string() . ' does not have a price for pricelist : ' . $Pricelist->name() );
if ( 0 ) {
			if ( my @Prices = openprint::PaperPrice->find('paper_id'=>$$Paper{id}, 'Pricelist_id'=>$$default{id} ) ) {
				foreach my $Price ( @Prices ) {
					my $NewPrice = $Price->copy();
					$$NewPrice{'PricelistIndex'} = $Pricelist->id();
					$NewPrice->save();
				} # end foreach Price
			} # end if
} # end if
			
		} # end if
	} # end foreach
} # end foreach Paper

if ( openprint::ProjectType->find_one() ) {
	foreach my $Product ( openprint::Product->find() ) {
		if ( ! $Product->project_id() ) {
			$log->warn( 'Product ' . $Product->name() . ' does not have a template assigned.' );
		} # end if
	} # end foreach Product
} # end if

foreach my $Fold ( openprint::Fold->find() ) {
	foreach my $FS ( openprint::FoldSpecification->find(fold_id=>$$Fold{id}) ) {
		if ( $$FS{'interpolate'} and ( $$FS{min_weight} != $$FS{max_weight} ) ) {
			$log->error( sprintf('Fold %s on %s has invalid interpolate/min_weight/max_weight settings', $Fold->name(), $Fold->Equipment()->name() ) );
			last;
		} # end if
	} # end foraech my $FS
} # end foraech my $Folf

if ( 0 ) {
	foreach my $PO ( openprint::PurchaseOrder->find('order'=>'id desc') ) {
		if ( $PO->subtotal() > $PO->total() - $PO->payments_total() ) {
			$log->error('PO ' . $PO->id() . ' has an invalid total.' . $PO->subtotal() . ' > ' . $PO->total() );
		#$PO->save();
			next;
		} 
		my $tax_total;
		foreach my $Tax ( $PO->Taxes() ) {
			$tax_total += $Tax->amount();
		} # end if
		$tax_total = Math::Round::nearest( 0.01, $tax_total);
		my $total = Math::Round::nearest( 1, $PO->subtotal() + $tax_total - $PO->payments_total() );

		if ( ($tax_total > 0) and ( $total != Math::Round::nearest( 1, $PO->total()) ) ) {
			$log->error(sprintf('PO %1$d has an invalid total. %2$s != %3$s + %4$s -%7$s: %5$s for %6$s', $PO->id(), $PO->total(), $PO->subtotal(), $tax_total, $total, $PO->vendor_name(), $PO->payments_total() ) );

			$log->error("q to quit, n for next, enter to try to fix it.");
			my $input = <STDIN>;
			last if $input eq 'q';
			next if $input eq 'n';

			$PO->save();

			my $tax_total;
			foreach my $Tax ( $PO->Taxes() ) {
				$tax_total += $Tax->amount();
			} # end if
			$tax_total = Math::Round::nearest( 0.01, $tax_total);
			my $total = Math::Round::nearest( 1, $PO->subtotal() + $tax_total );

			if ( ($tax_total > 0) and ( $total != Math::Round::nearest( 1, $PO->total()) ) ) {
				$log->error("Not fixed.");
				$log->error(sprintf('PO %1$d has an invalid total. %2$s != %3$s + %4$s : %5$s for %6$s', $PO->id(), $PO->total(), $PO->subtotal(), $tax_total, $total, $PO->vendor_name() ) );
			}

		} 
	} # end foreach
}

foreach my $Job ( openprint::ScheduledJob->find() ) {
	if ( ! $Job->Shift() ) {
		$log->error('No shift for job ' . $Job->to_string());
	} # end if
} # end foreach

foreach my $Project ( openprint::Project->find( 
	'created_on >=' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -60 ) ),
	order	=>	'id DESC',
) ) {
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		my $current_price = $Project->price($qty_index);

		if ( int($current_price) != int($Project->price($qty_index,undef)) ) {
			$log->error("Bad price for project $$Project{id}: current: $current_price, should be " . $Project->price($qty_index) );
			foreach my $QP ( openprint::QuotedProject->find(project_id=>$$Project{id}) ) {
				$log->error("Is in quote $$QP{quote_id}");
			}
			$log->error("q to quit, n for next, enter to try to fix it.");
			my $input = <STDIN>;
			last if $input eq 'q';
			next if $input eq 'n';
			$Project->save();

		} else {
			$log->warn("Good price for $$Project{id} $qty_index $current_price == " . $Project->price($qty_index) );
		} # end if
	} # end foreach
} # end foreach
$dbh->disconnect();
1;
__END__
