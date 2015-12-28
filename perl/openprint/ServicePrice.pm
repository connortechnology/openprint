use strict;
require sql;
require openprint::Object;
require Math::Round;
package openprint::ServicePrice;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );

$debug = 0;
$table = 'Service_Prices';
$serial = 'service_prices_id_seq';

%fields = (
	id				=>	'id',
	owner_id		=>	'owner_id',
	pricelist_id	=>	'pricelist_id',
	service_id		=>	'service_id',
	equipment_id	=>	'equipment_id',
	min				=>	'min',
	max				=>	'max',
	units			=>	'units',
	cost			=>	'cost',
	markup			=>	'markup',
	price			=>	'price',
	discountable	=>	'discountable',
	interpolate		=>	'interpolate',
	supplier_id		=>	'supplier_id',
	period_start	=>	'period_start',
	period_end		=>	'period_end',
);
%find_fields  = 	(
	service_name	=>	'(SELECT name from services WHERE services.id=service_id)',
);
%defaults = (
	min		=>	undef,
	max		=>	undef,
	cost	=>	undef,
	markup	=>	undef,
	price			=>	undef,
	discountable	=>	'Y',
	interpolate		=>	0,
	period_start    =>  undef,
	period_end      =>  undef,
	supplier_id		=>	undef,
	equipment_id	=>	undef,
);

%transforms = (
	min		=>	[ 's/[^\d\.\-]//g' ],
	max		=>	[ 's/[^\d\.\-]//g' ],
	cost	=>	[ 's/[^\d\.\-]//g' ],
	markup	=>	[ 's/[^\d\.\-]//g' ],
	price	=>	[ 's/[^\d\.\-]//g' ],
);

sub next {
	return new openprint::ServicePrice( sql::execute( undef,undef, q{SELECT MIN(id) WHERE id > ?}, $_[0]{id} ) );
} # end sub next

sub Pricelist {
	return new openprint::Pricelist( $_[0]{'pricelist_id'} );
}
sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
}
sub Service {
	return new openprint::Service( $_[0]{'service_id'} );
}

sub price {
    if ( @_ > 1 ) {
        $_[0]{'price'} = $_[1];
    } # end if
    if ( ! defined $_[0]{'price'} ) {
        $_[0]{'price'} = $_[0]{markup} ? Math::Round::nearest( 0.01, $_[0]{'cost'} * ( 1+($_[0]{'markup'}/100) ) ) : $_[0]{cost};
    } # end if
    return $_[0]{'price'};
} # end sub price

sub markup {
	if ( @_ > 1 ) {
		$_[0]{'markup'} = $_[1];
		$_[0]->price( undef );
	} # end if
	return $_[0]{'markup'};
} # end sub markup
sub cost {
	if ( @_ > 1 ) {
		$_[0]{'cost'} = $_[1];
		$_[0]->price( undef );
	} # end if
	return $_[0]{'cost'};
} # end sub cost

sub id_string {
	my $Price = $_[0];
	my $price_desc = '';
	if ( ! ( $Price->min() or $Price->max() ) ) {
		'all quantities';
	} else {
		if ( $Price->min() ) {
			$price_desc .= 1*$Price->min() . ' ';
		}
		$price_desc .= 'up';
		if ( $Price->max() ) {
			$price_desc .= ' to ' . 1*$Price->max();
		}
	} # end if
	return $Price->Pricelist()->name() . ' '. $price_desc . ' on ' . $Price->Equipment()->strid();
}

1;
__END__
