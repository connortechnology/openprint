package openprint::employee_performance;
use strict;

require sql;
require openprint::PerformancePoint;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub setup {
	if ( $param{'function'} eq 'Save' ) {
		foreach my $Type ( openprint::PerformancePoint_Type->find() ) {
			foreach my $Equipment ( openprint::Equipment->find(
						'use_in_scheduling'=>1,
						( $Type->category() ? ( 'category'=>$Type->category() ) : () ),
						) ) {
				my $Point = openprint::PerformancePoint->find_one('equipment_id'=>$$Equipment{'id'},'type_id'=> $$Type{'id'} );
				if ( ! $Point ) {
					next if ! $param{"value-$$Type{id}-$$Equipment{id}"};
					$Point = new openprint::PerformancePoint();
					$Point->set({
						'type_id'	=>	$$Type{'id'},
						'equipment_id'	=>	$$Equipment{'id'},
					});
				} # end if
				if ( ! $param{"value-$$Type{id}-$$Equipment{id}"} ) {
					$Point->delete();
				} elsif( 
						( $Point->value() != $param{"value-$$Type{id}-$$Equipment{id}"} ) or 
						( $Point->max_value() != $param{"max_value-$$Type{id}-$$Equipment{id}"} ) or 
						( $Point->units() ne $param{"units-$$Type{id}-$$Equipment{id}"} ) 
					   ) {
					$variable{'error'} .= $Point->save({
							'value'		=>	$param{"value-$$Type{id}-$$Equipment{id}"},
							'max_value'	=>	$param{"max_value-$$Type{id}-$$Equipment{id}"},
							'units'		=>	$param{"units-$$Type{id}-$$Equipment{id}"},
							});
				} # end if
			} # end foreach my $Equipment
		} # end foreach Type
	} # end if
} # end sub setup

sub _type {
	if ( $param{'function'} eq 'remove' ) {
		my $Type = new openprint::PerformancePoint_Type( $param{'type_id'} );
		$variable{'error'} .= $Type->delete();
	} # end if
} # end sub _type

sub history {
    ssi::save_params( '/employee/performance/history.html', (
                'starttime_start_year','starttime_start_month','starttime_start_day',
                'starttime_end_year','starttime_end_month','starttime_end_day',
                'category', 'equipment_id', 'operator_id' ) );
    ssi::setup_date_select( '/employee/performance/history.html', 'starttime_start', -31 );
    ssi::setup_date_select( '/employee/performance/history.html', 'starttime_end', '' );

} # end sub history

sub _history {
    ssi::save_params( '/employee/performance/history.html', (
                'starttime_start_year','starttime_start_month','starttime_start_day',
                'starttime_end_year','starttime_end_month','starttime_end_day',
                'category', 'equipment_id', 'operator_id' ) );
} # end sub _history


1;
__END__
