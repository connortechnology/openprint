require openprint::Object;
require sql;
require ssi;
require misc;
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
	'created_on'		=>	'created_on',
	'due_on'			=>	'due_on',
	'currency_id'		=>	'currency_id',
	'federaltax_rate'	=>	'federaltax_rate',
);

%transforms = (
	'id'				=>	[ 's/\D//g' ],
	'owner_id'			=>	[ 's/\D//g' ],
	'currency_id'		=>	[ 's/\D//g' ],
	'recipient_id'		=>	[ 's/\D//g' ],
	'amount'			=>	[ 's/[^\d\.\-]//g' ],
	'federaltax_rate'	=>	[ 's/[^\d\.]//g' ],
);

%defaults = (
	'due_on'		=>	'NOW()',
	'created_on'	=>	'NOW()',
	'recipient_id'	=>	undef,
);

sub Payor {
	return new openprint::Company( $_[0]{'payor_id'} );
} # end sub Payor

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
	return new openprint::Category( $_[0]{'category_id'} )->name();
} # end sub category

sub Category {
	return new openprint::Expense_Category( $_[0]{'category_id'} );
} # end sub Category

sub federaltax {
	my $self = shift;
	return sprintf('%.2f', $$self{'amount'} * $$self{'federaltax_rate'}/100 );
} # end sub federaltax
sub Recipient {
return new openprint::Company( $_[0]{'recipient_id'} );
}

1;
__END__
