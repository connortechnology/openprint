use strict;
package openprint::Survey_Response;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table %fields %transforms %defaults $serial );
$debug = 1;
$serial = 'survey_responses_id_seq';
$table = 'survey_responses';

%fields = (
		'survey_id'		=>	'survey_id',
		'company_id'	=>	'company_id',
		'user_id'		=>	'user_id',
		'question_id'	=>	'question_id',
		'answer'		=>	'answer',
		'answer_id'		=>	'answer_id',
		'created_on'	=>	'created_on',
);

%defaults = (
	'created_on'	=>	q`NOW()`,
	'answer_id'		=>	q`undef`,
	'company_id'	=>	q`undef`,
	'survey_id'		=>	q`undef`,
	'answer'		=>	q`undef`,
	
);

1;
__END__
