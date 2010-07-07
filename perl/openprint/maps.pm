package openprint::maps;
use openprint;
use vars qw( %variable %session %param %config $log $dbh $r );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::Location;

use strict;

sub index {
   if ( $param{'selected_name'} ) {
        $variable{'Selected'} = openprint::Location->find_one( 'name' => $param{'selected_name'} );
    } elsif ( $param{'selected_id'} ) {
        $variable{'Selected'} = new openprint::Location( $param{'selected_id'} );
    } # end if
    if ( $param{'location_name'} ) {
        $variable{'Location'} = openprint::Location->find_one( 'name' => $param{'location_name'} );
    } elsif ( $param{'location_id'} ) {
        $variable{'Location'} = new openprint::Location( $param{'location_id'} );
    } else {
        $variable{'Location'} = new openprint::Location( 1 );
    } # end if
    if ( defined $param{'parent'} and $variable{'Location'}->parent() ) {
        $variable{'Location'} = $variable{'Location'}->parent();
    } # end if
    $variable{'MapFile'} = $variable{'Selected'} ? join('_', $variable{'Location'}->name(), $variable{'Selected'}->name() ) : $variable{'Location'}->name();

} # end sub index

1;
__END__
