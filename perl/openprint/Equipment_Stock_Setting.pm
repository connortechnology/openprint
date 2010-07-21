package openprint::Equipment_Stock_Setting;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $table $serial %fields %transforms %defaults );

$table = 'Equipment_Stock_Settings';
$serial= 'equipment_stock_settings_id_seq';
%fields = (
	'id'	=>	'id',
	'equipment_id'	=>	'equipment_id',
	'stock_id'		=>	'stock_id',
	'grain'			=>	'grain',
);
%transforms = (
	'grain' => [ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
);

require sql;
require openprint::Equipment;
require openprint::Paper;

sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment
sub Stock {
	return new openprint::Paper( $_[0]{'stock_id'} );
} # end sub Stock
	

1;

__END__
