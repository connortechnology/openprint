use strict;
package openprint::Survey_Question_Available_Answer;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'survey_question_available_answers';
$serial = 'survey_question_available_answers_id_seq';
%fields = (
	'id'		=>	'id',
	'question_id'	=>	'question_id',
	'answer_id'	=>	'answer_id',
	'sorting'	=>	'sorting',
);

1;
__END__
