package openprint::StockColour;
@ISA = qw(openprint::Object);

use strict;

require sql;

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM PaperColours WHERE 1>0';
	my @values;

	if ( $params{'shortname'} ) {
		$sql .= ' AND shortname=?';
		push @values, $params{'shortname'};
	} # end if
	if ( $params{'papers'} ) {
		$sql .= ' AND id IN (?)';
		push @values, [map { $_->name_id(); } @{$params{'papers'}}];
	} # end if
	if ( $params{'project_type'} ) {
		$sql .= ' AND id IN (SELECT DISTINCT name_id FROM papers WHERE id IN (SELECT lngPaperIndex FROM Paper_Recommendations WHERE lngprojecttypeindex=?))';
		push @values, $params{'project_type'}->id();
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::StockColour::find( $sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::StockColour( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM PaperColours WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{qw/id shortname longname/} = @$data{qw/id shortname longname/};

} # end sub load

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM PaperColours WHERE id=?}, $$self{'id'} );
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('paper_prices_id_seq')});
		sql::insert( undef, undef, 'PaperColours', $self );
	} else {
		sql::update( undef, undef, 'PaperColours', ['id=?', $$self{'id'}], $self );
	} # end if
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::StockColour();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

1;

__END__
~       
