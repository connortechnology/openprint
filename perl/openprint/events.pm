package openprint::events;

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

require openprint::Event;
require openprint::Event_Category;

sub history {
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'starting_on'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'starting_on_year','starting_on_month','starting_on_day','starting_on_hour','starting_on_minute'} );
		$param{'ending_on'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'ending_on_year','ending_on_month','ending_on_day','ending_on_hour','ending_on_minute'} );
		if ( ! $param{'event_id'} ) {
			if ( openprint::Event->find_one('created_by'=>$session{'user_id'},'starting_on'=>$param{'starting_on'},'ending_on'=>$param{'ending_on'}, 'name'=>$param{'name'} ) ) {
				$variable{'error'} = 'Not creating duplicate.<br/>';
				return;
			} # end if
		} # end if
		my $Event = new openprint::Event( $param{'event_id'} );
		$variable{'error'} .= $Event->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Event = new openprint::Event( $param{'event_id'} );
		$variable{'error'} .= $Event->destroy();
	} elsif ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/event/history.html', ( 'starting_on_start_year','starting_on_start_month','starting_on_start_day','starting_on_end_year','starting_on_end_month','starting_on_end_day') );
	} # end if

	if ( ( ! $session{'/event/history.html?lastupdated'} ) or ( time - $session{'/event/history.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/event/history.html', 'starting_on_start', -31 );
		ssi::setup_date_select( '/event/history.html', 'starting_on_end', '' );
	} # end if
} # end sub history

sub _history {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/event/history.html', ( 'starting_on_start_year','starting_on_start_month','starting_on_start_day','starting_on_end_year','starting_on_end_month','starting_on_end_day') );
	} # end if
} # end sub _history

sub edit {
	$variable{'Event'} = new openprint::Event( $param{'event_id'} );
	if ( $param{'btnFunction'} eq 'Copy' ) {
		$variable{'Event'} = $variable{'Event'}->copy();
		$variable{'error'} .= $variable{'Event'}->save();
	} # end if
} # end sub edit

1;
__END__
