use strict;
#use warnings;
package openprint::pricing;
use Memoize;
use Carp qw( cluck );

require openprint::pricelist;
require openprint::priceset;
require openprint::price;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use constant DEBUG => 0;

my %price_cache;

sub clear_cache {
	%price_cache = ();
} # end sub clear_cache

sub init_cache {
	$price_cache{$config{db_name}} = {};
	#my @Services = openprint::Service->find(); # for cachine	
	#my @Materials = openprint::Material->find(); # for cachine	
	#my @Pricelists = openprint::Pricelist->find();

	my @ServicePrices = openprint::ServicePrice->find( 'period_end is null'=>1, order=>'min NULLS FIRST, max NULLS FIRST');
	my @MaterialPrices = openprint::MaterialPrice->find( order=>'lngmin NULLS FIRST, lngmax NULLS FIRST');
	my $Pricelist = $openprint::Pricelist;
	#foreach my $Pricelist ( @Pricelists ) {
		$$Pricelist{cache}{'openprint::Service'} = $$Pricelist{cache}{'openprint::Material'} = $$Pricelist{cache} = {};
		my $cache = $$Pricelist{cache}{'openprint::Service'};
	
		foreach my $S ( @ServicePrices ) {
			next if $$S{pricelist_id} != $$Pricelist{id};
			#if ( ! $price_cache{$config{db_name}}{$$Pricelist{id}}{'openprint::Service'}{$S->service_id()} ) {
				#$price_cache{$config{db_name}}{$$Pricelist{id}}{'openprint::Service'}{$S->service_id()} = [];
			#} # end if
			if ( ! $$cache{$$S{service_id}} ) {
				$$cache{$$S{service_id}} = [];
			}
			#push @{$price_cache{$config{db_name}}{$$Pricelist{id}}{'openprint::Service'}{$S->service_id()}}, $S;
			push @{$$cache{$$S{service_id}}}, $S;
		} # end foreach ServicePrice
		$cache = $$Pricelist{cache}{'openprint::Material'};
		foreach my $P ( @MaterialPrices ) {
			next if $$P{pricelist_id} != $$Pricelist{id};
#'period_end is null'=>0, 
			if ( ! $$cache{$$P{material_id}} ) {
				$$cache{$$P{material_id}} = [];
			} # end if
			push @{$$cache{$$P{material_id}}}, $P;
		} # end foreach ServicePrice
	#} # end foreach Pricelist
	#foreach my $Service ( @Services ) {
		#$Service->Prices( [ map { $price_cache{$config{db_name}}{$$_{id}}{'openprint::Service'}{$$Service{id}} ? $price_cache{$config{db_name}}{$$_{id}}{'openprint::Service'}{$$Service{id}} : () } @Pricelists ] );
	#} # end foreach Service
	#foreach my $Material ( @Materials ) {
		#$Material->Prices( [ map { $price_cache{$config{db_name}}{$$_{id}}{'openprint::Material'}{$$Material{id}} ? $price_cache{$config{db_name}}{$$_{id}}{'openprint::Material'}{$$Material{id}} : () } @Pricelists ] );
	#} # end foreach Service
#}
}

sub get_pricelist_id {

	if ( $openprint::session{'Pricelist_id'} ) {
		# Validity of session variables is the job of openprint.pm, so it is done once per hit
		return $openprint::session{'Pricelist_id'};
	} # end if

	my $list_id;

	if ( $openprint::session{company_id} > 0 ) {
		my $Company = new openprint::Company( $openprint::session{company_id} );
		$list_id = $Company->pricelist_id();
		if ( (! $list_id ) and $Company->country() ) {
			$list_id = $openprint::config{'Default'.$Company->country().'Pricelist'};
		} # end if
	} # end if
	if ( ( ! $list_id ) and $openprint::session{'Country'} ) {
		$list_id = $openprint::config{'Default'.$openprint::session{'Country'}.'Pricelist'};
	}  # end if
	$list_id = $openprint::config{'DefaultPricelist'} if ! $list_id;
	if ( ! $list_id ) {
		$openprint::log->debug("No pricelist to be had! Country: $openprint::session{'Country'}" );
	} # end if
	
	$openprint::session{'Pricelist_id'} = $list_id;
	return $list_id;
} # end sub get_pricelist_id

