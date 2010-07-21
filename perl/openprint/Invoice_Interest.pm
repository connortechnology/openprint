package openprint::Invoice_Interest;
@ISA = qw(openprint::Object);

require sql;

use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );

$table = 'invoice_interests';
$serial = 'invoice_interests_id_seq';

$debug = 0;

%fields = (
	'id'				=>	'id',
	'amount'			=>	'amount',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'description'		=>	'description',
	'compounded_on'		=>	'compounded_on',
	'invoice_id'		=>	'invoice_id',
);

%transforms = (
);
%defaults = (
	'invoice_id'	=>	undef,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'amount'		=>	0,
);

sub save {
	my ( $self, $data ) = @_;
	my $ac = sql::start_transaction( $dbh );
	my $error = $self->SUPER::save( $data );
	$error .= $self->Invoice()->save({'interest'=>undef});
	sql::end_transaction( $dbh, $ac );
	return $error;
} # end sub save

1;
__END__
