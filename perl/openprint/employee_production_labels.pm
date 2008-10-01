package openprint::employee_production_labels;
use strict;
use Date::Calc qw(Add_Delta_Days Date_to_Days check_date );
use MIME::QuotedPrint;

use openprint ();
use vars qw{ $log $dbh %config %variable %param };
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*variable = \%openprint::variable;
*param = \%openprint::param;

require sql;
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
		$variable{'PageContent'} = ssi::htmlize(join('',$Label->get_data($param{'field'})));
$openprint::log->debug("_label get " . join('',$Label->get_data($param{'field'})));
	} elsif ( $param{'action'} eq 'get' ) {
		$variable{'PageContent'} = join('',$Label->get_data($param{'field'}));
	} elsif ( $param{'action'} eq 'getnohtml' ) {
		$variable{'PageContent'} = join('',$Label->get_data($param{'field'}));
$openprint::log->debug('filtering');
		$variable{'PageContent'} =~ s/<br\/>/\n/ig;
	} # end if
} # end sub _label

sub label {
} # end sub label

1;

__END__
~	   
