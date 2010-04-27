package openprint::Object;

use strict;
use openprint ();
use vars qw( $log $dbh $AUTOLOAD %cache %fields %defaults %transforms $no_cache );

*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 0;
$no_cache = 0;

sub init_cache {
	$no_cache = 0;
	%cache = ();
} # end sub init_cache

sub debug {
	$log->debug("Dumping Object cache");
	foreach my $o ( keys %cache ) {
		foreach my $id ( keys %{$cache{$o}} ) {
			$log->debug( "$o : $id" );
		} # end foreach
	} # end foreach
} # end sub debug

sub new {
	my ( $parent, $id, $data ) = @_;

	my $self = {};
	bless $self, $parent;

	if ( ref $id eq 'HASH' ) {
		# First off, for now, don't cache figure that out later
		my @keys = keys %{$id};
		@$self{@keys} = @$id{@keys};
		$self->load( $data );
	} else {
		if ( $id and $openprint::Object::cache{$parent} and $openprint::Object::cache{$parent}{$id} ) {
			return $openprint::Object::cache{$parent}{$id};
		} # end if

		if ( ( $$self{'id'} = $id ) or $data ) {
			$self->load( $data );
		} # end if
		if ( ! $no_cache ) {
			if ( $$self{'id'} ) {
				$openprint::Object::cache{$parent}{$id} = $self;
			} # end if
		} # end if
	} # end if ref id
	return $self;
} # end sub new

sub load {
	my ( $self, $data ) = @_;
	my $type = ref $self;
	my $table = eval '$'.$type.'::table';
	my %fields = eval '%'.$type.'::fields';
	if ( ! $table ) {
		$log->error( 'NO table for type ' . $type );
		return;
	} # end if
	my @identified_by = eval '@'.$type.'::identified_by';

	if ( ! $data ) {
		if ( @identified_by ) {
			$data = $dbh->selectrow_hashref( 'SELECT * FROM ' . $table . ' WHERE ' . join(' AND ', map { $fields{$_} . '=?' } @identified_by ), {}, @$self{@identified_by} );
		} else {
			$data = $dbh->selectrow_hashref( q{SELECT * FROM } . $table . " WHERE $fields{id}=?", {}, $$self{'id'} );
		} # end if
		if ( ! $data ) {
			$log->error( 'Failure to load ' . $type . " $$self{id}: Reason: " . $dbh->errstr ) if $dbh->errstr;
		} # end if
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};

} # end sub load

sub save {
	my ( $self, $data ) = @_;
	my $type = ref $self;
if ( $data ) {
foreach my $k ( keys %$data ) {
$log->debug("$type ::save $k => $$data{$k}");
}
} else {
$log->debug("No data");
}
	$self->set( $data ? $data : {} );
#if ( $data ) {
#foreach my $k ( keys %$data ) {
#$log->debug("Object::save after set $k => $$data{$k} $$self{$k}");
#}
#} else {
#$log->debug("No data after set");
#}
#$debug = 0;

	my $table = eval '$'.$type.'::table';
	my $serial = eval '$'.$type.'::serial';
	my %fields = eval '%'.$type.'::fields';

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$fields{$k}} = $$self{$k} if defined $fields{$k};
	} # end foreach
	delete $sql{'created_on'};
	$sql{'updated_by'} = $openprint::session{'user_id'} if exists $fields{'updated_by'};
	$sql{'updated_on'} = 'NOW()' if exists $fields{'updated_on'};
	if ( $debug ) {
		foreach my $k ( keys %sql ) {
			$openprint::log->debug("Saving $k => $sql{$k}");
		} # end foreach
	} # end if

	if ( ! $$self{'id'} ) {
		
		my $ac = sql::start_transaction( $dbh );
		($$self{'id'}) = ($sql{$fields{'id'}}) = sql::execute( undef, undef, q{SELECT nextval('} . $serial . q{')} );
		if ( my $error = sql::insert( undef, undef, $table, \%sql ) ) {
			$dbh->rollback();
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
		sql::end_transaction( $dbh, $ac );
	} else {
		if ( my $error = sql::update( undef, undef, $table, [$fields{'id'}.'=?', $$self{id}], \%sql ) ) {
			return $error;
		} # end if
	} # end if
	$self->load();
	delete $openprint::Object::cache{$type}{$$self{id}};
	eval 'if ( %'.$type.'::find_cache ) { %'.$type.'::find_cache = (); }';
	return;
} # end sub save


