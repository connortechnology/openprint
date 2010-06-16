package openprint::SurveyQuestion;
@ISA = qw( openprint::Object );
use strict;
use openprint ();

require sql;
require openprint::SurveyQuestionAvailableAnswer;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'survey_questions';
$serial = 'survey_questions_id_seq';

my %fields = (
	'id'			=>	'id',
	'text'			=>	'text',
	'type'			=>	'type',
	'survey_id'		=>	'survey_id',
	'category_id'	=>	'category_id',
);

sub AvailableAnswers {
	my ( $self ) = @_;
	return openprint::SurveyQuestionAvailableAnswer->find('question_id'=>$$self{'id'});
} # end sub AvailableAnswers

sub delete {
	my $self = shift;
	my $ac = sql::start_transaction();
	sql::execute( undef, undef, q{DELETE FROM Survey_Questions WHERE id=?}, $$self{id} );
	sql::end_transaction( $ac );
} # end sub delete
1;
__END__
