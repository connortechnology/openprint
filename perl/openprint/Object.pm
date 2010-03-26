package openprint::Object;

use strict;
use openprint ();
use vars qw( $log $dbh %variable %session $AUTOLOAD %cache %fields %defaults %transforms $no_cache );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;

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
$log->debug("Multi-key Obejct @keys" );
		@$self{@keys} = @$id{@keys};
		$self->load( $data );
	} else {
		if ( $id and $openprint::Object::cache{$parent} and $openprint::Object::cache{$parent}{$id} ) {
			return $openprint::Object::cache{$parent}{$id};
		} # end if


		$$self{'log'} = $openprint::log;
		$$self{'dbh'} = $openprint::dbh;
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
	my @identified_by = eval '@'.$type.'::identified_by';

	if ( ! $data ) {
		if ( @identified_by ) {
$log->debug("Loading multiple-key row: " . 'SELECT * FROM ' . $table . ' WHERE ' . join(' AND ', map { $fields{$_} . '=' . $$self{$_} } @identified_by ) );
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
if ( $data ) {
foreach my $k ( keys %$data ) {
$log->debug("Object::save $k => $$data{$k}");
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

	my $type = ref $self;
	my $table = eval '$'.$type.'::table';
	my $serial = eval '$'.$type.'::serial';
	my %fields = eval '%'.$type.'::fields';

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$fields{$k}} = $$self{$k} if defined $fields{$k};
	} # end foreach
	delete $sql{'created_on'};
	$sql{'updated_by'} = $session{'user_id'} if exists $fields{'updated_by'};
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
	return;
} # end sub save


sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self);
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
	my @requested_fields = @_;

	my $type = ref $self;
	my %fields = eval ('%'.$type.'::fields');
	foreach my $field ( @requested_fields ) {
		if ( ! defined $fields{$field} ) {
			$log->warn( "$type: Invalid field requested: ($field)." );
		} # end if
	} # end foreach

	return @$self{@requested_fields};
} # end sub get

sub set {
	my ( $self, $params ) = @_;
	my @set_fields = ();

	my $type = ref $self;
	my %fields = eval ('%'.$type.'::fields');

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

			my %defaults = eval('%'.$type.'::defaults');

			if ( ( (! defined $$self{$field}) or ( $$self{$field} eq '' ) ) and exists $defaults{$field} ) {
				$openprint::log->debug("Setting default ($field) ($$self{$field}) ($defaults{$field}) ") if $debug;
				$$self{$field} = $defaults{$field};
			} # end if
		} # end if
	} # end foreach
	return @set_fields;
} # end sub set

sub copy {
	my $self = shift;

	my $type = ref $self;
	my %fields = eval ('%'.$type.'::fields');

	my $New = new $type;
	@$New{keys %fields} = @$self{keys %fields};
	delete $$New{'id'};
	return $New;
} # end sub copy

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
	return;
} # end sub delete

sub undelete {
    my ( $self ) = @_;
    my $type = ref $self;
    my $table = eval '$'.$type.'::table';
	sql::update( undef, undef, $table, ['id=?', $$self{id}], 'deleted', 0 );
	$$self{'deleted'}=0;
	return;
} # end sub delete

sub Creator {
	require openprint::User;
	return new openprint::User( $_[0]{'created_by'} );
} # end sub Creator

1;
__END__
