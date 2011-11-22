use strict;
package openprint::Company_Profile;
require openprint::Company_Profile_Field;
require openprint::Company_Profile_Entry;
require openprint::Location;

use vars qw( $debug $AUTOLOAD );

# Not backed by db, this is an abstract object providing a convenient interface to Company_Profile_Fields and Values

sub new {
	my ( $parent, $company_id ) = @_;

	my $self = {};
	bless $self, $parent;
	$$self{'company_id'} = $company_id;
#$openprint::log->debug("new Company_Profile");
	if ( $company_id ) {
		%{$$self{'fields'}} = map { $_->field(), $_ } openprint::Company_Profile_Entry->find('company_id'=>$company_id);
	} # end if
#$openprint::log->debug("new Company_Profile now listing fields and values");
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
		%{$_[0]{'fields'}} = map { $_->field(), $_ } openprint::Company_Profile_Entry->find('company_id'=>$_[0]{'company_id'}) if $_[0]{'company_id'};
	} # end if
	
    my ( $Field, $Entry );
    if ( ref $_[1] eq 'openprint::User_Profile_Field' ) {
        $Field = $_[1];
        $Entry = $_[0]{'fields'}{$$Field{'name'}};
    } else {
        $Entry = $_[0]{'fields'}{$_[1]};
        # We don't do the Field here because we only need it when saving
    } # end if
	

	my $Entry = $_[0]{'fields'}{$_[1]} if $_[0]{'fields'};
	if ( @_ > 2 ) {
		if ( ! $Entry ) {
			$Entry = new openprint::Company_Profile_Entry();
			$_[0]{'fields'}{$_[1]} = $Entry;
			my $Field = openprint::Company_Profile_Field->find_one('name'=>$_[1]);
			$Entry->set({ 'field_id' => $Field->id(), '' => $_[0]{'company_id'} } );
		} # end if
		$_ = $Entry->save( { 'value' => $_[2] } );
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
	foreach my $Field ( openprint::Company_Profile_Field->find() ) {
		if ( $Field->type() eq 'date' ) {
			$self->value( $Field->name(), join('-', @$param{
						'field-'.$Field->id().'_year',
						'field-'.$Field->id().'_month',
						'field-'.$Field->id().'_day'} ) );
		} else {
			$self->value( $Field->name(), $$param{'field-'.$Field->id()} );
		} # end if
	} # end foreach $Field
} # end sub save

1;
__END__
