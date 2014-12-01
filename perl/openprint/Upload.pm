use strict;
package openprint::Upload;
our @ISA = qw( openprint::Object );

require misc;

use openprint ();
use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'uploads';
$serial = 'uploads_id_seq';
%fields = (
	id			=>	'id',
	start		=>	'start',
	size		=>	'size',
	total		=>	'total',
	finished	=>	'finished',
	company_id	=>	'company_id',
	user_id		=>	'user_id',
	file_path	=>	'file_path',
	company		=>	'company',
	type		=>	'type',
	complete	=>	'complete',
);
%defaults = (
	start		=>	q`'NOW()'`,
	size		=>	undef,
	total		=>	undef,
	finished	=>	0,
	complete	=>	undef,
);

sub Company {
	require openprint::Company;
	return new openprint::Company($_[0]{company_id});
} # end sub Company

sub User {
	require openprint::User;
	return new openprint::User($_[0]{user_id});
} # end sub User

sub Files {
	require openprint::File;
	return openprint::File->find(upload_id=>$_[0]{id});
} # end sub

sub total_text {
	return misc::format_bytes( $_[0]{total}, '.1' );
} #end sub total_text
sub size_text {
	return misc::format_bytes( $_[0]{size}, '.1' );
} #end sub size_text

sub path {
	return join('/',$openprint::config{ProjectFilesPath}, $_[0]->Company()->name(),$_[0]{file_path} );
}

1;
__END__