#memoize('find_price');
# returns an index into the passed array of the price entry that fits the specified quantity.
# if $qty = '' then it will return the last entry
# if the price array is empty, it will return -4, which isn't good.
sub find_price {
	my $qty = shift;
	for ( my $index = 0; $index < @_; $index += 1 ) {
 		if ( $qty ne '' ) {
			if ( $qty <= $_[$index]->{max} or $_[$index]->{max} eq '' ) {
				return $index;
			} # end if
		} else {
# Do this the ugly way as an optimisation when we don't care about the quantity and there are lots of options
			return $index;
		} # end if
	} # end for
	
	return @_ - 1;
} # end sub find_price

sub get_increment {
	my $number = shift;
	$number =~ /\d*.(\d*)/;
	return 1 / ( 10 ** (length $1) );
} # end sub get_imcrement

# takes two prices, and returns the results of a merge between them.
# So the result could be one price, or two prices.
# $price1 and $price2 are expected to be in sorted order.
sub merge_prices {
	my ( $price1, $price2 );

	if ( $_[0]{price} > $_[1]{price} ) {
		( $price2, $price1 ) = @_;
	} elsif ( $price1->{equipment_id} != $price2->{equipment_id} ) {
		return @_;
	} else {
		( $price1, $price2 ) = @_;
	} # end if
	my @prices = ( $price1 );

	# now Price1 has the lower price.
	if ( $price1->{min} ne '' and ( $price2->{min} < $price1->{min} or $price2->{min} eq '' ) ) {
		# tack on a price in front
		my $newprice = openprint::price->new( $openprint::log, '' );
		$newprice->copy( $price2 );
		my $increment = get_increment( $price1->{min} );
		$newprice->setMax( $price2->{max} < $price1->{min} - $increment ? $price2->{max} : $price1->{min} - $increment );
		unshift @prices, $newprice;
	} # end if

	if ( $price1->{max} ne '' and ( $price2->{max} > $price1->{max} or $price2->{max} eq '' ) ) {
		my $newprice = openprint::price->new( $openprint::log, '' );
		$newprice->copy( $price2 );
		my $increment = get_increment( $price1->{max} );
		$newprice->setMin( $price2->{min} > $price1->{max} + $increment ? $price2->{min} : $price1->{max} + $increment );
		push @prices, $newprice;
	} # end if
	return @prices;
} # end sub merge_prices

# builds an array of prices with a linear quantity range.
# the prices for each quantity range are the lowest possible.
sub build_lowest_price_list {
	my @returned = shift @_;

	# basically, we process each entry in the huge list of prices, and fit them into a returned list
	while ( @_ ) {
		# pull and entry off
		my $price = shift @_;
		# Get the appropriate price entry in the returned list.
		my $price_index = find_price( $price->{max}, @returned );
		# so all prices higher than price_index are for quantities higher than the current

		splice @returned, $price_index, 1, merge_prices( $returned[$price_index], $price );
		# while min of our returned entry is less than the requested min, or requested min is nothing,
		# basically, this says if our returned entry is appropriate.	You see, we travel upward through 
		# our returned list trying to find the right place to put our new entry.
		while ( ( $price_index > 0 ) and ( $returned[$price_index]->{min} <= $price->{min} or $price->{min} eq '' ) ) {
			$price_index -= 1;
			splice( @returned, $price_index, 2, merge_prices( $returned[$price_index], $returned[$price_index+1] ) );
		} # end while
	} # end while

	return @returned;
} # end sub build_lowest_price_list

sub split_by_equipment {
	my %lists;

	foreach my $price ( @_ ) {
		push @{$lists{$price->{equipment_index}}}, $price;
	} # end foreach
	return %lists;
} # end sub split_by_equipment

