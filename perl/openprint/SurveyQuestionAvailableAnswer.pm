package openprint::SurveyQuestionAvailableAnswer;
@ISA = qw( openprint::Object );
use strict;
use openprint ();

require sql;

my @fields = (
	'question_id',
	'answer_id',
	'sorting',
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::Survey( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM Survey_Question_Available_Answers WHERE 1>0};

		if ( $params{'question_id'} ) {
			$sql .= q{ AND question_id=?};
			push @values, $params{'question_id'};
		} # end if
		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
		my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		return map { new openprint::SurveyQuestionAvailableAnswer( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Survey_Question_Available_Answers WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub save {
	my ( $self, $params ) = @_;

	if ( $params ) {
		foreach my $key ( @fields ) {
			$$self{key} = $$params{$key} if exists $$params{$key};
		} 
	} # end if

	my @sql;
	foreach my $key ( @fields ) {
		next if $key eq 'id';
		push @sql, $key, $$self{$key};
	} 
	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('survey_question_available_answers_id_seq'::text)} );
		if ( my $e = sql::insert( $openprint::log, $openprint::dbh, 'Survey_Question_Available_Answers', ['id', $$self{'id'}, @sql ] ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
	} else {
		if ( my $e = sql::update( $openprint::log, $openprint::dbh, 'Survey_Question_Available_Answers', ['id=?', $$self{'id'}], \@sql ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return;
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::SurveyQuestionAvailableAnswer();
	@$new{@fields} = @$self{@fields};
	delete $$new{'id'};
	return $new;
} # end sub copy
sub delete {
	my $self = shift;
	my $ac = sql::start_transaction();
	sql::execute( undef, undef, q{DELETE FROM Survey_Question_Available_Answers WHERE id=?}, $$self{id} );
	sql::end_transaction( $ac );
} # end sub delete

1;
__END__
