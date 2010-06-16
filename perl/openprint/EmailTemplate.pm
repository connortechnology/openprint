package openprint::EmailTemplate;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 0;

use strict;
use vars qw( $table $serial %fields %defaults %transforms );

require sql;

$table = 'EmailTemplates';
$serial = 'emailtemplates_id_seq';

%fields = (
	'id'				=>	'id',
	'name'				=>	'name',
	'body'				=> 'body',
	'created_on'		=> 'created_on',
	'updated_on'		=> 'updated_on',
	'deleted'			=> 'deleted',
);

%transforms = (
);
%defaults = (
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'deleted'		=> 0,
);

1;
__END__