sub AUTOLOAD {
	my $self = shift;
	#my $type = ref($self);
	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	if ( @_ ) {
		return $self->{$name} = shift;
	} else {
		return $self->{$name};
	} # end if
} # end sub AUTOLOAD

sub get {
    my $self = shift;
	my @results;
	foreach ( @_ ) {
		push @results, $self->$_();
	} # end foreach

    return @results;
} # end sub get

sub set {
	my ( $self, $params ) = @_;
	my @set_fields = ();

	my $type = ref $self;
	my %fields = eval ('%'.$type.'::fields');
	if ( ! %fields ) {
$openprint::log->warn('Object::set called on an object with no fields');
	} # end if

	foreach my $field ( keys %fields ) {
$openprint::log->debug("field: $field, param: ".$$params{$field}) if $debug;
		if ( exists $$params{$field} ) {
			if ( ( ! defined $$self{$field} ) or ($$self{$field} ne $params->{$field}) ) {
# Only make changes to fields that have changed
				$$self{$field} = $$params{$field} if defined $fields{$field};
				eval "\$self->$field( \$\$params{\$field} );";
				push @set_fields, $fields{$field}, $$params{$field};	#mark for sql updating
			} # end if
		} # end if

		if ( defined $fields{$field} ) {
			my @transforms = eval('@{$'.$type.'::transforms{$field}}');
			$openprint::log->debug("Transforms: @transforms") if $debug;

			foreach my $transform ( @transforms ) {
				eval '$$self{$field} =~ ' . $transform;
			} # end foreach

			my %defaults = eval('%'.$type . '::defaults');

			if ( ( (! defined $$self{$field}) or ( $$self{$field} eq '' ) ) and exists $defaults{$field} ) {
				$openprint::log->debug("Setting default ($field) ($$self{$field}) ($defaults{$field}) ") if $debug;
				$$self{$field} = $defaults{$field};
			} else {
	#$openprint::log->debug("Not Setting default ($field) ($$self{$field}) ($defaults{$field}) ");
			} # end if
		} # end if
	} # end foreach
	return @set_fields;
} # end sub set

sub copy {
	my $self = shift;

	my $type = ref $self;
	my $new = new $type;
	my %fields = eval ('%'.$type.'::fields');
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{id};
	#$$new{'name'} = 'Copy of ' . $$new{'name'} if $fields{'name'};

	return $new;
} # end sub copy

sub clone {
	my $self = shift;
	my $new = new ref $self;
	@$new{keys %$self} = @$self{keys %$self};
	return $new;
} # end sub clone

sub delete {
    my ( $self ) = @_;
    my $type = ref $self;
    my $table = eval '$'.$type.'::table';
	my %fields = eval '%'.$type.'::fields';
	if ( exists $fields{'deleted'} ) {
		sql::update( undef, undef, $table, ['id=?', $$self{id}], 'deleted', 1 );
		return $dbh->errstr if $dbh->errstr;
		$$self{'deleted'}=1;
	} else {
		sql::execute( undef, undef, 'DELETE FROM '.$table.' WHERE id=?', $$self{'id'} );
		return $dbh->errstr if $dbh->errstr;
		delete $openprint::Object::cache{$type}{$$self{id}};
	} # end if
	eval 'if ( %'.$type.'::find_cache ) { %'.$type.'::find_cache = (); }';
	return;
} # end sub delete

sub undelete {
	my $self = shift;
    my $type = ref $self;
    my $table = eval '$'.$type.'::table';
	my %fields = eval '%'.$type.'::fields';
	sql::update( undef, undef, $table, [$fields{'id'}.'=?', $$self{'id'}], 'deleted', 0 );
	$$self{'deleted'} = 0;
	my %find_cache = eval '%'.$type.'::find_cache';
	%find_cache = () if %find_cache;
	delete $openprint::Object::cache{$type}{$$self{id}};
	return;
} # end sub undelete

sub destroy {
	my ( $self ) = @_;
	my $type = ref $self;
	my $table = eval '$'.$type.'::table';
	sql::execute( undef, undef, 'DELETE FROM '.$table.' WHERE id=?', $$self{'id'} );
	delete $openprint::Object::cache{$type}{$$self{id}};
	eval 'if ( %'.$type.'::find_cache ) { %'.$type.'::find_cache = (); }';
} # end sub destroy

sub Creator {
	require openprint::User;
	return new openprint::User( $_[0]{'created_by'} );
} # end sub Creator

1;
__END__
