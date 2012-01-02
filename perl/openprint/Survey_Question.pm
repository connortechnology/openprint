use strict;
package openprint::Survey_Question;
our @ISA = qw( openprint::Object );

require openprint::Survey_Question_Available_Answer;

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
	'alignment'	=>	'alignment',
);

%transforms = (
    'text' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	'alignment'	=>	1,
);

sub Available_Answers {
	return () if ! $_[0]{'id'};
	return openprint::Survey_Question_Available_Answer->find('question_id'=>$_[0]{'id'});
} # end sub Available_Answers

sub delete {
	my $error = '';
	foreach my $AA ( $_[0]->Available_Answers() ) {
		$error .= $AA->delete();
	} # end foreach AA
	return $error if $error;
	foreach my $R ( openprint::Survey_Response->find('question_id'=>$_[0]{'id'}) ) {
		$error .= $R->delete();
	} # end foreach Response
	return $error if $error;
	return $_[0]->SUPER::delete();	
} # end sub delete

1;
__END__
