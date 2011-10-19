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
#$openprint::log->debug("new User_Profile");
	if ( $user_id ) {
		%{$$self{'fields'}} = map { $_->field(), $_ } openprint::User_Profile_Entry->find('user_id'=>$user_id);
	} # end if
#$openprint::log->debug("new User_Profile now listing fields and values");
#foreach my $f ( keys %{$$self{'fields'}} ) {
#$openprint::log->debug("$f => " . $$self{'fields'}{$f}-value() );
#}
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
	if ( ! $_[0]{'fields'} ) {
		%{$_[0]{'fields'}} = map { $_->field(), $_ } openprint::User_Profile_Entry->find('user_id'=>$_[0]{'user_id'}) if $_[0]{'user_id'};
	} # end if
	my $Entry = $_[0]{'fields'}{$_[1]};
	if ( @_ > 2 ) {
		# Saving
		if ( ! $Entry ) {
#$openprint::log->debug("No entry for $_[1], creating one");
			$Entry = new openprint::User_Profile_Entry();
			$_[0]{'fields'}{$_[1]} = $Entry;
			my $Field = openprint::User_Profile_Field->find_one('name'=>$_[1]);
			$Entry->set({ 'field_id' => $Field->id(), 'user_id' => $_[0]{'user_id'} } );
		} # end if
		$_ = $Entry->save( { 'value' => $_[2] } ) if $Entry->value() ne $_[2];
		#$openprint::log->debug("Saving " . $Entry->field() . ': ' . $_[2] . " error: $_ " );
	} # end if 
		
	if ( $Entry ) {
		#$openprint::log->debug("Returning Entry");
		return $Entry->value();
	}
	#$openprint::log->debug("Returning No Entry");
	return undef;
} # end sub value

sub save {
	my ( $self, $param ) = @_;
	foreach my $Field ( openprint::User_Profile_Field->find('order'=>'sort') ) {
		if ( $Field->type() eq 'date' ) {
			$self->value( $Field->name(), join('-', @$param{
						'field-'.$Field->id().'_year',
						'field-'.$Field->id().'_month',
						'field-'.$Field->id().'_day'} ) );
		} elsif ( sets::isin( $Field->type(), [ 'country','state','city' ] ) ) {
			if ( $$param{'field-'.$$Field{'id'}.'_name'} ) {
				my $parent_id = $self->value( openprint::Location->parent_type( $Field->type() ) );
				my $Location = openprint::Location->find_one('type'=>$Field->type(), 'name_lc'=>lc $$param{'field-'.$$Field{'id'}.'_name'}, 'parent_id'=>$parent_id );
				if ( ! $Location ) {
					$Location = new openprint::Location();
					$Location->save({'type'=>$Field->type(),'name'=>$$param{'field-'.$$Field{'id'}.'_name'}, 'parent_id'=>$parent_id});
				} # end if
				$self->value( $Field->name(), $Location->id() );
			} else {
				$self->value( $Field->name(), $$param{'field-'.$Field->id()} );
			} # end if
		} else {
			$self->value( $Field->name(), $$param{'field-'.$Field->id()} );
		} # end if
	} # end foreach $Field
} # end sub save

1;
__END__
