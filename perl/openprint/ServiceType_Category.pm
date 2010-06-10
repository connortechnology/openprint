package openprint::ServiceType_Category;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'ServiceType_Categories';
$serial = 'ServiceType_Categories_id_seq';

%fields = (
	'id'				=>	'id',
	'name'				=> 'name',
	'sorting'			=> 'sorting',
);
%transforms = (
);
%defaults = (
	'sorting'	=>	undef,
);

my $debug = 0;

sub find_one {
    my %params = @_;
    $params{'limit'} = 1;
    my @Results = find(%params);
    return $Results[0] if @Results;
	return;
} # end sub find_one

sub find {
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM ServiceType_Categories WHERE 1>0};

	if ( exists $params{'name'} ) {
		if ( ref $params{'name'} eq 'ARRAY' ) {
            $sql .= q{ AND name IN (}.join(',', map {'?'} @{$params{'name'}} ).')';
            push @values, @{$params{'name'}};
		} else {
			$sql .= ' AND name=?';
			push @values, $params{'name'};
		} # end if
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->error("Error loading ServiceType_Categories: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$log->debug("Loading ServiceType_Categories: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::ServiceType_Category( $_->{id}, $_ ); } @$data;
} # end sub find

1;
__END__
