use strict;
package openprint::User_Profile;
require openprint::User_Profile_Entry;

use vars qw( $AUTOLOAD );

# Not backed by db, this is an abstract object providing a convenient interface to User_Profile_Fields and Values

sub new {
	my ( $parent, $user_id ) = @_;

	my $self = {};
	bless $self, $parent;
	$$self{'user_id'} = $user_id;
	@{$$self{'fields'}} = map { $_->field(), $_ } openprint::User_Profile_Entry->find('user_id'=>$user_id);
	return $self;
} # end sub new

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self);
	my $name = $AUTOLOAD;
#if ( $self eq 'supplier' ) {
#$openprint::log->debug("Autoload $type $name");
#}
	
	$name =~ s/.*://;
	if ( @_ ) {
		if ( exists $$self{'fields'}{$name} ) {
			return $$self{'fields'}{$name}->value( $_[0] );
		} else {
			# create a new entry
		} # end if
	} elsif ( $$self{'fields'} and exists $$self{'fields'}{$name} ) {
			return $$self{'fields'}{$name}->value( );
	} # end if
	return undef;
} # end sub AUTOLOAD

sub value {
	return $_[0]{'fields'}{$_[1]} if $_[0]{'fields'};
	return undef;
} # end sub value
1;
__END__

