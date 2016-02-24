use strict;
package openprint::Currency;
our @ISA = qw(openprint::Object);

require openprint;
require openprint::Currency_Conversion;
require openprint::Pricelist;
require openprint::Company;
require sql;

use vars qw( $log $dbh $debug $table $serial %fields %transforms %defaults $cache_field );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$debug = 0;
$table = 'Currencies';
$serial = 'currencies_id_seq';
%fields = (
	id		=>	'id',
	short	=>	'short',
	name	=>	'name',
	symbol	=>	'symbol',
);
%transforms = (
	id			=>	[ 's/\D//g', '<2147483647' ],
    name => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
    short => [ 's/\s+//' ],
);
%defaults = (
);

$cache_field = 'short';
sub cache_field {
	return $cache_field;
}
sub conversions {
	my ( $self, $to ) = @_;
	return 1 if $$self{id} == $to;
	if ( ! exists $$self{'Conversions'} ) {
		if ( $$self{'id'} ) {
			%{$$self{'Conversions'}} = sql::execute( undef, undef, q{SELECT to_id, rate FROM Currency_Conversions WHERE from_id=? AND period_end IS NULL}, $$self{'id'} );
		} else {
			%{$$self{'Conversions'}} = ();
		} # end if
	} # end if
	if ( $to ) {
		if ( $$self{'Conversions'}{$to} ) {
			return $$self{'Conversions'}{$to};
		} else {
			my $To = new openprint::Currency( $to );
			if ( $To->id() ) {
				if ( ! exists $$To{'Conversions'} ) {
					%{$$To{'Conversions'}} = sql::execute( undef, undef, q{SELECT to_id, rate FROM Currency_Conversions WHERE from_id=? AND period_end IS NULL}, $$To{'id'} );
				} # end if
				if ( my $rate = $$To{'Conversions'}{$$self{'id'}} ) {
					return 1/$rate if $rate;
				} # end if
				return;
			} # end if
		} # end if
	} # end if
	return %{$$self{'Conversions'}};
} # end sub conversions

sub set_conversion {
	my ( $self, $to_id, $rate ) = @_;
	my $Conversion = openprint::Currency_Conversion->find_one({to_id=>$to_id, from_id=>$$self{id},period_end=>undef});
	if ( ! $Conversion ) {
		$Conversion = new openprint::Currency_Conversion();
		$Conversion->set({to_id=>$to_id, from_id=>$$self{id}});
	} else {
		$Conversion->save({period_end=>'NOW()'});
		$Conversion->set({period_start=>'NOW()',period_end=>undef});
	} # end if
	$Conversion->save({rate=>$rate});
} # end sub add_conversion

sub convert_from {
	my ( $self, $value ) = @_;
	my $DST_Currency = get_current();
	if ( ! ( $DST_Currency and $$DST_Currency{id} ) ) {
		$log->error("Invalid destiation currency in convert_from");
		return $value;
	} elsif ( ! $$self{id} ) {
		$log->error("Invalid src currency in convert_from");
		return $value;
	}

	if ( $DST_Currency->id() != $$self{id} ) {
		my $rate = $self->conversions( $DST_Currency->id() );
		my $new = $value * $rate;
		$log->debug("Converting $value in $$self{'name'} to $$DST_Currency{'name'} using rate $rate $new") if $debug;
		return $new;
	} # end if
	return $value;
} # end sub convert_from
sub convert_to {
	my ( $From, $To, $value ) = @_;
	if ( ! ref $To ) {
		$To = openprint::Currency->find_one('short'=>$To);
	} 
	if ( $From eq 'openprint::Currency' ) {
		$From = get_current();
	} # end if
	if ( ! $To ) {
		$log->error('No Currency for ' . $_[1] );
		return;
	} # end if
	if ( $To and ( $$To{id} != $$From{id} ) ) {
		my $rate = $From->conversions( $To->id() );
		$log->debug("Converting $value in $$From{name} to $$To{name}") if $debug;
		$value *= $rate;
	} # end if
	return $value;
} # end sub

# Takes a ref to a price
# The price has a currency_id
# if $$price{'currency_id'} is not the Session's Currency, then convert it , and return
sub convert {
	my $Price = $_[0];

	# Get display_currency
	my $DST_Currency = get_current();
	if ( $DST_Currency ) {
		if ( $$DST_Currency{'id'} != $$Price{'currency_id'} ) {
			my $SRC_Currency = new openprint::Currency( $$Price{'currency_id'} );
			my $rate = $SRC_Currency->conversions( $DST_Currency->id() );
			$$Price{'Price'} *= $rate if $rate;
			$$Price{'price'} *= $rate if $rate;
#$log->debug("Converting $$Price{'Price'} in $$SRC_Currency{'name'} to $$DST_Currency{'name'}") if $debug;
			$$Price{'currency_id'} = $DST_Currency->id();
		} # end if
	} # end if
	return $Price;
} # end sub convert

sub get_current {

	if ( $openprint::session{'Currency_id'} ) {
		return new openprint::Currency( $openprint::session{'Currency_id'} );
	} # end if

	if ( ( ! $openprint::session{'Currency_id'} ) and $openprint::session{'company_id'} ) {
		my $Company = new openprint::Company( $openprint::session{'company_id'} );
		$openprint::session{'Currency_id'} = $Company->currency_id();
	} # end if

	if ( ! $openprint::session{'Currency_id'} ) {
		my $list_id = openprint::pricing::get_pricelist_id( );
		my $Pricelist = new openprint::Pricelist( $list_id );
		$openprint::session{'Currency_id'} = $Pricelist->currency_id();
	} # end if
	if ( ! $openprint::session{'Currency_id'} ) {
		if ( $openprint::config{'Currency'} ) {
			my @Currencies = openprint::Currency->find('short'=>$openprint::config{'Currency'});
			if ( @Currencies ) {
				$openprint::session{'Currency_id'} = $Currencies[0]->id();
			} # end if
		} # end if
	} # end if
	if ( $openprint::session{'Currency_id'} ) {
		return new openprint::Currency( $openprint::session{'Currency_id'} );
	} # end if
	return new openprint::Currency();

} # end sub get_currency

sub format {
	my ( $Currency, $price, $precision );
	if ( ref $_[0] eq 'openprint::Currency' ) {
		( $Currency, $price, $precision ) = @_;
	} else {
		( $price, $precision ) = @_;
		$Currency = get_current();
	} # end if
	

	$price = 0 if ! $price;
	$precision = 2 if ! defined $precision;
	my $symbol = $Currency->symbol();

	if ( ! $symbol ) {
		$openprint::log->error( "Currecy does not have symbol: " . $Currency->to_string() );
		$symbol = '$';
	}

	require Number::Format;
    my $Formatter = new Number::Format(
            -decimal_digits     =>  $precision,
            -int_curr_symbol    =>  $symbol,
            );
	return $Formatter->format_price( $price, $precision );
} # end sub format

1;
__END__
