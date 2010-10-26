package sets;

use strict;

sub isin {

    # Takes in a variable, and an array, and checks the array element by
    # element to see if the variable exists inside the array.
    my $var = shift;
	if ( @_ == 1 ) {
		my $thing = shift;
#$openprint::log->debug( 'REF' . ref $thing );
		if ( ref $thing eq 'ARRAY' ) {
			foreach (@{$thing}) {
#$openprint::log->debug( 'thing' . $value );
				return 1 if $_ eq $var;
			} # end foeach
		} else {
			return 1 if $thing eq $var;
		} # end if
	} elsif ( @_ > 1 ) {
		foreach $_ (@_) {
			return 1 if $_ eq $var;
		} # end foreach
	} # end if
    return 0;

} # end sub isin

sub isin_regx {
# Takes in a variable, and an array, and checks the array element by
# element to see if the variable exists inside the array.

	my $var = shift;
	foreach my $value (@_) {
		$value =~ s/\\\\/\\/g;
		if ( $var =~ /^($value)$/ ) {
#$openprint::log->debug("isin_regx: matched $value");
			return 1;
		#} else {
#$openprint::log->debug("isin_regx: not matched ($var) ($value)");

		} # end if
	} # end foeach
	return 0;

} # end sub inin_regx

sub union {
	my %hash;
	foreach ( @_ ) {
		$hash{$_} = 1;
	} # end foreach
	return keys %hash;
} # end sub union

sub contains {
	my ( $setA, $setB ) = @_;

	foreach ( @{$setB} ) {
		if ( ! isin( $_, @{$setA} ) ) {
			return 0;
		} # end if
	} # end foreach
	return 1;
} # end sub contains

sub intersection {
	my %elements;
	my $count = 2;
	my @result = ();

	foreach ( @_ ) {
		$elements{$_} += 1;
		if ( $elements{$_} > $count ) {
			$count = $elements{$_};
		} # end if
	} # end foreach

	foreach ( keys %elements ) {
		if ( $elements{$_} == $count ) {
			push @result, $_;
		} # end if
	} # end foreach
	return @result;
};

sub xor {
	my %elements;
	my @result = ();
	foreach ( @_ ) {
		$elements{$_} += 1;
	} # end foreach
	foreach ( keys %elements ) {
		if ( $elements{$_} == 1 ) {
			push @result, $_;
		} # end if
	} # end foreach
	return @result;
}

# We do it this way to maintain ordering of the input array
sub exclude {
	my ( $exclude, $array ) = @_;
	return if (! $exclude) or (! $array);
	my @results;
	foreach my $element ( @{$array} ) {
		push @results, $element if ( ! sets::isin( $element, $exclude ) );
	} # end foreach
	return @results;
} # end sub exclude

sub max {
	my $max;

	foreach ( ( ( @_ == 1 ) and ( ref $_[0] eq 'ARRAY' ) ) ? @{$_[0]} : @_ ) {
		$max = $_ if ( ! defined $max ) or  ($max < $_ );
	} # end foreach
	return $max;
} # end sub max

sub max_index {
	my $array = ( ( @_ == 1 ) and ( ref $_[0] eq 'ARRAY' ) ) ? $_[0] : \@_;
	my $max;
	my $max_index;

	for ( my $index = 0; $index < @$array; $index += 1 ) {
		if ( ( ! defined $max ) or ($max < $$array[$index] ) ) {
			$max = $$array[$index];
			$max_index = $index;
		} # endif
	} # end foreach
	return $max_index;
} # end sub max_index

1;

__END__
~       