#memoize('get_best_prices');
sub get_best_prices {
	my ( $cust_id, $prod_index, $list_id, $Object, $equipment, $qty, $period ) = @_;

	if ( ! $list_id ) {
		$log->error("Not specifying pricelist to get_best_prices is deprecated");
		Carp::cluck("Not specifying pricelist to get_best_prices is deprecated");
# figure out which price list we select from, because the caller didn't specify.
		$list_id = get_pricelist_id();
	} # end if

		my @pricing = ();
if ( DEBUG ) {
	$openprint::log->debug("Pricing: " . @pricing );
}
	my $price_type = ref $Object;
	if ( $price_type and $price_cache{$config{db_name}}{$list_id}{$price_type}{$$Object{name}} ) {
		@pricing = @{$price_cache{$config{db_name}}{$list_id}{$price_type}{$$Object{name}}};
	} else {
$log->warn("Request for old style price for $Object");
		my $priceGroup = $Object->new( $log, $dbh, $list_id, $prod_index, $equipment, $qty, $period );
		$priceGroup->load();	
		push @pricing, @{$priceGroup->{prices}};
	}

# We should do this later...

# Now if we are a customer, then we have more to do, including special pricing, adding discounts, etc. 
	if ( $cust_id != 0 ) {
		my $Company = new openprint::Company( $cust_id );

		my $pricingpercent = $Company->discount();
		if ( $pricingpercent ) {
			$pricingpercent = 1 - ($pricingpercent/100);
			for ( my $index = 0; $index < @pricing; $index += 1 ) {
				if ( $pricing[$index]->{Discountable} ne 'N' ) {

# the if here is to preserve empty pricing.	if pricei s empty, we display call, instead of 0.00.
					if ( $pricing[$index]->{Price} ne '' ) {
						$pricing[$index]->{Price} *= $pricingpercent;
					} # end if
				} # end if
			} # end for
		} # end if
	} # end if
	if ( $openprint::config{'ApplyMarkup'} ) {
#$openprint::log->debug("Apply Markup: $openprint::config{'ApplyMarkup'}");	
		my $pricingpercent = $openprint::config{'ApplyMarkup'};
		$pricingpercent =~ s/[^\d\.\-]//g;
		$pricingpercent /= 100;
		$pricingpercent += 1;
		for ( my $index = 0; $index < @pricing; $index += 1 ) {
# the if here is to preserve empty pricing.	if pricei s empty, we display call, instead of 0.00.
			if ( $pricing[$index]->{Price} ne '' ) {
				$pricing[$index]->{Price} *= $pricingpercent;
			} # end if
		} # end for
	} # end if

	my @prices;
	if ( $equipment ) {
		@prices = build_lowest_price_list( @pricing );
	} else {
		my %lists = split_by_equipment( @pricing );
		foreach my $key ( keys %lists ) {
			push @prices, build_lowest_price_list( @{$lists{$key}} );
		} # end foreach
	} # end if

	return \@prices;
} # end sub get_best_prices

