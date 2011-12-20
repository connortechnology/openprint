use strict;
require openprint::Object_Type;
package openprint::Privacy;
our @ISA = qw(openprint::Object);
use vars qw( $debug $table $serial %fields %find_fields %defaults %transforms );

$debug = 1;
$table = 'privacy';
$serial = 'privacy_id_seq';
%fields = (
	'id'				=>	'id',
	'object_type_id'	=>	'object_type_id',
	'object_type'		=>	undef,
	'object_id'			=>	'object_id',
	'mode'				=>	'mode',
	'privacy_mode'		=>	undef,
	'usergroup_id'		=>	'usergroup_id',# an array of group_id
	'relationship_type_id'	=>	'relationship_type_id',# an array of relationship_ids
	'user_id'				=>	'user_id', # an array
);
%find_fields = (
	'object_type'			=>	'(SELECT name FROM object_types WHERE id=object_type_id)',
	'usergroup_id'			=>	q`undef`,
	'user_id'				=>	q`undef`,
	'relationship_type_id'	=>	q`undef`,
);
%defaults = (
);
sub Object {
	$_ =  $_[0]->object_type()->new( $_[0]{'object_id'} );
	return $_;
} # end sub Object

sub privacy_mode {
$openprint::log->debug("Privacy mode! $_[1]");
	$_[0]{'mode'} = $_[1] if @_ > 1;
	return $_[0]{'mode'};
}

sub user_id {
	my $self = shift;
	if ( @_ > 1 ) {
		# passing in an array
		$$self{'user_id'} = [@_];
	} elsif ( @_ == 1 ) {
		if ( ref $_[0] eq 'ARRAY' ) {
		$$self{'user_id'} = $_[0];
		} else {
		$$self{'user_id'} = [ $_[0] ];
		} # end if
	} # end if
	if ( ! $$self{'user_id'} ) {
		$$self{'user_id'} = [];
	} 
	return $$self{'user_id'};
}

sub usergroup_id {
	my $self = shift;
	if ( @_ > 1 ) {
		# passing in an array
		$$self{'usergroup_id'} = [@_];
	} elsif ( @_ == 1 ) {
		if ( ref $_[0] eq 'ARRAY' ) {
		$$self{'usergroup_id'} = $_[0];
		} else {
		$$self{'usergroup_id'} = [ $_[0] ];
		} # end if
	} # end if
	return $$self{'usergroup_id'} ? $$self{'usergroup_id'} : [];
}

sub relationship_type_id {
	my $self = shift;
	if ( @_ > 1 ) {
		# passing in an array
		$$self{'relationship_type_id'} = [@_];
	} elsif ( @_ == 1 ) {
		if ( ref $_[0] eq 'ARRAY' ) {
		$$self{'relationship_type_id'} = $_[0];
		} else {
		$$self{'relationship_type_id'} = [ $_[0] ];
		} # end if
	} # end if
	return $$self{'relationship_type_id'} ? $$self{'relationship_type_id'} : [];
}
1;
__END__
