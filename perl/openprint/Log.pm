use strict;
package openprint::Log;
our @ISA = qw( openprint::Object );
require openprint::Object;
require openprint::User;
require openprint::Log_Action;
require openprint::Host;

use vars qw( $debug $log $dbh $table $serial %fields %transforms %defaults %types );
$debug = 0;
$table = 'log';
$serial = 'log_id_seq';
%fields = (
	'id'	=>	'id',
	'user_id'		=>	'user_id',
	'company_id'	=>	'company_id',
	'date_time'		=>	'date_time',	
	'action_id'	=>	'action_id',
	'action'			=>	undef,
	'note'			=>	'note',
	'host_id'		=>	'host_id',
	'ip_address'	=>	undef,
);
%defaults = (
	'date_time'	=>	"'NOW()'",
	'user_id'	=>	q`$openprint::session{'user_id'}`,
	'company_id'	=>	q`$openprint::session{'company_id'}`,
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
	$_[0]{'Action'} = new openprint::Log_Action( $_[0]{'action_id'} ) if ! $_[0]{'Action'};
	return $_[0]{'Action'};
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
	if ( ( ! $_[0]{'host_id'} ) and ( $_[0]=>$_[0]{'ip_address'} ) ) {
		my $Host = openprint::Host->find_one('ip'=>$_[0]{'ip_address'});
		if ( ! $Host ) {
			$Host = new openprint::Host();
			$Host->save({'ip'=>$_[0]{'ip_address'}});
		} # endif	
		$_[0]->save({'host_id'=>$Host->id()});
	} # end if
		
	return new openprint::Host( $_[0]{'host_id'} );
} # end sub Host

sub action {
	if ( @_ > 1 ) {
		my $Action = openprint::Log_Action->find_one( 'name'=>$_[1] );
		$Action->save({'name'=>$_[1], 'description'=>$_[1]}) if $_[1] and ! $Action;
		$_[0]{'Action'} = $Action;
		return $Action->name();
	} # end if
	return $_[0]->Action()->name();
} # end sub action

1;
__END__
