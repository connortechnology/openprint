package openprint::Log;
@ISA = qw( openprint::Object );
require openprint::Object;
require openprint::User;
require openprint::logAction;
require openprint::Host;
use strict;

use vars qw( $debug $log $dbh $table $serial %fields %transforms %defaults %types );
$debug = 1;
$table = 'log';
$serial = 'log_id_seq';
%fields = (
	'id'	=>	'id',
	'user_id'		=>	'user_id',
	'company_id'	=>	'company_id',
	'date_time'		=>	'date_time',	
	'action_type'	=>	'action_type',
	'note'			=>	'note',
	'host_id'		=>	'host_id',
	'ip_address'	=>	undef,
);
%defaults = (
	'date_time'	=>	"'NOW()'",
);

%types = (
	2	=> 'Successful Login',
	3	=>	'Logout', 
	78	=>	'Failed Login',
	79	=> '',
);
use openprint ();
*log = \$openprint::log;
*dbh = \$openprint::dbh;

sub User {
	my $self = shift;
	return new openprint::User( $$self{user_id} );	
} # end sub User

sub Company {
	my $self = shift;
	return new openprint::Company( $$self{company_id} );	
} # end sub Company

sub Action {
	my $self = shift;
	return new openprint::logAction( $$self{action_type} );	
} # end sub Action

sub hostname {
	my ( $self, $new ) = @_;
	my $Host = $self->Host();

	if ( defined $new ) {
		$Host->save({'hostname'=>$new});
	} # end if
	return $Host->hostname();
} # end sub hostname

sub ip_address {
	my ( $self, $new ) = @_;
	my $Host = $self->Host();

	if ( defined $new ) {
		$Host = openprint::Host->find_one( 'ip'=>$new );
		if ( ! $Host ) {
			$Host = new openprint::Host();
			$Host->save({'ip'=>$new});
		} # end if
		$$self{'host_id'} = $Host->id();
	} # end if
	return $Host->ip();
} # end sub ip_address

sub Host {
	return new openprint::Host( $_[0]{'host_id'} );
} # end sub Host

1;
__END__
