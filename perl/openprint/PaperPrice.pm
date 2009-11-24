package openprint::PaperPrice;
@ISA = qw(openprint::Object);

my $debug = 1;

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

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM Paper_Prices WHERE 1>0};
	my @values;

	if ( exists $params{'paper_id'} ) {
		$sql .= ' AND lngpaperindex=?';
		push @values, $params{'paper_id'};
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
	if ( ! $Paper->mweight() ) {
		# ROll papers won't have an mweight
		return sprintf('%.2f', $$self{'Cost'} *= $Paper->wpsi() * $Paper->width() * $Paper->height() * 1000 );
	} else {
		return sprintf('%.2f', $$self{'Cost'} *= $Paper->mweight() / 100 );
	} # end if
} # end sub costperm
sub priceperm {
	my $self = shift;
	my $Paper = $self->Paper();
	if ( ! $Paper->mweight() ) {
		# ROll papers won't have an mweight
		return sprintf('%.2f', $$self{'Price'} *= $Paper->wpsi() * $Paper->width() * $Paper->height() * 1000 );
	} else {
		return sprintf('%.2f', $$self{'Price'} *= $Paper->mweight() / 100 );
	} # end if
} # end sub priceperm

1;

__END__
~       
