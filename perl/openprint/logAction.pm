package openprint::logAction;
@ISA = qw( openprint::Object );
require openprint::Object;

my $debug = 1;
use strict;
use Date::Handler;

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM log_Actions WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) {
			$openprint::log->error('Error loading LogAction: reason:'.$openprint::dbh->errstr());
		} # end if
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub find {
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM log_actions WHERE 1>0};
	if ( $params{'id'} ) {
		$sql .= ' AND id=?';
		push @values, $params{'id'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading logAction: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading logAction: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::logAction( $_->{id}, $_ ); } @$data;
} # end sub find

return 1;
__END__
