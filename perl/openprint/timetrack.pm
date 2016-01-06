use strict;
package openprint::timetrack;

use openprint ();
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require Date::Format;
require openprint::Timetrack;
require openprint::Currency;
require ssi;
require DateTime::Format::Pg;
require DateTime::TimeZone;


sub history {
	if ( $param{func} eq 'Destroy' ) {
		my $Timetrack = new openprint::Timetrack( $param{timetrack_id} );
		$variable{error} .= $Timetrack->destroy();
	} elsif ( $param{func} eq 'Download' ) {
		ssi::save_params( '/timetrack/history.html', ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','invoiced','paid','user_id','company_id', 'service_id', 'billable') );
        my @header = ('Who', 'Company', 'Start', 'End', 'Duration', 'Service', 'Description', 'Rate', 'Price');
        my @data;
        my ( $total_hours, $total_value );
        foreach my $Timetrack ( openprint::Timetrack->find(
					ssi::date_filter( '/timetrack/history.html?starting_start', 'starting >=' ),
					ssi::date_filter( '/timetrack/history.html?starting_end', 'starting <=' ),
					( sets::isin( $session{user_type}, ['E', 'A'] ) ?
					  ( $session{'/timetrack/history.html?company_id'} ? ( 'company_id'   => $session{'/timetrack/history.html?company_id'} ) : () ) :
					  ( 'company_id'  => $session{company_id} ) ),
					( $session{'/timetrack/history.html?user_id'} ? ( 'user_id' => $session{'/timetrack/history.html?user_id'} ) : () ),
					( $session{'/timetrack/history.html?service_id'} ? ( 'service_id'   => $session{'/timetrack/history.html?service_id'} ) : () ),
					( $session{'/timetrack/history.html?billable'} ? ( 'billable' => $session{'/timetrack/history.html?billable'} ) : () ),
					'order'             => 'starting',
					) ) {
			next if $Timetrack->paid() and ! sets::isin( 1, split(',', $session{'/timetrack/history.html?paid'} ) );
			next if ( ! $Timetrack->paid() ) and ! sets::isin( 0, split(',', $session{'/timetrack/history.html?paid'} ) );
			next if $Timetrack->invoiced() and ! sets::isin( 1, split(',', $session{'/timetrack/history.html?invoiced'} ) );
			next if ( ! $Timetrack->invoiced() ) and ! sets::isin( 0, split(',', $session{'/timetrack/history.html?invoiced'} ) );

			push @data, ( $Timetrack->User()->name(), $Timetrack->Company()->name(), 
					Date::Format::time2str(($Timetrack->time_associated() ? $config{DateTimeFormat} : $config{DateFormat}), Date::Parse::str2time( $Timetrack->starting() ) ),
					Date::Format::time2str(($Timetrack->time_associated() ? $config{DateTimeFormat} : $config{DateFormat}), Date::Parse::str2time( $Timetrack->ending() ) ),
					misc::seconds_to_pretty_interval( $Timetrack->elapsed() ),
					$Timetrack->Service()->name(),
					$Timetrack->description(),
					join('',$Timetrack->get('rate','units' ) ),
					openprint::Currency::format( $Timetrack->value() ),
					);
			$total_hours += $Timetrack->elapsed();
			$total_value += $Timetrack->value();
		} # end foreach Timetrack
		push @data, '','','','Totals:',misc::seconds_to_pretty_interval($total_hours),'','','',openprint::Currency::format($total_value);
		misc::export_csv( $r, $log, \%variable, 'timetracks.csv', \@header, \@data );

	} elsif ( $param{func} eq 'reset' ) {
		foreach ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','invoiced','paid','user_id','company_id', 'service_id', 'lastupdated', 'billable' ) {
			delete $session{'/timetrack/history.html?'.$_}
		} # end foreach
	} # end if

	_history();
	if ( ( ! $session{'/timetrack/history.html?lastupdated'} ) or ( time - $session{'/timetrack/history.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/timetrack/history.html', 'starting_start', -31 );
		ssi::setup_date_select( '/timetrack/history.html', 'starting_end', '' );
	} # end if

	$session{'/timetrack/history.html?invoiced'} = '0' if ! $session{'/timetrack/history.html?invoiced'};
	$session{'/timetrack/history.html?paid'} = '0' if ! $session{'/timetrack/history.html?paid'};
	if ( sets::isin( $session{user_type}, ['A','E'] ) ) {
		$session{'/timetrack/history.html?user_id'} = $session{user_id} if ! exists $session{'/timetrack/history.html?user_id'};
	} # end if
} # end sub history

sub _history {
	if ( ! $param{func} ) {
		ssi::save_params( '/timetrack/history.html', ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','invoiced','paid','user_id','company_id', 'service_id', 'billable','travel_associated','contains', 'keywords' ) );
	} # end if
} # end sub _history

sub edit {
	my $Timetrack = $variable{Timetrack} = new openprint::Timetrack( $param{timetrack_id} );
	if ( $param{func} eq 'Save' ) {
		$param{owner_id} = $session{company_id} if ! $param{owner_id};

        my $start_datetime = DateTime->new( time_zone => $openprint::TZ,
				( map { $_ => int($param{'starting_'.$_ }) } ( 'year', 'month', 'day', 'hour','minute' ) ),
                );

        my $end_datetime = DateTime->new( time_zone => $openprint::TZ,
				( map { $_ => int($param{'ending_'.$_ }) } ( 'year', 'month', 'day', 'hour','minute' ) ),
                );

        if ( $start_datetime > $end_datetime ) {
            $variable{error} .= 'Invalid end time. The end of the shift must occur after the start of the shift.  No changes made.<br/>';
            return;
        } # end if

        my $parser = 'DateTime::Format::Pg';

		$param{starting} = $parser->format_datetime( $start_datetime );
		$param{ending} = $parser->format_datetime( $end_datetime );
		if ( ! $param{timetrack_id} ) {
			if ( openprint::Timetrack->find_one(
						user_id		=>$param{user_id},
						owner_id	=>$param{owner_id},
						company_id	=>$param{company_id},
						starting	=>$param{starting},
						ending		=>$param{ending},
						service_id	=>( $param{service_id} ? $param{service_id} : undef ),
						) ) {
				$variable{error} = 'Not creating duplicate.<br/>';
				return;
			} # end if
		} # end if
		$variable{error} .= $Timetrack->save(\%param);
		if ( ! $variable{error} ) {
			if ( $param{referrer_invoice_id} ) {
				$_ = $param{referrer_invoice_id};
				$variable{ExternalRedirect} = '/invoice/edit.html?invoice_id='.$_;
				%param = ();
				return;
			} else {
				ssi::save_params( '/timetrack/edit.html', 'ending', 'company_id' );
				$variable{ExternalRedirect} = '/timetrack/history.html';
				return;
			} # end if
		} # end if
	} elsif ( $param{func} eq 'Copy' ) {
		$variable{Timetrack} = $variable{Timetrack}->copy();
		#$variable{error} .= $variable{Timetrack}->save();
	} elsif ( $param{func} eq 'Destroy' ) {
		my $Timetrack = new openprint::Timetrack( $param{timetrack_id} );
		$variable{error} .= $Timetrack->destroy();
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/timetrack/history.html';
			return;
		}
	} # end if
	if ( (!$variable{Timetrack}->id()) ) {
		$variable{Timetrack}->set(\%param); # Sets defaults
		if ( time - $session{'/timetrack/edit.html?lastupdated'} < ( 12*60*60 ) ) {
			$variable{Timetrack}->company_id( $session{'/timetrack/edit.html?company_id'} ) if ! $variable{Timetrack}->company_id();
			$variable{Timetrack}->starting( $session{'/timetrack/edit.html?ending'} ) if ! $variable{Timetrack}->starting();
			$variable{Timetrack}->ending( $session{'/timetrack/edit.html?ending'} ) if ! $variable{Timetrack}->ending();
		} # end if
	} # end if
} # end sub edit

1;
__END__
