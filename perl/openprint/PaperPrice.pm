package openprint::PaperPrice;
@ISA = qw(openprint::Object);

my $debug = 0;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'Paper_Prices';
$serial = 'paper_prices_id_seq';

use strict;

require sql;

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

sub Paper {
	my $self = shift;
	return new openprint::Paper( $$self{paper_id} );
} # end sub Paper

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

1;
__END__
