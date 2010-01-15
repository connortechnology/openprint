package openprint::articles;

use strict;
use openprint;
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::Article;

sub history {
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'company_id'} = $session{'company_id'} if ! $param{'company_id'};
		$param{'published_on'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'published_on_year','published_on_month','published_on_day','published_on_hour','published_on_minute'} );
		my $Article = new openprint::Article( $param{'articles_id'} );
		$variable{'error'} .= $Article->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Article = new openprint::Article( $param{'articles_id'} );
		$variable{'error'} .= $Article->destroy();
	} elsif ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/articles/history.html', ( 'published_on_start_year','published_on_start_month','published_on_start_day','published_on_end_year','published_on_end_month','published_on_end_day') );
	} # end if
	if ( ( ! $session{'/articles/history.html?lastupdated'} ) or ( time - $session{'/articles/history.html?lastupdated'} ) < ( 12*60*60 ) ) {
		ssi::setup_date_select( '/articles/history.html', 'published_on', -31 );
	} # end if
} # end sub history

sub _history {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/articles/history.html', ( 'published_on_start_year','published_on_start_month','published_on_start_day','published_on_end_year','published_on_end_month','published_on_end_day') );
	} # end if
} # end sub _history

sub edit {
	$variable{'Article'} = new openprint::Article( $param{'articles_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $variable{'Article'}->save(\%param);
		$variable{'Redirect'} = '/articles/history.html';
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		$variable{'Article'} = $variable{'Article'}->copy();
		$variable{'error'} .= $variable{'Article'}->save();
	} # end if
} # end sub edit