sub get_Price {
	my ( $Object, $Pricelist, $qty, $Equipment, $period ) = @_;

	my $type = ref $Object;
	my @Prices;
	my $Price;

	$Pricelist = $openprint::Pricelist if ! $Pricelist;

	# If we specify a period, then forget about the caching.  Caching will only do current prices.
	#if ( $period ) {
	#}
	if ( $$Pricelist{cache}{$type}{$$Object{id}} ) {
if ( ref $$Pricelist{cache}{$type}{$$Object{id}} eq 'HASH' ) {
$_ = Data::Dumper::Dumper( $$Pricelist{cache}{$type}{$$Object{id}} );
$log->debug($_);
}
		@Prices = @{$$Pricelist{cache}{$type}{$$Object{id}}};
	} else {
		$$Pricelist{cache}{$type}{$$Object{id}} = [$Object->Prices_For_Pricelist($Pricelist)];
		@Prices = @{$$Pricelist{cache}{$type}{$$Object{id}}};
		$log->error("Prices not cached for $config{db_name} pricelist: $$Pricelist{id} type $type $$Object{name}");
	}
	if ( @Prices ) {

		my @Equipment_Prices;
		if ( $Equipment ) {
			@Equipment_Prices = map { $$_{equipment_id} == $$Equipment{id} ? $_ : () } @Prices;
			@Equipment_Prices = map { defined $$_{equipment_id} ? () : $_ } @Prices if ! @Equipment_Prices;
			@Prices = @Equipment_Prices;
		} # end if

		if ( ! defined $qty or $qty eq '' ) {
			$Price = $Prices[0];
		} else {	
			foreach my $P ( @Prices ) {
				#$log->debug("Need $qty, equipment: $$P{equipment_id} $$Object{name} min: $$P{min} max: $$P{max} ");
				if ( 
						( ( ! defined $P->{min} ) or $P->{min} <= $qty ) and 
						( ( ! defined $P->{max} ) or $P->{max} >= $qty )
				   ) {
					$Price = $P;
#->clone();
				} # end if
			} # end foreach
		} # end if qty
	} # end if

	if ( $Price and $$Price{price} ) {
		if ( $openprint::session{company_id} or $openprint::config{'ApplyMarkup'} ) {
			$Price = $Price->clone();
		}
		if ( $openprint::session{company_id} != 0 ) {
			my $Company = new openprint::Company( $openprint::session{company_id} );

			my $pricingpercent = $Company->discount();
			if ( $pricingpercent ) {
				$pricingpercent = 1 - ($pricingpercent/100);
				if ( $Price->{discountable} ne 'N' ) {

# the if here is to preserve empty pricing. if pricei s empty, we display call, instead of 0.00.
					$Price->{price} *= $pricingpercent;
				} # end if
			} # end if
		} # end if

		if ( $openprint::config{'ApplyMarkup'} ) {
#$openprint::log->debug("Apply Markup: $openprint::config{'ApplyMarkup'}"); 
			my $pricingpercent = $openprint::config{'ApplyMarkup'};
			$pricingpercent =~ s/[^\d\.\-]//g;
			$pricingpercent /= 100;
			$pricingpercent += 1;
# the if here is to preserve empty pricing. if pricei s empty, we display call, instead of 0.00.
			$Price->{price} *= $pricingpercent;
		} # end if
	} # end if
	return $Price;
}

#memoize('get_best_price_object');
sub get_best_price {
	my ( $cust_id, $prod_index, $list_id, $pricesetclass, $qty, $equipment, $period ) = @_;

	my %price = get_best_price_object( $cust_id, $prod_index, $list_id, $pricesetclass, $qty, $equipment, $period );
	return $price{price};
} # end sub get_best_price 

sub get_best_price_object {
	my ( $cust_id, $prod_index, $list_id, $pricesetclass, $qty, $equipment, $period ) = @_;
	my $prices = get_best_prices( $cust_id, $prod_index, $list_id, $pricesetclass, $equipment, $qty, $period );
if ( DEBUG ) {
	$openprint::log->debug("Prices in get_best_price_obejct" . @$prices);
	foreach my $price ( @$prices ) {
		$openprint::log->debug("$$price{min} $$price{max} $$price{price}");
	} # end foreach
	
}
	foreach my $price ( @$prices ) {
		if ( $price and ( 
					( (!defined $qty) or $qty eq '' ) or
					( 
					 ( ( $price->{min} eq '' or ! defined $price->{min} ) or 1*$price->{min} <= $qty ) and 
					 ( ( $price->{max} eq '' or ! defined $price->{max} ) or 1*$price->{max} >= $qty )
					)
) ) {
			return %$price;
		} # end if
	} # end foreach
	return;
} # end sub get_best_price 

sub adjust_price {
	my ( $Price, $options ) = @_;
	if ( $openprint::config{'ApplyMarkup'} ) {
#$openprint::log->debug("Apply Markup: $openprint::config{'ApplyMarkup'}");	
		my $pricingpercent = $openprint::config{'ApplyMarkup'};
		$pricingpercent =~ s/[^\d\.\-]//g;
		$pricingpercent /= 100;
# the if here is to preserve empty pricing.	if pricei s empty, we display call, instead of 0.00.
		if ( $$Price{price} ne '' ) {
			$$Price{price} *= ( 1 + $pricingpercent );
		} # end if
	} # end if
	return openprint::Currency::convert( $Price );
} # end sub adjust_price

1;
__END__
