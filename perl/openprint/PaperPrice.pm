package openprint::PaperPrice;
@ISA = qw(openprint::Object);

my $debug = 1;

use strict;

require sql;

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
	} elsif ($debug ) {
		$openprint::log->debug("openprint::PaperPrice::find($sql) (@values)");
	} # end if
	return map { new openprint::PaperPrice( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Paper_Prices WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{qw/id PricelistIndex PaperIndex Min Max Units Cost Markup Price Discountable/} = 
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
			'lngListIndex',			$$self{'PricelistIndex'},
			'lngPaperIndex',		$$self{'PaperIndex'},
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
		sql::insert( undef, undef, 'Paper_Prices', [ 'id', $$self{'id'}, @sql ] );
	} else {
		sql::update( undef, undef, 'Paper_Prices', ['id=?', $$self{'id'}], \@sql );
	} # end if
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::PaperPrice();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

1;

__END__
~       
