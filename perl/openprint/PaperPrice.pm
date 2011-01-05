package openprint::PaperPrice;
@ISA = qw(openprint::Object);

use strict;

require sql;

use vars qw( $debug $table $serial %find_fields %fields %transforms %defaults );
$debug = 1;
$table = 'paper_prices';
$serial = 'paper_prices_id_seq';

%fields = (
	'id'			=>	'id',
	'pricelist_id'	=>	'lnglistindex',
	'paper_id'		=>	'lngpaperindex',	
	'min'			=>	'lngmin',
	'max'			=>	'lngmax',
	'units'			=>	'strunits',
	'cost'			=>	'dblcost',
	'markup'		=>	'dblmarkup',
	'price'			=>	'dblprice',
	'discountable'	=>	'ysndiscountable',
	'service'		=>	'service',
	'equipment_id'	=>	'equipment_id',
	'stock_id'		=>	undef,
);
%find_fields = (
	'stock_id'	=>	'paper_id',
);
%transforms = (
	'min' => [ 's/,//g', 's/(\d*)/$1/g' ],
	'max' => [ 's/,//g', 's/(\d*)/$1/g' ],
	'cost' => [ 's/[^\d\.]//g' ],
	'price' => [ 's/[^\d\.]//g' ],
	'markup' => [ 's/[^\d\.]//g' ],
);
%defaults = (
	'equipment_id'	=>	undef,
	'min' => undef,
	'max' => undef,
	'cost' => 0,
	'price' => 0,
	'markup' => 0,
);

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM Paper_Prices WHERE id=?}, $$self{'id'} );
	my $Paper = $self->Paper();
	delete $$Paper{'Prices'};
} # end sub delete

sub costperm {
	my $self = shift;
	my $Paper = $self->Paper();
	if ( $Paper->wpsi() ) {
		# ROll papers won't have an mweight
		return sprintf('%.2f', $$self{'cost'} * $Paper->wpsi() * $Paper->width() * $Paper->height() * 10 );
	} elsif ( $Paper->mweight() ) {
		return sprintf('%.2f', $$self{'cost'} * $Paper->mweight() / 100 );
	} # end if
} # end sub costperm

sub priceperm {
	my $self = shift;
	my $Paper = $self->Paper();
	if ( $Paper->wpsi() ) {
		# ROll papers won't have an mweight
		return sprintf('%.2f', $$self{'price'} * $Paper->wpsi() * $Paper->width() * $Paper->height() * 10 );
	} elsif ( $Paper->mweight() ) {
		return sprintf('%.2f', $$self{'price'} * $Paper->mweight() / 100 );
	} # end if
} # end sub priceperm
sub costperfoot {
	my $self = $_[0];
	my $Paper = $self->Paper();
	return sprintf('%.2f', ($$self{'cost'}/100 ) * ( $Paper->wpsi() * 144 ) );
}
sub priceperfoot {
	my $self = $_[0];
	my $Paper = $self->Paper();
	return sprintf('%.2f', $$self{'price'} * ( $Paper->wpsi() * 144 ) /100 );
}

sub markup {
	if ( @_ > 1 ) {
		$_[0]{'markup'} = $_[1];
	} # end if
	return $_[0]{'markup'};
} # end sub markup

sub price {
	if ( @_ > 1 ) {
		$_[0]{'price'} = $_[1];
	} # end if
	if ( ! defined $_[0]{'price'} ) {
		$_[0]{'price'} = sprintf( '%.2f', $_[0]{'cost'} * ( 1+($_[0]{'markup'}/100) ) );
	} # end if
	return $_[0]{'price'};
}

sub stock_id {
	if ( @_ > 1 ) {
		$_[0]{'paper_id'} = $_[1];
	} # end if
	return $_[0]{'paper_id'};
} # end sub stock_id

1;
__END__
