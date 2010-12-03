require openprint::Object;
require openprint::Expense_Tax;
use strict;

package openprint::Expense_Category;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'expense_categories';
$serial = 'expense_categories_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);
%transforms = (
);
%defaults = (
);

package openprint::Expense;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'expenses';
$serial = 'expenses_id_seq';

%fields = (
	'id'				=>	'id',
	'owner_id'			=>	'owner_id',
	'recipient_id'		=>	'recipient_id',
	'category_id'		=>	'category_id',
	'category'			=>	undef,
	'description'		=>	'description',
	'amount'			=>	'amount',
	'total'				=>	'total',
	'created_on'		=>	'created_on',
	'due_on'			=>	'due_on',
	'invoiced_on'		=>	'invoiced_on',
	'currency_id'		=>	'currency_id',
	'business_use'		=>	'business_use',
);

%transforms = (
	'id'				=>	[ 's/\D//g' ],
	'owner_id'			=>	[ 's/\D//g' ],
	'currency_id'		=>	[ 's/\D//g' ],
	'recipient_id'		=>	[ 's/\D//g' ],
	'amount'			=>	[ 's/[^\d\.\-]//g' ],
	'total'				=>	[ 's/[^\d\.\-]//g' ],
	'business_use'		=>	[ 's/[^\d\.\-]//g' ],
);

%defaults = (
	'due_on'		=>	q`'NOW()'`,
	'invoiced_on'	=>	q`'NOW()'`,
	'created_on'	=>	q`'NOW()'`,
	'recipient_id'	=>	undef,
	'business_use'	=>	undef,
);


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
		my $Category = openprint::Expense_Category->find_one('name_lc'=>lc$_[1]);
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
                    'period_start_null_or_<='   =>  $$self{'invoiced_on'},
                    'period_end_null_or_>='     =>  $$self{'invoiced_on'},
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
					'period_start_null_or_<='   =>  $$self{'invoiced_on'},
					'period_end_null_or_>='     =>  $$self{'invoiced_on'},
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
	foreach my $Tax ( $self->Taxes() ) {
		$error .= $Tax->save({'expense_id'=>$self->id()});
	} # end foreach Tax
		
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
		$_[0]{'total'} = sprintf('%.2f', $_[0]{'total'} );
	} # end if
	return $_[0]{'total'};
} # end sub total
sub Tax {
    my $result = openprint::Expense_Tax->find_one('expense_id'=>$_[0]{'id'}, 'tax_id'=>$_[1]->id() ) if $_[0]{'id'};
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

1;
__END__
