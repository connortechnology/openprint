package openprint::ProjectService;
@ISA = qw( openprint::Object );
require openprint::Object;

use strict;

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Project_Contents WHERE lngServiceIndex=?', {}, $$self{'id'} );
		if ( ! $data ) {
			$openprint::log->error('Error loading Service: reason:'.$openprint::dbh->errstr());
		} # end if
	} # end if
	@$self{qw/id project_id status updated_on operator_id type_id starttime approved/} =
		@$data{qw/lngserviceindex lngprojectindex strstatus dtmlastmodified operator_id servicetype_id starttime arppoved/};
} # end sub load

1;
__END__
