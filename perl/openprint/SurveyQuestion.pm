package openprint::SurveyQuestion;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::SurveyQuestionAvailableAnswer;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'survey_questions';
$serial = 'survey_questions_id_seq';

%fields = (
	'id'			=>	'id',
	'text'			=>	'text',
	'type'			=>	'type',
	'survey_id'		=>	'survey_id',
	'category_id'	=>	'category_id',
);

sub AvailableAnswers {
	return openprint::SurveyQuestionAvailableAnswer->find('question_id'=>$_[0]{'id'});
} # end sub AvailableAnswers

1;
__END__
