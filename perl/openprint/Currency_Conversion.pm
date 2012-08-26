use strict;
package openprint::Currency_Conversion;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'currency_conversions';
$serial	= 'currency_conversions_id_seq';
%fields = (
	id				=>	'id',
	to_id			=>	'to_id',
	from_id			=>	'from_id',
	period_start	=>	'period_start',
	period_end		=>	'period_end',
	rate			=>	'rate',
);
%transforms = (
);
%defaults = (
	period_start	=>	undef,
	period_end		=>	undef,
	rate			=>	undef,
);

1;
__END__
