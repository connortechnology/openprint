package openprint::pricing;

use strict;

require openprint::pricelist;
require openprint::priceset;
require openprint::price;

my $debug = 0;

my %price_cache;

sub clear_cache {
	%price_cache = ();
} # end sub clear_cache

sub get_pricelist_id {

	if ( $openprint::session{'Pricelist_id'} ) {
		my $Pricelist = new openprint::Pricelist( $openprint::session{'Pricelist_id'} );
		if ( $Pricelist->id() ) {
$openprint::log->debug("openprint::pricing::get_pricelist_id returning cached Pricelist " . $Pricelist->id() . ' ' . $Pricelist->name() ) if $debug;
			return $Pricelist->id();
		} # end if
	} # end if

	my $list_id;

	if ( $openprint::session{'company_id'} > 0 ) {
		my $Company = new openprint::Company( $openprint::session{'company_id'} );
		$list_id = $Company->pricelist_id();
		if ( (! $list_id ) and $Company->country() ) {
			$list_id = $openprint::config{'Default'.$Company->country().'Pricelist'};
		} # end if
	} elsif ( $openprint::session{'Country'} ) {
		$list_id = $openprint::config{'Default'.$openprint::session{'Country'}.'Pricelist'};
	} elsif ( $openprint::session{'Country'} ) {
		$list_id = $openprint::config{'Default'.$openprint::session{'Country'}.'Pricelist'};
	} else {
		$openprint::log->debug("No pricelist to be had! Country: $openprint::session{'Country'}" );
	} # end if
	$openprint::session{'Pricelist_id'} = $list_id;
	return $list_id;
} # end sub get_pricelist_id

# returns an index into the passed array of the price entry that fits the specified quantity.
# if $qty = '' then it will return the last entry
# if the price array is empty, it will return -4, which isn't good.
sub find_price {
	my $qty = shift;
	for ( my $index = 0; $index < @_; $index += 1 ) {
 		if ( $qty ne '' and ( $qty <= $_[$index]->{max} or $_[$index]->{max} eq '' ) ) {
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
	my ( $price1, $price2 ) = @_;

	if ( $price1->{Price} > $price2->{Price} ) {
		my $temp_price = $price1;
		$price1 = $price2;
		$price2 = $temp_price;	
	} elsif ( $price1->{equipment_index} != $price2->{equipment_index} ) {
		return ( $price1, $price2 );
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
	my @prices = @_;
	my @returned = shift @prices;

	# basically, we process each entry in the huge list of prices, and fit them into a returned list
	while ( @prices ) {
		# pull and entry off
		my $price = shift @prices;
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

sub get_best_prices {
	my ( $log, $dbh, $cust_id, $prod_index, $list_id, $pricesetclass, $equipment, $qty ) = @_;

	my $hash_index = "$pricesetclass-$cust_id-$prod_index-$equipment-$qty";

	if ( ! defined $price_cache{$hash_index} ) {

		if ( ! $list_id ) {
# figure out which price list we select from, because the caller didn't specify.
			$list_id = get_pricelist_id( $log, $dbh );
		} # end if

		my @pricing = ();
		my $priceGroup = $pricesetclass->new( $log, $dbh, $list_id, $prod_index, $equipment, $qty );
		$priceGroup->load();	
		push @pricing, @{$priceGroup->{prices}};

# Now if we are a customer, then we have more to do, including special pricing, adding discounts, etc. 
		if ( $cust_id != 0 ) {
			my $Company = new openprint::Company( $cust_id );

			my $pricingpercent = $Company->discount();
			if ( 1*$pricingpercent ) {
				$pricingpercent = $pricingpercent/100;
				for ( my $index = 0; $index < @pricing; $index += 1 ) {
					if ( $pricing[$index]->{Discountable} ne 'N' ) {

# the if here is to preserve empty pricing.	if pricei s empty, we display call, instead of 0.00.
						if ( $pricing[$index]->{Price} ne '' ) {
							$pricing[$index]->{Price} *= ( 1 - $pricingpercent );
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
			for ( my $index = 0; $index < @pricing; $index += 1 ) {
# the if here is to preserve empty pricing.	if pricei s empty, we display call, instead of 0.00.
				if ( $pricing[$index]->{Price} ne '' ) {
					$pricing[$index]->{Price} *= ( 1 + $pricingpercent );
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
		$price_cache{$hash_index} = [ @prices ];
	} # end if

	return $price_cache{$hash_index};
} # end sub get_best_prices

sub get_best_price {
	my ( $log, $dbh, $cust_id, $prod_index, $list_id, $pricesetclass, $qty, $equipment ) = @_;

	my %price = get_best_price_object( $log, $dbh, $cust_id, $prod_index, $list_id, $pricesetclass, $qty, $equipment );
	return $price{Price};
} # end sub get_best_price 

sub get_best_price_object {
	my ( $log, $dbh, $cust_id, $prod_index, $list_id, $pricesetclass, $qty, $equipment ) = @_;
	my $prices = get_best_prices( $log, $dbh, $cust_id, $prod_index, $list_id, $pricesetclass, $equipment, $qty );
	foreach my $price ( @$prices ) {
		#if ( $price and ( (!defined $price->{min} or $price->{min} eq '' ) or 1*$price->{min} <= $qty ) and ( $price->{max} >= $qty or $price->{max} eq '' ) ) {
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
~		
