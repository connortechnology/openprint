package openprint::Claim_Tax;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );

require sql;

$debug = 1;

$table = 'claim_taxes';
$serial = 'claim_taxes_id_seq';

%fields = (
	'id'			=>	'id',
	'claim_id'		=>	'claim_id',
	'tax_id'		=>	'tax_id',
	'rate'			=>	'rate',
	'amount'		=>	'amount',
	'charge'		=>	'charge',
);

%transforms = (
);
%defaults = (
	'rate'		=>	undef,
	'amount'	=>	undef,
);

sub name {
	return $_[0]->Tax()->name();
} # end sub name

sub amount {
	my $self = $_[0];
	if ( @_ == 2 ) {
		$$self{'amount'} = $_[1];
	} # end if

	if ( ! defined $$self{'amount'} ) {
		if ( $$self{'charge'} ) {
			$$self{'amount'} = ($$self{'rate'}/100) * $self->Claim()->subtotal();
		} # end if
	} # end if
	return $$self{'amount'};
} # end sub amount

sub charge {
	my $self = $_[0];
	if ( @_ == 2 ) {
		$$self{'charge'} = $_[1];
	} # end if

	if ( $self->Claim()->company_id() and ! defined $$self{'charge'} ) {
		if ( sets::isin( $self->name(), ['GST','HST'] ) ) {
			if ( $self->Claim()->Company()->taxexempt1() eq 'Y' ) {
				$$self{'charge'} = 0;
			} # end if
			$$self{'charge'} = 1;
		} elsif ( sets::isin( $self->name(), ['PST'] ) ) {
			if ( $self->Claim()->Company()->taxexempt2() eq 'Y' ) {
				$$self{'charge'} = 0;
			} # end if
			$$self{'charge'} = 1;
		} # end if 
	} # end if
	return $$self{'charge'};
} # end sub charge

1;
__END__
