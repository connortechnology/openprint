package openprint::Currency;
@ISA = qw(openprint::Object);

use strict;
use Number::Format;
use openprint ();
require openprint::Object;
require sql;

# This treats a Currency as an object.  The database is only accessed on method access.
my $debug = 0;

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

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM CUrrencies WHERE id=?', {}, $$self{'id'} );
	} # end if
	@$self{qw/name short symbol/} = @$data{qw/name short symbol/};
} # end sub load

sub values {
	my $self = shift;
	my @results;
	foreach ( @_ ) {
		push @results, $$self{lc $_};
	} # end foreach
	return @results;
} # end sub values

sub conversions {
	my ( $self, $to ) = @_;
	return 1 if $$self{id} == $to;
	if ( ! exists $$self{'Conversions'} ) {
		if ( $$self{'id'} ) {
			%{$$self{'Conversions'}} = sql::execute( undef, undef, q{SELECT to_id, rate FROM Currency_Conversions WHERE from_id=?}, $$self{'id'} );
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
					%{$$To{'Conversions'}} = sql::execute( undef, undef, q{SELECT to_id, rate FROM Currency_Conversions WHERE from_id=?}, $$To{'id'} );
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
	my ( $self, $to, $rate ) = @_;
	sql::execute( undef, undef, q{DELETE FROM Currency_Conversions WHERE from_id=? AND to_id=?}, $$self{'id'}, $to );
	sql::insert( undef, undef, 'Currency_Conversions', 'from_id', $$self{'id'}, 'to_id', $to, 'rate', $rate ) if $rate;
} # end sub add_conversion

sub convert_from {
} # end sub
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
		if ( $$DST_Currency{'id'} != $$Price{'currency_id'} ) {
			my $SRC_Currency = new openprint::Currency( $$Price{'currency_id'} );
			my $rate = $SRC_Currency->conversions( $DST_Currency->id() );
			$$Price{'Price'} *= $rate if $rate;
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
	return new openprint::Currency( $openprint::session{'Currency_id'} );
} # end sub get_currenct

sub format {
    my ( $price, $precision ) = @_;

    $precision = 2 if ! defined $precision;
    my $Currency = get_current();

    my $Formatter = new Number::Format(
            -decimal_digits     =>  $precision,
            -int_curr_symbol    =>  $Currency->symbol(),
            );
    return $Formatter->format_price( $price );
} # end sub format

1;

__END__

