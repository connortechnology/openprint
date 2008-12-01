package openprint::ServiceCategory;
@ISA = qw( openprint::Object );
use openprint ();
require openprint::Service;


use vars qw($log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'Service_Categories';
$serial = 'Service_Categories_id_seq';

%fields = (
	'id','id',
	'name','name',
);
%transforms = (
);
%defaults = (
);

sub find {
	my %params = @_;
	my $sql = q{SELECT * FROM Service_Categories WHERE 1>0};
	my @values;
    if ( $params{name} ) {
        $sql .= ' AND name=?';
        push @values, $params{name};
    } # end if
	if ( $params{'order'} ) {
		$sql .= qq{ ORDER BY $params{'order'} };
	} # end if
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->error("Error loading Service Categories: ($sql) (@values)");
		return;
	} # end if
	return map { new openprint::ServiceCategory( $_->{id}, $_ ) } @$data;
} # end sub find

sub Services {
	my $self = shift;
	
	return openprint::Service::find( 'category_id'=>$$self{'id'} );
} # end sub project_types
1;
__END__
