package openprint::PaperPrice;
@ISA = qw(openprint::Object);

my $debug = 1;

use vars qw( %fields %transforms %defaults );

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
	'Min' => [ 's/(\d*)/$1/g' ],
	'Max' => [ 's/(\d*)/$1/g' ],
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
	if ( $params{'pricelist_id'} ) {
		$sql .= ' AND lngListindex=?';
		push @values, $params{'pricelist_id'};
	} elsif ( $params{'Pricelist'} ) {
		$sql .= ' AND lngListindex=?';
		push @values, $params{'Pricelist'}->id();
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

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Paper_Prices WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{qw/id pricelist_id paper_id Min Max Units Cost Markup Price Discountable/} = 
		@$data{qw/id lnglistindex lngpaperindex lngmin lngmax strunits dblcost dblmarkup dblprice ysndiscountable/};

} # end sub load

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM Paper_Prices WHERE id=?}, $$self{'id'} );
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	$$self{Price} = $$self{Cost} * ( 1+($$self{Markup}/100) ) if ( ! $$self{Price} );

	my @sql = (
			'lngListIndex',			$$self{'pricelist_id'},
			'lngPaperIndex',		$$self{'paper_id'},
			'lngMin',				$$self{'Min'} eq '' ? undef : $$self{'Min'},
			'lngMax',				$$self{'Max'} eq '' ? undef : $$self{'Max'},
			'strUnits',				$$self{'Units'},
			'dblCost',				1*$$self{'Cost'},
			'dblMarkup',			1*$$self{'Markup'},
			'dblPrice',				1*$$self{'Price'},
			'ysnDiscountable',		$$self{'Discountable'},
			);
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('paper_prices_id_seq')});
		if ( my $error = sql::insert( undef, undef, 'Paper_Prices', [ 'id', $$self{'id'}, @sql ] ) ) {
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'Paper_Prices', ['id=?', $$self{'id'}], \@sql ) ) {
			return $error;
		} # end if
	} # end if
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::PaperPrice();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

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
