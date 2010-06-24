package openprint::PageFlip;
@ISA = qw( openprint::Object );

use openprint ();

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require openprint::PageFlip_Page;

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

sub Pages {
	my ( $self, %params ) = @_;

	if ( %params ) {
		$params{'pageflip_id'} = $$self{'id'};
		return openprint::PageFlip_Page->find(%params);
	} # end if
	if ( ! $$self{'Pages'} ) {
		@{$$self{'Pages'}} = openprint::PageFlip_Page->find('pageflip_id'=>$$self{'id'}, 'order'=>'page');
	} # end if
	return @{$$self{'Pages'}};
} # end sub Pages

1;
__END__
