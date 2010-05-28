package openprint::PageFlip;
@ISA = qw( openprint::Object );

use openprint ();

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use vars qw( $table $serial %fields %defaults %transforms );
$table = 'pageflip';
$serial = 'pageflip_id_seq';

%fields = (
	'id'	=>	'id',
	'docket'	=>	'docket',
	'company_id'	=>	'company_id',
	'page_files'	=>	'page_files',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
);

1;
__END__
