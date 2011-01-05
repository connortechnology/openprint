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

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM Paper_Prices WHERE 1>0};
	my @values;

	if ( exists $params{'paper_id'} ) {
		$sql .= ' AND lngpaperindex=?';
		push @values, $params{'paper_id'};
	} # end if
	if ( exists $params{'stock_id'} ) {
		$sql .= ' AND lngpaperindex=?';
		push @values, $params{'stock_id'};
	} # end if
	if ( exists $params{'Paper'} ) {
		$sql .= ' AND lngpaperindex=?';
		push @values, $params{'Paper'}->id();
	} # end if
	if ( $params{'pricelist_id'} ) {
		$sql .= ' AND lngListindex=?';
		push @values, $params{'pricelist_id'};
	} elsif ( $params{'Pricelist'} ) {
		$sql .= ' AND lngListindex=?';
		push @values, $params{'Pricelist'}->id();
	} # end if
	if ( exists $params{'units'} ) {
		$sql .= ' AND strunits=?';
		push @values, $params{'units'};
	} # end if
	if ( exists $params{'service'} ) {
		$sql .= ' AND service=?';
		push @values, $params{'service'};
	} # end if
	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->warn("Error loading PaperPrices: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug) {
		$openprint::log->debug("openprint::PaperPrice::find($sql) (@values) " . @$data );
	} # end if
	return map { new openprint::PaperPrice( $_->{id}, $_ ); } @$data;
} # end sub find

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
~       
