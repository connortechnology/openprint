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
$openprint::log->debug("new User_Profile");
	%{$$self{'fields'}} = map { $_->field(), $_ } openprint::User_Profile_Entry->find('user_id'=>$user_id);
$openprint::log->debug("new User_Profile now listing fields and values");
foreach my $f ( keys %{$$self{'fields'}} ) {
$openprint::log->debug("$f => " . $$self{'fields'}{$f}-value() );
}
	return $self;
} # end sub new

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self);
	my $name = $AUTOLOAD;
	
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
	my $Entry = $_[0]{'fields'}{$_[1]} if $_[0]{'fields'};
	if ( @_ > 2 ) {
		if ( ! $Entry ) {
			$Entry = new openprint::User_Profile_Entry();
			$_[0]{'fields'}{$_[1]} = $Entry;
			my $Field = openprint::User_Profile_Field->find_one('name'=>$_[1]);
			$Entry->set({ 'field_id' => $Field->id(), 'user_id' => $_[0]{'user_id'} } );
		} # end if
		$_ = $Entry->save( { 'value' => $_[2] } );
		$openprint::log->debug("Saving " . $Entry->field() . ': ' . $_[2] . " error: $_ " );
	} # end if 
		
	if ( $Entry ) {
		$openprint::log->debug("Returning Entry");
		return $Entry->value();
	}
	$openprint::log->debug("Returning No Entry");
	return undef;
} # end sub value

sub save {
	my $error;
	foreach my $Field ( values %{$_[0]{'fields'}} ) {
		$error .= $Field->save();
	} # end foreach
	return $error;
} # end sub save

1;
__END__
