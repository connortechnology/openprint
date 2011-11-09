# Copyright (C) 2007 Isaac Connor <isaac@connortechnology.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

use strict;
package openprint::survey;

require openprint::Survey;
require openprint::Survey_Question;
require openprint::Survey_Answer;
require openprint::Survey_Response;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub view {
$log->debug("In survey view");
	$param{'survey_id'} =~ s/\D//g;
    my $Survey = $variable{'Survey'} = new openprint::Survey( $param{'survey_id'} );
    if ( $param{'btnFunction'} eq 'Save' ) {
        $variable{'error'} = $Survey->save( \%param );
    } elsif ( $param{'btnFunction'} eq 'Delete' ) {
        $variable{'error'} = $Survey->delete( );
    } elsif ( $param{'action'} eq 'submit' ) {
		my %Responses = map { $_->question_id(), $_ } openprint::Survey_Response->find('survey_id'=>$Survey->id(),'user_id'=>$session{'user_id'});
		foreach my $Question ( $Survey->Questions() ) {
			my $Response = $Responses{$$Question{id}};
			$Response = new openprint::Survey_Response() if ! $Response;
			if ( 
					( $Response->answer_id() != $param{'answer_id-'.$$Question{'id'}} ) or
					( $Response->answer() ne $param{'answer-'.$$Question{'id'}} ) 
			   ) {

				$variable{'error'} .= $Response->save({
						'company_id'	=>	$session{'company_id'},
						'user_id'		=>	$session{'user_id'},
						'survey_id'		=>	$$Survey{'id'},
						'question_id'	=>	$$Question{'id'},
						'answer_id'=>$param{'answer_id-'.$Question->id()},
						'answer'=>$param{'answer-'.$Question->id()},
						});
			} # end nif answer has changed
		} # end foreach Question
		if ( ! $variable{'error'} ) {
			$variable{'ExternalRedirect'} = '/survey/history.html';
			%param = ();
		} # end if
    } # end if
} # end sub view


sub edit {
	$param{'survey_id'} =~ s/\D//g;
	my $Survey = $variable{'Survey'} = new openprint::Survey( $param{'survey_id'} );
	if ( $param{'action'} eq 'Copy' ) {
		$variable{'Survey'} = $variable{'Survey'}->copy();
		$variable{'error'} = $variable{'Survey'}->save( );
	} elsif ( $param{'action'} eq 'Save' ) {
		$variable{'error'} = $variable{'Survey'}->save( \%param );
		foreach my $Question ( $Survey->Questions() ) {
			$variable{'error'} .= $Question->save({
					'text'=>$param{'text-'.$Question->id()},
					'type'=>$param{'type-'.$Question->id()},
					});
		} # end foreach Question
	} elsif ( $param{'action'} eq 'Delete' ) {
		$variable{'error'} .= $Survey->delete();
		if ( ! $variable{'error'} ) {
			$variable{'ExternalRedirect'} = '/survey/history.html';
			$variable{'information'} .= 'Survey successfully deleted.';
			%param = ();
		} # end if
	} # end if
} # end sub edit

sub responses {
    if ( $param{'btnFunction'} eq 'Delete' ) {
		my $Response = openprint::Survey_Response->find_one(
				'survey_id'=>$param{'survey_id'},
				'user_id'=>$param{'user_id'}
				);
		$Response->delete();
    } # end if
} # end sub responses

sub history {
	_history();
	ssi::setup_date_select( '/survey/history.html', 'created_on_start', -30 );
	ssi::setup_date_select( '/survey/history.html', 'created_on_end', '' );
} # end sub history
sub _history {
	ssi::save_params( '/survey/history.html', ( 
		( map { 'created_on_start_'.$_ } ( 'year','month','day' ) ),
		( map { 'created_on_end_'.$_ } ( 'year','month','day' ) ),
		) );
} # end sub _history

sub _questions_edit {
	$param{'survey_id'} =~ s/\D//g;
	$variable{'Survey'} = new openprint::Survey( $param{'survey_id'} );
	if ( $param{'action'} eq 'new' ) {
		my $Question = new openprint::Survey_Question();
		$variable{'error'} .= $Question->save({
			'survey_id'	=>	$param{'survey_id'},	
			});
	} elsif ( $param{'action'} eq 'delete' ) {
		my $Question = openprint::Survey_Question->find_one('id'=>$param{'question_id'} );
		if ( $Question ) {
			$variable{'error'} .= $Question->delete();
		} else {
			$log->error("attempt to delete unfound question $param{question_id}");
		} # end if
	} # end if
} # end sub _questions_edit

sub _answers_edit {
	$param{'question_id'} =~ s/\D//g;
	my $Question = $variable{'Question'} = new openprint::Survey_Question( $param{'question_id'} );
	if ( $param{'action'} eq 'delete' ) {
		$param{'answer_id'} =~ s/\D//g;
		my $Answer = openprint::Survey_Question_Available_Answer->find_one('answer_id'=>$param{'answer_id'}, 'question_id'=>$$Question{'id'});
		if ( $Answer ) {
		$variable{'error'} .= $Answer->delete();
		} else {
		$variable{'error'} .= 'Answer not found.';
		} # end if
	} elsif ( $param{'action'} eq 'add' ) {
		my $Answer = openprint::Survey_Answer->find_one('text'=>openprint::Survey_Answer->transform('text', $param{'text'} ) );
		if ( ! $Answer ) {
			$Answer = new openprint::Survey_Answer();
			$variable{'error'} .= $Answer->save({
					'question_id'	=>	$param{'question_id'},
					'text'			=>	$param{'text'},
					});
		} # end if
		my $AA = new openprint::Survey_Question_Available_Answer();
			$variable{'error'} .= $AA->save({
					'question_id'	=>	$param{'question_id'},
					'answer_id'		=>	$$Answer{'id'},
					});
	} # end if
} # end sub _answers_edit

sub questions {
} # end sub questions

1;
__END__
