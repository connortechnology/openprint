use strict;
use openprint ();
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
			$$self{'user_id'} = @{$_[0]} ? $_[0] : undef;
		} else {
			$$self{'user_id'} = $_[0] ? [ $_[0] ] : undef;
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
			$$self{'usergroup_id'} = @{$_[0]} ? $_[0] : undef;
		} else {
			$$self{'usergroup_id'} = $_[0] ? [ $_[0] ] : undef;
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
			$$self{'relationship_type_id'} = @{$_[0]} ? $_[0] : undef;
		} else {
			$$self{'relationship_type_id'} = $_[0] ? [ $_[0] ] : undef;
		} # end if
	} # end if
	return $$self{'relationship_type_id'} ? $$self{'relationship_type_id'} : [];
}

sub can_view {
	return 1 if $openprint::session{'user_type'} eq 'A';
	if ( $_[0]{'mode'} eq 'public' ) {
		return 1;
	} elsif ( $_[0]{'mode'} eq 'logged_in' ) {
		return 1 if $openprint::session{'user_id'};
	} elsif ( $_[0]{'mode'} eq 'specific' ) {
		if ( @{$_[0]->usergroup_id()} ) {
			my @Groups = openprint::UserGroup->find('user_id any'=>$openprint::session{'user_id'} );
			return 1 if sets::intersection( ( map { $_->id() } @Groups ), @{$_[0]->usergroup_id()} );
		} # end if
		if ( @{$_[0]->relationship_type_id()} ) {
			my @Relationships = (
					openprint::User_Relationship->find('user_id1'=>$openprint::session{'user_id'},'user_id2'=>$_[0]->Object()->created_by()),
					openprint::User_Relationship->find('user_id2'=>$openprint::session{'user_id'},'user_id1'=>$_[0]->Object()->created_by()),
					);
			my @type_ids = map { $_->type_id() } @Relationships;

			return 1 if sets::intersection( @{$_[0]->relationship_type_id()}, @type_ids );
		} # end if
		if ( $_[0]->user_id() and sets::isin( $openprint::session{'user_id'}, $_[0]->user_id() ) ) {
			return 1;
		} # end if
	} elsif ( $_[0]{'mode'} eq 'onlyyou' ) {
		return 1 if $_[0]->Object()->created_by() == $openprint::session{'user_id'};
	} else {
		$openprint::log->warn("Unknown value for privacy mode: ".$_[0]{'mode'} );
	} # end if
	return 0;
} # end sub can_view
1;
__END__
