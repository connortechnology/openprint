use strict;
package openprint::Upload;
our @ISA = qw( openprint::Object );

require openprint::Company;
require openprint::File;
use openprint ();
use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'uploads';
$serial = 'upload_id_seq';
%fields = (
	'start'	=>	'start',
	'size'	=>	'size',
	'total'	=>	'total',
	'id'	=>	'id',
	'finished'	=>	'finished',
	'company_id'	=>	'company_id',
	'user_id'		=>	'user_id',
	'company'		=>	'company',	
	'type'			=>	'type',
);

sub Company {
	my $self = shift;
	return new openprint::Company($$self{company_id});
} # end sub Company

sub User {
	my $self = shift;
	return new openprint::User($$self{user_id});
} # end sub User

sub Files {
	my $self = shift;
	return openprint::File::find('upload_id'=>$$self{id});
} # end sub

sub total_text {
	my ( $self ) = @_;
	return misc::format_bytes( $$self{'total'}, '.1' );
} #end sub total_text
sub size_text {
	my ( $self ) = @_;
	return misc::format_bytes( $$self{'size'}, '.1' );
} #end sub size_text
1;
__END__
