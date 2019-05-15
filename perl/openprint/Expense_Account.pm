package openprint::Expense_Account;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'expense_accounts';
$serial = 'expense_accounts_id_seq';
%fields = (
  id  =>  'id',
  name  =>  'name',
);
%transforms = (
  name => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
);

1;
__END__
