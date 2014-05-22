use strict;
package openprint::pricing;
use Memoize;
use Carp qw( cluck );

require openprint::pricelist;
require openprint::priceset;
require openprint::price;

use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

use constant DEBUG => 1;

my %price_cache;

sub clear_cache {
	%price_cache = ();
} # end sub clear_cache

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

	if ( $_[0]{Price} > $_[1]{Price} ) {
		( $price2, $price1 ) = @_;
	} elsif ( $price1->{equipment_index} != $price2->{equipment_index} ) {
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

memoize('get_best_prices');
sub get_best_prices {
	my ( $cust_id, $prod_index, $list_id, $pricesetclass, $equipment, $qty, $period ) = @_;

	#my $hash_index = "$list_id-$pricesetclass-$cust_id-$prod_index-$equipment-$qty";

	#if ( ! defined $price_cache{$hash_index} ) {

		if ( ! $list_id ) {
$log->error("Not specifying pricelist to get_best_prices is deprecated");
Carp::cluck("Not specifying pricelist to get_best_prices is deprecated");
# figure out which price list we select from, because the caller didn't specify.
			$list_id = get_pricelist_id();
		} # end if

		my @pricing = ();
		my $priceGroup = $pricesetclass->new( $log, $dbh, $list_id, $prod_index, $equipment, $qty, $period );
		$priceGroup->load();	
		push @pricing, @{$priceGroup->{prices}};
if ( DEBUG ) {
	$openprint::log->debug("Pricing: " . @pricing );
}

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
		#$price_cache{$hash_index} = [ @prices ];
	#} # end if

	return \@prices;
	#return $price_cache{$hash_index};
} # end sub get_best_prices

#memoize('get_best_price_object');
sub get_best_price {
	my ( $cust_id, $prod_index, $list_id, $pricesetclass, $qty, $equipment, $period ) = @_;

	my %price = get_best_price_object( $cust_id, $prod_index, $list_id, $pricesetclass, $qty, $equipment, $period );
	return $price{Price};
} # end sub get_best_price 

sub get_best_price_object {
	my ( $cust_id, $prod_index, $list_id, $pricesetclass, $qty, $equipment, $period ) = @_;
	my $prices = get_best_prices( $cust_id, $prod_index, $list_id, $pricesetclass, $equipment, $qty, $period );
if ( DEBUG ) {
	$openprint::log->debug("Prices in get_best_price_obejct" . @$prices);
	foreach my $price ( @$prices ) {
		$openprint::log->debug("$$price{min} $$price{max} $$price{Price}");
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
		if ( $$Price{'Price'} ne '' ) {
			$$Price{'Price'} *= ( 1 + $pricingpercent );
		} # end if
	} # end if
	return openprint::Currency::convert( $Price );
} # end sub adjust_price

1;
__END__
