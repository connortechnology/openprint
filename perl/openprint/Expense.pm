require openprint::Object;
require openprint::Expense_Tax;
require Math::Round;
use strict;

package openprint::Expense_Category;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'expense_categories';
$serial = 'expense_categories_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);
%transforms = (
    'name' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
);
package openprint::Expense_Account;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'expense_accounts';
$serial = 'expense_accounts_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);
%transforms = (
    'name' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
);

package openprint::Expense;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'expenses';
$serial = 'expenses_id_seq';

%fields = (
	'id'				=>	'id',
	'owner_id'			=>	'owner_id',
	'recipient_id'		=>	'recipient_id',
	'category_id'		=>	'category_id',
	'category'			=>	undef,
	'account_id'		=>	'account_id',
	'account'			=>	undef,
	'description'		=>	'description',
	'amount'			=>	'amount',
	'amount_locked'		=>	'amount_locked',
	'total'				=>	'total',
	'total_locked'		=>	'total_locked',
	'created_on'		=>	'created_on',
	'due_on'			=>	'due_on',
	'paid_on'			=>	'paid_on',
	'invoiced_on'		=>	'invoiced_on',
	'currency_id'		=>	'currency_id',
	'business_use'		=>	'business_use',
	'business_use_amount'		=>	'business_use_amount',
	'attention'			=>	'attention',
	deleted				=>	'deleted',
	transaction_id		=>	'transaction_id',
);

%transforms = (
	'id'				=>	[ 's/\D//g' ],
	'owner_id'			=>	[ 's/\D//g' ],
	'currency_id'		=>	[ 's/\D//g' ],
	'recipient_id'		=>	[ 's/\D//g' ],
	'amount'			=>	[ 's/[^\d\.\-]//g' ],
	'total'				=>	[ 's/[^\d\.\-]//g' ],
	'business_use'		=>	[ 's/[^\d\.\-]//g' ],
    'description'		=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);

%defaults = (
	'due_on'		=>	q`'NOW()'`,
	'invoiced_on'	=>	q`'NOW()'`,
	'created_on'	=>	q`'NOW()'`,
	'recipient_id'	=>	undef,
	'business_use'	=>	undef,
	'paid_on'		=>	undef,
	'amount_locked'	=>	0,
	'total_locked'	=>	0,
	'account_id'	=>	undef,
	'category_id'	=>	undef,
	'attention'		=>	0,
	deleted			=>	0,
	amount			=>	undef,
	total			=>	undef,
);


sub link_to {
	return sprintf('<a href="/employee/accounting/expense.html?expense_id=%d">%s</a>', $_[0]{id}, 'Expense ' . $_[0]{id} );
}
sub Company {
	return new openprint::Company( $_[0]{'owner_id'} );
} # end sub Company

sub Currency {
	return new openprint::Currency( $_[0]{'currency_id'} );
} # end sub Currency

sub category_id {
	if ( @_ > 1 and defined $_[1] ) {
		$_[0]{'category_id'} = $_[1];
	} # end if
	return $_[0]{'category_id'};
} # end sub category_id

sub category {
	if ( @_ > 1 ) {
		my $Category = openprint::Expense_Category->find_one('name lc'=>lc $_[1]);
		if ( ! $Category ) {
			$Category = new openprint::Expense_Category();
			$Category->save({'name'=>$_[1]})
		} # end if	
		$_[0]{'category_id'} = $Category->id();
		return $Category->name();
	} # end if
	return new openprint::Expense_Category( $_[0]{'category_id'} )->name();
} # end sub category

sub Category {
	return new openprint::Expense_Category( $_[0]{'category_id'} );
} # end sub Category

sub account {
	if ( @_ > 1 ) {
		my $Account = openprint::Expense_Account->find_one('name lc'=>lc $_[1]);
		if ( ! $Account ) {
			$Account = new openprint::Expense_Account();
			$Account->save({'name'=>$_[1]})
		} # end if	
		$_[0]{'account_id'} = $Account->id();
		return $Account->name();
	} # end if
	return new openprint::Expense_Account( $_[0]{'account_id'} )->name();
} # end sub account

sub Account {
	return new openprint::Expense_Account( $_[0]{'account_id'} );
} # end sub Account

sub Recipient {
	return new openprint::Company( $_[0]{'recipient_id'} );
}

sub delete {
	foreach my $T ( $_[0]->Taxes() ) {
		$T->delete();
	} # end foreach
	$_[0]->SUPER::delete();
} # end sub delete

