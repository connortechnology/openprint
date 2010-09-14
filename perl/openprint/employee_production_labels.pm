package openprint::employee_production_labels;
use strict;

use openprint ();
use vars qw{ $log $dbh %config %variable %param };
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*variable = \%openprint::variable;
*param = \%openprint::param;

require openprint::Label;
require openprint::LabelType;

sub index {
} # end sub index

sub _label {
	my $Label = new openprint::Label( $param{'id'} );
	if ( $param{'action'} eq 'update' ) {
		$param{'value'} =~ s/<br\/>/\n/ig;
		$Label->set_data($param{'field'}=>$param{'value'});
		$Label->save();
		$variable{'PageContent'} = join('',$Label->get_data($param{'field'}));
	} elsif ( $param{'action'} eq 'get' ) {
		$variable{'PageContent'} = join('',$Label->get_data($param{'field'}));
	} elsif ( $param{'action'} eq 'getnohtml' ) {
		$variable{'PageContent'} = join('',$Label->get_data($param{'field'}));
		$variable{'PageContent'} =~ s/<br\/>/\n/ig;
	} # end if
} # end sub _label

sub label {
} # end sub label

1;
__END__
