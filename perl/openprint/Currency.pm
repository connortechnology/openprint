package openprint::Currency;
@ISA = qw(openprint::Object);

use strict;
use Number::Format;
use openprint ();
use vars qw( $log $dbh $table $serial %fields );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
require openprint::Object;
require sql;

my $debug = 1;
$table = 'Currencies';
$serial = 'currencyindex_seq';
%fields = (
'id'	=>	'id',
'name'	=>	'name',
'symbol'	=>	'symbol',
'short'		=>	'short',
);

sub get {
	my ( $params ) = @_;
	my @Currencies = find(@_);
	if ( @Currencies == 1 ) {
		return $Currencies[0] 
	} elsif ( @Currencies > 1 ) {
		$log->error('More than 1 currency found in openprint::Currency::get');
	} else {
		$log->error('No Currency found in openprint::Currency::get');
	} # end if
	return;
} # end sub get

sub find {
	my %params = @_;
	my $sql = 'SELECT * FROM Currencies WHERE 1>0';
	my @values;
	if ( $params{'id'} ) {
		$sql .= ' AND id=?';
		push @values, $params{'id'};
	} # end if
	if ( $params{'short'} ) {
		$sql .= ' AND short=?';
		push @values, $params{'short'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading Currencies: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Currencies: ($sql) (@values) " . @$data );
	} # end if
	return map { new openprint::Currency( $_->{id}, $_ ) } @$data;
} # end sub find

sub values {
	my $self = shift;
	my @results;
	foreach ( @_ ) {
		push @results, $$self{lc $_};
	} # end foreach
	return @results;
} # end sub values

sub conversions {
	my $self = shift;
	if ( ! exists $$self{'Conversions'} ) {
		%{$$self{'Conversions'}} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT to_id, rate FROM Currency_Conversions WHERE from_id=?}, $$self{'id'} );
	} # end if
	if ( my $to = shift ) {
		return $$self{'Conversions'}{$to};
	} # end if
	return %{$$self{'Conversions'}};
} # end sub conversions

sub set_conversion {
	my ( $self, $to, $rate ) = @_;
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Currency_Conversions WHERE from_id=? and to_id=?}, $$self{'id'}, $to );
	sql::insert( $openprint::log, $openprint::dbh, 'Currency_Conversions', 'from_id', $$self{'id'}, 'to_id', $to, 'rate', $rate );
} # end sub add_conversion

sub convert_from {
	my ( $self, $value ) = @_;
	my $DST_Currency = get_current();
	if ( $DST_Currency and ( $DST_Currency->id() != $$self{'id'} ) ) {
		my $rate = $self->conversions( $DST_Currency->id() );
		$log->debug("Converting $value in $$self{'name'} to $$DST_Currency{'name'}") if $debug;
		$value *= $rate;
	} # end if
	return $value;
} # end sub convert_from
sub convert_to {
} # end sub

# Takes a ref to a price
# The price has a currency_id
# if $$price{'currency_id'} is not the Session's Currency, then convert it , and return
sub convert {
	my $Price = shift;

	# Get display_currency
	my $DST_Currency = get_current();
	if ( $DST_Currency ) {
		my $SRC_Currency = new openprint::Currency( $$Price{'currency_id'} );
		if ( $DST_Currency->id() != $$Price{'currency_id'} ) {
			my $rate = $SRC_Currency->conversions( $DST_Currency->id() );
$log->debug("Converting $$Price{'Price'} in $$SRC_Currency{'name'} to $$DST_Currency{'name'}") if $debug;
			$$Price{'Price'} *= $rate;
			$$Price{'currency_id'} = $DST_Currency->id();
		} # end if
	} # end if
	return $Price;
} # end sub convert

sub get_current {

	if ( ( ! $openprint::session{'Currency_id'} ) and $openprint::session{'company_id'} ) {
		my $Company = new openprint::Company( $openprint::session{'company_id'} );
		$openprint::session{'Currency_id'} = $Company->currency_id();
	} # end if

	if ( ! $openprint::session{'Currency_id'} ) {
		my $list_id = openprint::pricing::get_pricelist_id( $openprint::log, $openprint::dbh, $openprint::variable );
		my $Pricelist = new openprint::Pricelist( $list_id );
		$openprint::session{'Currency_id'} = $Pricelist->currency_id();
	} # end if
	if ( ! $openprint::session{'Currency_id'} ) {
		if ( $openprint::config{'Currency'} ) {
			my @Currencies = openprint::Currency::find('short'=>$openprint::config{'Currency'});
			if ( @Currencies ) {
				$openprint::session{'Currency_id'} = $Currencies[0]->id();
			} # end if
		} # end if
	} # end if

	if ( $openprint::session{'Currency_id'} ) {
		return new openprint::Currency( $openprint::session{'Currency_id'} );
	} # end if
} # end sub get_currenct

sub format {
	my ( $price, $precision ) = @_;

	$precision = 2 if ! defined $precision;
	my $Currency = get_current();

	my $Formatter = new Number::Format(
			-decimal_digits		=>  $precision,
			-int_curr_symbol    =>  $Currency->symbol(),
			);
	return $Formatter->format_price( $price );
} # end sub format
1;

__END__

