use strict;
package openprint::Survey_Question;
our @ISA = qw( openprint::Object );

require openprint::SurveyQuestionAvailableAnswer;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'survey_questions';
$serial = 'survey_questions_id_seq';

%fields = (
	'id'		=>	'id',
	'text'		=>	'text',
	'type'		=>	'type',
	'survey_id'	=>	'survey_id',
	'category_id'	=>	'category_id',
);

sub AvailableAnswers {
	return openprint::SurveyQuestionAvailableAnswer->find('question_id'=>$_[0]{'id'});
} # end sub AvailableAnswers

1;
__END__
