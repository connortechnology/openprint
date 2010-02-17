package openprint::Host;
@ISA = qw( openprint::Object );
require openprint::Object;
use strict;

my $debug = 1;
use vars qw( $log $dbh $table $serial %fields %tansforms %defaults %types );
$table = 'hosts';
$serial = 'hosts_id_seq';
%fields = (
	'id'	=>	'id',
	'ip'	=>	'ip',
	'hostname'		=>	'hostname',
	'mac'	=>	'mac',	
);

sub find {
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM hosts WHERE 1>0};
	if ( $params{'id'} ) {
        if ( ref $params{'id'} eq 'ARRAY' ) {
            $sql .= q{ AND id IN (}.join(',', map {'?'} @{$params{'id'}} ).')';
            push @values, @{$params{'id'}};
        } else {
            $sql .= q{ AND id=?};
            push @values, $params{'id'};
        } # end if
	} # end if
	if ( $params{'ip'} ) {
		$sql .= ' AND ip=?';
		push @values, $params{'ip'};
	} # end if

	if ( exists $params{'hostname'} ) {
		if ( ! defined $params{'hostname'} ) {
			$sql .= ' AND hostname IS NULL';
		} else {
			$sql .= ' AND hostname=?';
			push @values, $params{'hostname'};
		} # end if
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading Host: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Host: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::Host( $_->{id}, $_ ); } @$data;
} # end sub find

sub resolve {
	my ( $self ) = @_;
	my @h = gethostbyaddr(pack('C4',split('\.',$$self{'ip'})),2);
	if ( @h ) {
		return $h[0];
	} # end if
	return;
} # end sub resolve

1;
__END__
