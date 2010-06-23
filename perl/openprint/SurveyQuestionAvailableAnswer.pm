package openprint::SurveyQuestionAvailableAnswer;
@ISA = qw( openprint::Object );
use strict;
use openprint ();

require sql;

use vars qw( $table $serial %feilds %transforms %defaults );
$table = 'Survey_Question_Available_Answers';
$serial = 'survey_question_available_answers_id_seq';
my %fields = (
	'id'	=>	'id',
	'question_id'	=>	'question_id',
	'answer_id'		=>	'answer_id',
	'sorting'		=>	'sorting',
);

1;
__END__
