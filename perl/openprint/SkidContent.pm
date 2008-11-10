package openprint::SkidContent;
@ISA = qw(openprint::Object);

use strict;

require sql;

my $debug = 1;

my @fields = (
'skid_id','paper_id','quantity','purpose_id','units',
);

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM Skid_Contents WHERE 1>0';
	my @values;
	if ( $params{'skid_id'} ) {
		$sql .= ' AND skid_id=?';
		push @values, $params{'skid_id'};
	} # end if
	if ( $params{'paper_id'} ) {
		$sql .= ' AND paper_id=?';
		push @values, $params{'paper_id'};
	} # end if
	if ( $params{'Paper'} ) {
		$sql .= ' AND paper_id=?';
		push @values, $params{'Paper'}->id();
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::SkidContent::find( $sql)" . $openprint::dbh->errstr);
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading openprint::SkidContent::find( $sql) : " . @$data );
	} # end if
	return map { new openprint::SkidContent( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Skid_Contents WHERE skid_id=? AND paper_id=?', {}, @$self{'skid_id','paper_id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{keys %$data} = @$data{keys %$data};

} # end sub load

sub delete {
	my $self = shift;

    sql::execute( undef, undef, q{DELETE FROM Skid_Contents WHERE skid_id=? AND paper_id=? AND ( purpose_id=? OR purpose_id IS NULL)}, @$self{'skid_id','paper_id','purpose_id'} );
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	my $ac = sql::start_transaction( $openprint::dbh );
	$self->delete();
	sql::insert( undef, undef, 'Skid_Contents', {
			'skid_id'		=>	$$self{'skid_id'},
			'paper_id'		=>	$$self{'paper_id'},
			'purpose_id'	=>	$$self{'purpose_id'} ? $$self{'purpose_id'} : undef,
			'quantity'		=>	1*$$self{'quantity'},
			'units'			=>	$$self{'units'},
			});
	sql::end_transaction( $openprint::dbh, $ac );
	return;
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::SkidContent();
	@$new{keys %$self} = @$self{keys %$self};
	return $new;
} # end sub copy

sub purpose {
	my $self = shift;
	return $self->Purpose()->name();
} # end sub purpose

sub Purpose {
	my $self = shift;
	my $Purpose = new openprint::StockPurpose( $$self{'purpose_id'} );
	return $Purpose;
} # end sub Purpose

sub Paper {
	my $self = shift;
	my $Paper = new openprint::Paper( $$self{'paper_id'} );
	return $Paper;
} # end sub Paper

1;

__END__
~       
