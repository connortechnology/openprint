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

package openprint::survey;

require openprint::Survey;
use openprint::EmailCampaign;
use openprint::MarketingCategory;
use Mail::Sendmail;
use MIME::QuotedPrint;
use Email::Valid;
use strict;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub view {
    $variable{'Survey'} = new openprint::Survey( $param{'survey_id'} );
    if ( $param{'btnFunction'} eq 'Save' ) {
        $variable{'error'} = $variable{'Survey'}->save( \%param );
    } elsif ( $param{'btnFunction'} eq 'Delete' ) {
        $variable{'error'} = $variable{'Survey'}->delete( );
    } # end if
} # end sub history

sub edit {
    $variable{'Survey'} = new openprint::Survey( $param{'survey_id'} );
    if ( $param{'btnFunction'} eq 'Copy' ) {
        $variable{'Survey'} = $variable{'Survey'}->copy();
        $variable{'error'} = $variable{'Survey'}->save( );
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

sub view {
} # end sub view

1;

__END__

