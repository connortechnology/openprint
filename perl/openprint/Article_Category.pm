package openprint::Article_Category;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $table $serial %fields %defaults %transforms %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

require sql;

$table = 'article_categories';
$serial = 'article_categories_id_seq';

%fields = (
	'id'				=>	'id',
	'name'				=>	'name',
	'position'			=>	'position',
	'permalink'			=>	'permalink',
);

%transforms = (
);
%defaults = (
);

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM '.$table.' WHERE 1>0';
	my @values;

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if
	if ( $params{'limit'} ) {
		$sql .= " LIMIT $params{'limit'}";
	} # end if

	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->warn("Error loading Article_Categorys: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug ) {
		$openprint::log->debug("openprint::Article_Category::find($sql) (@values)");
	} # end if
	return map { new openprint::Article_Category( $_->{id}, $_ ); } @$data;
} # end sub find


1;

__END__
~       
