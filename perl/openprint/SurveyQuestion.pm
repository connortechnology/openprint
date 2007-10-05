package openprint::SurveyQuestion;
@ISA = qw( openprint::Object );
use strict;
use openprint ();

require sql;

my @fields = (
	'text',
	'type',
	'survey_id',
	'category_id',
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::Survey( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM Survey_Questions WHERE 1>0};

		if ( $params{'survey_id'} ) {
			$sql .= q{ AND survey_id=?};
			push @values, $params{'survey_id'};
		} # end if
		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
		my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		return map { new openprint::SurveyQuestion( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Survey_Questions WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub save {
	my ( $self, $params ) = @_;

	if ( $params ) {
		foreach my $key ( @fields ) {
		$$self{key} = $$params{$key};
		} 
	} # end if

	my @sql;
	foreach my $key ( @fields ) {
		push @sql, $key, $$self{$key};
	} 
	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('survey_question_id_seq'::text)} );
		if ( my $e = sql::insert( $openprint::log, $openprint::dbh, 'Survey_Questions', 'id', $$self{'id'}, @sql ) ) {
			$openprint::dbh->rollback();
		} # end if
	} else {
		if ( my $e = sql::update( $openprint::log, $openprint::dbh, 'Survey_Questions', "id=$$self{'id'}", @sql ) ) {
			$openprint::dbh->rollback();
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();

} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::SurveyQuestion();
	@$new{@fields} = @$self{@fields};
	return $new;
} # end sub copy

1;
__END__
