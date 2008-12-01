package openprint::QuoteLevel;
@ISA = qw(openprint::Object);

use strict;

require sql;

use vars qw( %fields %transforms %defaults );
%fields = ( 'name'=>'name' );
%transforms = ();
%defaults = ();

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM QuoteLevels WHERE 1>0';
	my @values;

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::QuoteLevel::find( $sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::QuoteLevel( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM QuoteLevels WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{qw/id name/} = @$data{qw/id name/};

} # end sub load

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM QuoteLevels WHERE id=?}, $$self{'id'} );
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	if ( $param ) {
		$self->set( $param );
	} # end if

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$k} = $$self{$k};
	} # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('stockgroups_id_seq')});
		$sql{'id'} = $$self{'id'};
		if ( my $error = sql::insert( undef, undef, 'QuoteLevels', \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'QuoteLevels', ['id=?', $$self{'id'}], \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return;
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::QuoteLevel();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

1;

__END__
~       
