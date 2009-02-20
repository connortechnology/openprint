package openprint::ProductionFeedback;
@ISA = qw(openprint::Object);

use strict;

require sql;
require openprint::Object;
use openprint ();

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'ProductionFeedback';
$serial = 'ProductionFeedback_id_seq';
%fields = (
	'id'			=>	'id',
	'project_id'	=>	'project_id',
	'service_id'	=>	'service_id',
	'starting_on'	=>	'starting_on',
	'ending_on'		=>	'ending_on',
	'user_id'		=>	'user_id',
	'comment'		=>	'comment',
);
%defaults = (
	'user_id'		=>	undef,
);
%transforms = (
	'project_id'	=> [ 's/\D//g' ],
	'service_id'	=> [ 's/\D//g' ],
	'user_id'		=> [ 's/\D//g' ],
);
sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM ProductionFeedback WHERE 1>0';
	my @values;

	if ( $params{'project_id'} ) {
		$sql .= ' AND project_id=?';
		push @values, $params{'project_id'};
	} # end if

	if ( $params{'service_id'} ) {
		$sql .= ' AND service_id=?';
		push @values, $params{'service_id'};
	} # end if

	$sql .= " ORDER BY $params{order}" if $params{'order'};
	$sql .= " LIMIT $params{limit}" if $params{'limit'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::ProductionFeedback::find( $sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::ProductionFeedback( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

1;

__END__
~       
