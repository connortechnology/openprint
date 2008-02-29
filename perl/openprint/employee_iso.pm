package openprint::employee_iso;
use openprint;
use vars qw( %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require openprint::CAR;


sub car {
	$variable{'CAR'} = new openprint::CAR( $param{'car_id'} );
} # end sub view_car
sub _car_view_part1 {
	$variable{'CAR'} = new openprint::CAR( $param{'car_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'issued_on'} = sprintf('%.4d-%.2d-%.2d', @param{'issued_on_year','issued_on_month','issued_on_day'} );
		$param{'reply_by'} = sprintf('%.4d-%.2d-%.2d', @param{'reply_by_year','reply_by_month','reply_by_day'} );
		$param{'printed_on'} = sprintf('%.4d-%.2d-%.2d', @param{'printed_on_year','printed_on_month','printed_on_day'} );
		$param{'presses'} = ref $param{'presses'} eq 'ARRAY' ? join(';', @{$param{'presses'}} ) : $param{'presses'};
		$param{'part1_signed_on'} = sprintf('%.4d-%.2d-%.2d', @param{'part1_signed_on_year','part1_signed_on_month','part1_signed_on_day'} );
		$$variable{'error'} .= $variable{'CAR'}->save( \%param );
	} # end if
} # end sub _car_view_part1
sub _car_view_part2 {
	$variable{'CAR'} = new openprint::CAR( $param{'car_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'part2_signed_on'} = sprintf('%.4d-%.2d-%.2d', @param{'part2_signed_on_year','part2_signed_on_month','part2_signed_on_day'} );
		$$variable{'error'} .= $variable{'CAR'}->save( \%param );
	} # end if
} # end sub _car_view_part2
sub _car_view_part3 {
	$variable{'CAR'} = new openprint::CAR( $param{'car_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'part3_signed_on'} = sprintf('%.4d-%.2d-%.2d', @param{'part3_signed_on_year','part3_signed_on_month','part3_signed_on_day'} );
		$param{'reprint_on'} = sprintf('%.4d-%.2d-%.2d', @param{'reprint_on_year','reprint_on_month','reprint_on_day'} );
		$$variable{'error'} .= $variable{'CAR'}->save( \%param );
	} # end if
} # end sub _car_view_part3
sub _car_view_part4 {
	$variable{'CAR'} = new openprint::CAR( $param{'car_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'part4_signed_on'} = sprintf('%.4d-%.2d-%.2d', @param{'part4_signed_on_year','part4_signed_on_month','part4_signed_on_day'} );
		$$variable{'error'} .= $variable{'CAR'}->save( \%param );
	} # end if
} # end sub _car_view_part4

sub _car_edit_part1 {
	$variable{'CAR'} = new openprint::CAR( $param{'car_id'} );
}
sub _car_edit_part2 {
	$variable{'CAR'} = new openprint::CAR( $param{'car_id'} );
}
sub _car_edit_part3 {
	$variable{'CAR'} = new openprint::CAR( $param{'car_id'} );
}
sub _car_edit_part4 {
	$variable{'CAR'} = new openprint::CAR( $param{'car_id'} );
}

1;
__END__
