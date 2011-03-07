use strict;
require openprint::Event_Category;
package openprint::Event;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %transforms %defaults );
$table = 'events';
$serial = 'events_id_seq';

%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'created_by'	=>	'created_by',
	'starting_on'	=>	'starting_on',
	'ending_on'	=>	'ending_on',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'deleted'		=>	'deleted',
	'location_id'	=>	'location_id',
	'info'			=>	'info',
	'time_associated'	=>	'time_associated',
	'category_id'	=>	'category_id',
	'category'		=>	undef,
	'asset_id'		=>	'asset_id',
	# Photo album for the event, created on first photo upload
	'album_id'		=>	'album_id', 
);

%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'starting_on'	=>	undef,
	'ending_on'		=>	undef,
	'location_id'	=>	undef,
	'asset_id'		=>	undef,
	'time_associated'	=> 0,
	'created_by'		=> q`$openprint::session{'user_id'}`,
	'deleted'			=> 0,
);

sub category {
	if ( @_ > 1 ) {
		my $Category = openprint::Event_Category->find_one('name_lc'=>lc$_[1]);
		if ( ! $Category ) {
			$Category = new openprint::Event_Category();
			$Category->save({'name'=>$_[1]})
		} # end if	
		$_[0]{'category_id'} = $Category->id();
		return $Category->name();
	} # end if
	return new openprint::Event_Category( $_[0]{'category_id'} )->name();
} # end sub category
sub Category {
	return new openprint::Event_Category( $_[0]{'category_id'} );
} # end sub Category

sub where {
	return join(',', map { $_->name() } $_[0]->Location(), $_[0]->Location()->Parents() );
} # end sub where

sub Asset {
	return new openprint::Asset( $_[0]{'asset_id'} );
} # end sub Asset

sub location {
	if ( @_ > 1 ) {
		my $Location = openprint::Location->find_one('name_lc'=>lc $_[1]);
		if ( ! $Location ) {
			$Location = new openprint::Location();
			$Location->save({'name'=>$_[1]});
		} # end if
		$_[0]{'location_id'} = $Location->id();
		return $Location->name();
	} # end if
	return new openprint::Location( $_[0]{'location_id'} )->name();
} # end if

sub Photos {
	if ( ! $_[0]{'album_id'} ) {
		return ();
	} # end if
	return $_[0]->Album()->Photos( );
} # end sub Photos

sub Album {
	return new openprint::Photo_Album( $_[0]{'album_id'} );
} # end sub Album

1;
__END__