sub Taxes {
    my ( $self ) = @_;

    if ( $$self{'id'} ) {
		if ( ! $$self{'Taxes'} ) {
			@{$$self{'Taxes'}} = openprint::Expense_Tax->find('expense_id'=>$$self{'id'});
		} # end if
	} else { 
		@{$$self{'Taxes'}} = ();
    } # end if
    if ( $self->Company()->country() and $self->Company()->state() and $$self{'invoiced_on'} and ! @{$$self{'Taxes'}} ) {
        foreach my $Tax ( openprint::Tax->find(
                    'period_start null_or_<='   =>  $$self{'invoiced_on'},
                    'period_end null_or_>='     =>  $$self{'invoiced_on'},
                    'country'   =>  $self->Company()->country(),
                    'state'     =>  $self->Company()->state()),
                ) {
            my $T = new openprint::Expense_Tax();
            $T->set({
				'expense_id'	=>	$$self{'id'},
                'tax_id'    =>  $$Tax{'id'},
                'rate'      =>  $$Tax{'rate'},
            });
			# SHould not save.  Saving will be done in the save function This is okay, because in the html, we id our field by the tax_id
			#$T->save({ 'expense_id'=>  $$self{'id'}}) if $$self{'id'};
            push @{$$self{'Taxes'}}, $T;
        } # end foreach Tax
    } # end if
    return @{$$self{'Taxes'}};
} # end sub Taxes

sub save {
	my $self = shift;

	$self->set( @_ );

	if ( $self->id() ) {
		# Taxes, get current, get relevant, save, delete as appropriate
		my @Old_Taxes = $self->Taxes();
		my @New_Taxes;

		foreach my $Tax ( openprint::Tax->find(
					'period_start null_or_<='   =>  $$self{'invoiced_on'},
					'period_end null_or_>='     =>  $$self{'invoiced_on'},
					'country'   =>  $self->Company()->country(),
					'state'     =>  $self->Company()->state()),
				) {
			my $T = $self->Tax( $Tax );
			push @New_Taxes, $T;
			if ( $T->id() ) {
				for ( my $i = 0; $i < @Old_Taxes; $i += 1 ) {
					if ( $Old_Taxes[$i]->id() == $T->id() ) {
						splice @Old_Taxes, $i, 1;
						last;
					} # end if
				} # end for
			} # end if
		} # end foreach Tax
		foreach my $Tax ( @Old_Taxes ) {
			$Tax->delete() if $Tax->id();
		} # end foreach Tax
		@{$$self{'Taxes'}} = @New_Taxes;
	} # end if
	foreach my $Tax ( $self->Taxes() ) {
		$Tax->amount(undef);
	} # end foreach Tax
	$self->total(undef);
	my $error = $self->SUPER::save( @_ );
	if ( ! $error ) {
		foreach my $Tax ( $self->Taxes() ) {
			$error .= $Tax->save({'expense_id'=>$self->id()});
		} # end foreach Tax
	} # end if
	return $error;
} # end sub save
sub total {
	if ( @_ == 2 ) {
		$_[0]{'total'} = $_[1];
	} # end if
	if ( ! $_[0]{'total'} ) {
		$_[0]{'total'} = $_[0]->amount();
        foreach my $Tax ( $_[0]->Taxes() ) {
            $_[0]{'total'} += $Tax->amount();
        } # end foreach Tax
		$_[0]{'total'} = Math::Round::nearest( 0.01, $_[0]{'total'} );
	} # end if
	return $_[0]{'total'};
} # end sub total
sub Tax {
	foreach my $T ( $_[0]->Taxes() ) {
		return $T if $$T{tax_id} == $_[1]->id();
	} # end foreach
    my $result = openprint::Expense_Tax->find_one(expense_id=>$_[0]{id}, tax_id=>$_[1]->id() ) if $_[0]{id};
    if ( ! $result ) {
        $result = new openprint::Expense_Tax();
		$result->set({
			'expense_id'=>$_[0]{'id'},
			'tax_id'=>$_[1]->id(),
			'rate'=>$_[1]->rate(),
			});
    } # end if
    return $result;
} # end sub Tax
sub business_use_amount {
	if ( @_ > 1 ) {
		$_[0]{'business_use_amount'} = $_[1];
	} # end if
	if ( ! defined $_[0]{'business_use_amount'} ) {
		$_[0]{'business_use_amount'} = Math::Round::nearest( 0.01, $_[0]{'amount'} * ( $_[0]{'business_use'} / 100 ) );
	} # end if
	return $_[0]{'business_use_amount'};
} # end sub business_use_amount
1;
__END__
