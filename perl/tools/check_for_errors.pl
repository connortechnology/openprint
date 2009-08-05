#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Company;
require openprint::User;
require openprint::Project;
require openprint::Quote;
require openprint::Order;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2]) );
	
my @defaultPricelist = openprint::Pricelist::find('name'=>'default');
my $default;
if ( ! @defaultPricelist ) {
	$log->warn("There is no default Pricelist");
} else {
	$default = $defaultPricelist[0];
} # end if

foreach my $Paper ( openprint::Paper::find() ) {

	# Only quotable stock needs to have prices
	next if ! $Paper->recommendations();

	foreach my $Pricelist ( openprint::Pricelist::find() ) {
		if ( ! openprint::PaperPrice::find('Paper'=>$Paper, 'Pricelist'=>$Pricelist) ) {
			$log->warn ( 'Paper ' . $Paper->to_string() . ' does not have a price for pricelist : ' . $Pricelist->name() );
if ( 0 ) {
			if ( my @Prices = openprint::PaperPrice::find('Paper'=>$Paper, 'Pricelist'=>$default ) ) {
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

foreach my $Product ( openprint::Product::find() ) {
	if ( ! $Product->project_id() ) {
		$log->warn( 'Product ' . $Product->name() . ' does not have a template assigned.' );
	} # end if
} # end foreach Product
$dbh->disconnect();
1;
__END__
