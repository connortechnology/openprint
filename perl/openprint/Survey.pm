package openprint::Survey;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::SurveyQuestion;

my @fields = (
	'id',
	'name',
	'description',
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::Survey( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM Surveys WHERE 1>0};

		if ( $params{'name'} ) {
			$sql .= q{ AND name=?};
			push @values, $params{'name'};
		} # end if
		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );

		my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		$openprint::log->debug("Error loading Surveys: ".DBI->errstr ) if ! $data;
		return map { new openprint::Survey( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Surveys WHERE id=?}, {}, $$self{'id'} );
        if ( ! $data ) {
            $openprint::log->error( "Failure to load Surveys $$self{'id'}: Reason: " . $openprint::dbh->errstr );
            return;
        } # end if
    } # end if
    foreach my $key ( keys %{$data} ) {
        $$self{$key} = $$data{$key};
    } # end foreach
} # end sub load

sub save {
	my ( $self, $data ) = @_;

	my %sql;
	foreach ( @fields ) {
		$$self{$_} = $$data{$_} if $$data{$_};
		$sql{$_} = $$self{$_};
	} # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );
	
	if ( ! $$self{'id'} ) {
		@$self{'id'} = @sql{'id'} = sql::execute( undef, undef, q{SELECT nextval('survey_id_seq')} );
		if ( my $e = sql::insert( undef, undef, 'Surveys', \%sql ) ) {
            $openprint::dbh->rollback();
        } # end if
	} else {
		if ( my $e = sql::update( $openprint::log, $openprint::dbh, 'Surveys', ['id=?', $$self{'id'}], \%sql ) ) {
            $openprint::dbh->rollback();
        } # end i
	} # end if
    sql::end_transaction( $openprint::dbh, $ac );

	$self->load();
} # end sub save

sub delete {
	my $self = shift;
	my $ac = sql::start_transaction();
	sql::execute( undef, undef, q{DELETE FROM Survey_Questions WHERE survey_id=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM Survey_Responses WHERE survey_id=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM Survey_Answers WHERE survey_id=?}, $$self{id} );
	foreach my $Q ( $self->Questions() ) {
		foreach my $A ( $Q->AvailableAnswers() ) {
			$A->delete();
		} # end foreach
		$Q->delete();
	} # end foreach Question
	sql::execute( undef, undef, q{DELETE FROM Surveys WHERE id=?}, $$self{id} );
	sql::end_transaction( $ac );
} # end sub delete

sub next {
	my $self = shift;
	return new openprint::Survey( sql::execute( undef, undef, q{SELECT MIN(id) FROM Surveys WHERE id > ?}, $$self{id} ) );
} # end sub next;

sub previous {
	my $self = shift;
	return new openprint::Survey( sql::execute( undef, undef, q{SELECT MIN(id) FROM Surveys WHERE id > ?}, $$self{id} ) );
} # end sub previous

sub Questions {
    my $self = shift;
    if ( ! $$self{Questions} ) {
        @{$$self{Questions}} = openprint::SurveyQuestion::find('survey_id'=>$$self{id});
    } # end if
    return @{$$self{Questions}};
} # end sub questions

sub copy {
    my $self = shift;
    my $new = new openprint::Survey();
    $$new{name} = 'Copy of ' . $$self{name};
    $$new{description} = $$self{description};
    $new->save();
    foreach my $Q ( $self->Questions() ) {
        my $Q2 = $Q->copy();
        $Q2->survey_id($new->id());
		$Q2->save();
        push @{$$new{Questions}}, $Q2;
		foreach my $Available_Answer ( $Q->AvailableAnswers() ) {
			my $new_Available_Answer = $Available_Answer->copy();
			$new_Available_Answer->question_id( $Q2->id() );
			$new_Available_Answer->save({'question_id'=>$Q2->id()});
		} # end foreach 
    } # end foreach
    return $new;
} # end sub copy


1;
__END__
