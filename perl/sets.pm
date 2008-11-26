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
			foreach my $value (@{$thing}) {
#$openprint::log->debug( 'thing' . $value );
				return 1 if $value eq $var;
			} # end foeach
		} else {
			return 1 if $thing eq $var;
		} # end if
	} elsif ( @_ > 1 ) {
		foreach my $value (@_) {
			return 1 if $value eq $var;
		} # end foeach
	} # end if
    return 0;

} # end sub isin

sub isin_regx {
# Takes in a variable, and an array, and checks the array element by
# element to see if the variable exists inside the array.

	my ($var, @array) = @_;
	foreach my $value (@array) {
		$value =~ s/\\\\/\\/g;
		if ( $var =~ /^($value)$/ ) {
$openprint::log->debug("isin_regx: matched $value");
			return 1;
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
	my $max = undef;
	if ( @_ == 1 and ref $_[0] eq 'ARRAY' ) {
		foreach ( @{$_[0]} ) {
			if ( $_ > $max or ! defined $max ) {
				$max = $_;
			} # end if
		} # end foreach
	} else {
		foreach ( @_ ) {
			if ( $_ > $max or ! defined $max ) {
				$max = $_;
			} # end if
		} # end foreach
	} # end if
	return $max;
} # end sub max

1;

__END__
~       
