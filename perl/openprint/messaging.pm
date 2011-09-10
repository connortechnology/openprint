use strict;
package openprint::messaging;

use openprint;
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::Message;

sub history {
	if ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Message = new openprint::Message( $param{'message_id'} );
		$variable{'error'} .= $Message->destroy();
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		my $Message = new openprint::Message( $param{'message_id'} );
		$variable{'error'} .= $Message->destroy();
	} # end if

	if ( ( ! $session{'/messaging/history.html?lastupdated'} ) or ( time - $session{'/messaging/history.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/messaging/history.html', 'created_on_start', '' );
		ssi::setup_date_select( '/messaging/history.html', 'created_on_end', '' );
		ssi::setup_date_select( '/messaging/history.html', 'sent_on_start', -31 );
		ssi::setup_date_select( '/messaging/history.html', 'sent_on_end', '' );
	} # end if
	ssi::save_params( '/messaging/history.html', ( 
				'created_on_start_year','created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'sent_on_start_year','sent_on_start_month','sent_on_start_day',
				'sent_on_end_year','sent_on_end_month','sent_on_end_day',
				'from_id', 'to_id' ) );
} # end sub history

sub _history {
	if ( ! $param{'btnFunction'} ) {
	ssi::save_params( '/messaging/history.html', ( 
				'created_on_start_year','created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'sent_on_start_year','sent_on_start_month','sent_on_start_day',
				'sent_on_end_year','sent_on_end_month','sent_on_end_day',
				'from_id', 'to_id' ) );
	} # end if
} # end sub _history

sub inbox {
	my $Message = $variable{'Message'} = new openprint::Message( $param{'message_id'} );
	if ( sets::isin( $param{'btnFunction'}, [ 'Save', 'Send' ] ) ) {
		if ( $param{'btnFunction'} eq 'Send' and ! $variable{'error'} ) {
			$Message->sent_on('NOW()');
		} # end if send
		$variable{'error'} .= $Message->save(\%param);
	} elsif ( ! $param{'btnFunction'} ) {
		$log->error("Invalid value for btnFunction $param{btnFunction}");
	} else {
		ssi::save_params( '/messaging/inbox.html', ( 
				'sent_on_start_year','sent_on_start_month','sent_on_start_day',
				'sent_on_end_year','sent_on_end_month','sent_on_end_day',
		) );
	} # end if
	if ( ( ! $session{'/messaging/inbox.html?lastupdated'} ) or ( time - $session{'/messaging/inbox.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/messaging/history.html', 'sent_on_start', -31 );
		ssi::setup_date_select( '/messaging/history.html', 'sent_on_end', '' );
	} # end if
} # end sub inbox
sub _inbox {
	if ( $param{'action'} eq 'delete' ) {
		my $To = new openprint::Message_To( { 'message_id'=>$param{'message_id'},'user_id'=>$session{'user_id'} } );
		$variable{'error'} .= $To->delete();	
	} elsif ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/messaging/inbox.html', ( 
				'starting_on_start_year','starting_on_start_month','starting_on_start_day',
				'starting_on_end_year','starting_on_end_month','starting_on_end_day',
				'user_id', 'category_id' ) );
	} # end if
} # end sub _inbox
sub drafts {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/messaging/drafts.html', ( 
				'sent_on_start_year','sent_on_start_month','sent_on_start_day',
				'sent_on_end_year','sent_on_end_month','sent_on_end_day',
		) );
	} # end if
	if ( ( ! $session{'/messaging/drafts.html?lastupdated'} ) or ( time - $session{'/messaging/drafts.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/messaging/drafts.html', 'sent_on_start', -31 );
		ssi::setup_date_select( '/messaging/drafts.html', 'sent_on_end', '' );
	} # end if
} # end sub drafts
sub _drafts {
	if ( $param{'action'} eq 'delete' ) {
		my $Message = new openprint::Message( $param{'message_id'} );
		$variable{'error'} .= $Message->delete();	
	} elsif ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/messaging/drafts.html', ( 
				'starting_on_start_year','starting_on_start_month','starting_on_start_day',
				'starting_on_end_year','starting_on_end_month','starting_on_end_day',
				'user_id', 'category_id' ) );
	} # end if
} # end sub _drafts
sub sent {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/messaging/sent.html', ( 
				'sent_on_start_year','sent_on_start_month','sent_on_start_day',
				'sent_on_end_year','sent_on_end_month','sent_on_end_day',
		) );
	} # end if
	if ( ( ! $session{'/messaging/sent.html?lastupdated'} ) or ( time - $session{'/messaging/sent.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/messaging/sent.html', 'sent_on_start', -31 );
		ssi::setup_date_select( '/messaging/sent.html', 'sent_on_end', '' );
	} # end if
} # end sub sent
sub _sent {
	if ( $param{'action'} eq 'delete' ) {
		my $To = new openprint::Message_To( { 'message_id'=>$param{'message_id'},'user_id'=>$session{'user_id'} } );
		$variable{'error'} .= $To->delete();	
	} elsif ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/messaging/sent.html', ( 
				'starting_on_start_year','starting_on_start_month','starting_on_start_day',
				'starting_on_end_year','starting_on_end_month','starting_on_end_day',
				'user_id', 'category_id' ) );
	} # end if
} # end sub _sent

sub edit {
	$variable{'Message'} = new openprint::Message( $param{'message_id'} );
	$variable{'Message'}->save() if ! $variable{'Message'}->id();
} # end sub edit

sub view {
	my $Message = $variable{'Message'} = new openprint::Message( $param{'message_id'} );
	if ( sets::isin( $param{'btnFunction'}, [ 'Save', 'Send' ] ) ) {
		if ( $param{'btnFunction'} eq 'Send' and ! $variable{'error'} ) {
			$Message->sent_on('NOW()');
		} # end if send
		$variable{'error'} .= $Message->save(\%param);
	} # end if
} # end sub view

sub _view {
	my $Message = $variable{'Message'} = new openprint::Message( $param{'message_id'} );
	$Message->set( \%param );
} # end sub _view

sub _to {
	my $Message = $variable{'Message'} = new openprint::Message( $param{'message_id'} );
	$Message->save() if ! $Message->id();
	if ( $param{'action'} eq 'add' ) {
		my $To = new openprint::Message_To();
		$variable{'error'} .= $To->save({
			'message_id'=>	$param{'message_id'},
			'user_id'	=>	$param{'user_id'},
			});
	} elsif ( $param{'action'} eq 'remove' ) {
		my $To = new openprint::Message_To(\%param);
		$To->delete();
	} # end if
	
} # end sub _to

1;
__END__
