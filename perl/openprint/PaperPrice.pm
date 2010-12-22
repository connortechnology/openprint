package openprint::PaperPrice;
@ISA = qw(openprint::Object);

use strict;

require sql;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'paper_prices';
$serial = 'paper_prices_id_seq';

%fields = (
	'id'			=>	'id',
	'pricelist_id'	=>	'lnglistindex',
	'paper_id'		=>	'lngpaperindex',	
	'Min'			=>	'lngmin',
	'Max'			=>	'lngmax',
	'Units'			=>	'strunits',
	'Cost'			=>	'dblcost',
	'Markup'		=>	'dblmarkup',
	'Price'			=>	'dblprice',
	'Discountable'	=>	'ysndiscountable',
);
%transforms = (
	'Min' => [ 's/,//g', 's/(\d*)/$1/g' ],
	'Max' => [ 's/,//g', 's/(\d*)/$1/g' ],
	'Cost' => [ 's/[^\d\.]//g' ],
	'Price' => [ 's/[^\d\.]//g' ],
	'Markup' => [ 's/[^\d\.]//g' ],
);
%defaults = (
	'Min' => undef,
	'Max' => undef,
	'Cost' => 0,
	'Price' => 0,
	'Markup' => 0,
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
		return sprintf('%.2f', $$self{'Cost'} * $Paper->wpsi() * $Paper->width() * $Paper->height() * 10 );
	} elsif ( $Paper->mweight() ) {
		return sprintf('%.2f', $$self{'Cost'} * $Paper->mweight() / 100 );
	} # end if
} # end sub costperm

sub priceperm {
	my $self = shift;
	my $Paper = $self->Paper();
	if ( $Paper->wpsi() ) {
		# ROll papers won't have an mweight
		return sprintf('%.2f', $$self{'Price'} * $Paper->wpsi() * $Paper->width() * $Paper->height() * 10 );
	} elsif ( $Paper->mweight() ) {
		return sprintf('%.2f', $$self{'Price'} * $Paper->mweight() / 100 );
	} # end if
} # end sub priceperm
sub costperfoot {
	my $self = $_[0];
	my $Paper = $self->Paper();
	return sprintf('%.2f', ($$self{'Cost'}/100 ) * ( $Paper->wpsi() * 144 ) );
}
sub priceperfoot {
	my $self = $_[0];
	my $Paper = $self->Paper();
	return sprintf('%.2f', $$self{'Price'} * ( $Paper->wpsi() * 144 ) /100 );
}

sub markup {
	if ( @_ > 1 ) {
		$_[0]{'Markup'} = $_[1];
	} # end if
	return $_[0]{'Markup'};
} # end sub markup

sub price {
	if ( @_ > 1 ) {
		$_[0]{'Price'} = $_[1];
	} # end if
	if ( ! defined $_[0]{'Price'} ) {
		$_[0]{'Price'} = sprintf( '%.2f', $_[0]{'Cost'} * ( 1+($_[0]{'Markup'}/100) ) );
	} # end if
	return $_[0]{'Price'};
}

1;
__END__
