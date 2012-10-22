use strict;
package openprint::Expense_Tax;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );

require openprint::Expense;
require openprint::Tax;
require Math::Round;

$debug = 0;

$table = 'expense_taxes';
$serial = 'expense_taxes_id_seq';

%fields = (
	'id'			=>	'id',
	'expense_id'		=>	'expense_id',
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
		if ( $self->charge() ) {
			$$self{'amount'} = $self->Expense()->amount() * ($$self{'rate'}/100);
		} # end if
		$$self{'amount'} = Math::Round::nearest(0.01, $$self{amount} );
	} # end if
	return $$self{'amount'};
} # end sub amount

sub charge {
	my $self = $_[0];
	if ( @_ == 2 ) {
		$$self{'charge'} = $_[1];
	} # end if

	if ( $self->Expense()->owner_id() and ( ! defined $$self{'charge'} ) ) {
		if ( $self->Tax()->period_end() ) {
			# See if tax is applicabale
			my $period_end = Date::Parse::str2time( $self->Tax()->period_end() );
			my $invoiced_on = Date::Parse::str2time( $self->Expense()->invoiced_on() );
			if ( $period_end < $invoiced_on ) {
				$$self{'charge'} = 0;
				return $$self{'charge'};
			} # end if
		} # end if
		if ( $self->Tax()->period_start() ) {
			# See if tax is applicabale
			my $period_start = Date::Parse::str2time( $self->Tax()->period_start() );
			my $invoiced_on = Date::Parse::str2time( $self->Expense()->invoiced_on() );
			if ( $period_start < $invoiced_on ) {
				$$self{'charge'} = 0;
				return $$self{'charge'};
			} # end if
		} # end if
		if ( sets::isin( $self->name(), ['GST','HST'] ) ) {
			if ( $self->Expense()->Company()->taxexempt1() eq 'Y' ) {
				$$self{'charge'} = 0;
			} else {
				$$self{'charge'} = 1;
			} # end if
		} elsif ( sets::isin( $self->name(), ['PST'] ) ) {
			if ( $self->Expense()->Company()->taxexempt2() eq 'Y' ) {
				$$self{'charge'} = 0;
			} else {
				$$self{'charge'} = 1;
			} # end if
		} # end if 
	} # end if
	return $$self{'charge'};
} # end sub charge

sub rate {
	if ( @_ > 1 ) {
		$_[0]{'rate'} = $_[1];
	} # end if
	if ( ! defined $_[0]{'rate'} ) {
		$_[0]{'rate'} = $_[0]->Tax()->rate();
	} # end if
	return $_[0]{'rate'};
} # end sub rate

1;
__END__
