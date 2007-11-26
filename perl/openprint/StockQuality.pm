package openprint::StockQuality;
@ISA = qw(openprint::Object);

use strict;

require sql;

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM PaperQualities WHERE 1>0';
	my @values;

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
		$openprint::log->debug("openprint::StockQuality::find( $sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::StockQuality( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM PaperQualities WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{qw/id shortname longname/} = @$data{qw/id shortname longname/};

} # end sub load

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM PaperQualities WHERE id=?}, $$self{'id'} );
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('paper_prices_id_seq')});
		sql::insert( undef, undef, 'PaperQualities', $self );
	} else {
		sql::update( undef, undef, 'PaperQualities', ['id=?', $$self{'id'}], $self );
	} # end if
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::StockQuality();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

1;

__END__
~       
