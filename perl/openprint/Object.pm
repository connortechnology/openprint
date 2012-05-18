use strict;
require openprint::Object_Asset;
package openprint::Object;

use openprint ();
require sets;
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
#n$log->debug("Multi-key Obejct @keys" );
		@$self{@keys} = @$id{@keys};
		$self->load( $data );
	} elsif ( ref $id eq 'ARRAY' and $data ) {
#$log->debug("Multi-key Obejct @$id @$data{@$id}" );
		@$self{@$id} = @$data{@$id};
		$self->load( $data );
	} else {
		if ( $id and (!$data) ) {
			if ( $openprint::Object::cache{$parent} and $openprint::Object::cache{$parent}{$id} ) {
				return $openprint::Object::cache{$parent}{$id};
			} else {
				$log->debug("Not loading from cache $id $parent ");
			} # end if
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
    no strict 'refs';
    my $fields = \%{$type.'::fields'};
    my $debug = ${$type.'::debug'};

	my @identified_by = eval '@'.$type.'::identified_by';
	my $d = eval '$'.$type.'::dbh';
	$d = $dbh if ! $d;

	if ( ! $data ) {
		if ( @identified_by ) {
			$log->debug('SELECT * FROM ' . $table . ' WHERE ' . join(' AND ', map { $$fields{$_} . '=' . $$self{$_} } @identified_by ) ) if $debug;
			$data = $d->selectrow_hashref( 'SELECT * FROM ' . $table . ' WHERE ' . join(' AND ', map { $$fields{$_} . '=?' } @identified_by ), {}, @$self{@identified_by} );
			$log->debug("Got $type: " . join(',', map { $_ . '=>' . $$data{$_} } keys %$data ) ) if $debug;
		} else {
			$data = $d->selectrow_hashref( q{SELECT * FROM } . $table . " WHERE $$fields{id}=?", {}, $$self{'id'} );
		} # end if
		if ( ! $data ) {
			$log->error( 'Failure to load ' . $type . " $$self{id}: Reason: " . $d->errstr ) if $d->errstr;
		} # end if
	} # end if
	@$self{keys %$fields} = @$data{values %$fields};
} # end sub load

sub save {
	my ( $self, $data ) = @_;
	my $type = ref $self;
	my $local_dbh = eval '$'.$type.'::dbh';
	$local_dbh = $openprint::dbh if ! $local_dbh;
#if ( $data ) {
#foreach my $k ( keys %$data ) {
#$log->debug("$type ::save $k => $$data{$k}");
#}
#} else {
#$log->debug("No data");
#}
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
	my %fields = eval '%'.$type.'::fields';

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$fields{$k}} = $$self{$k} if defined $fields{$k};
	} # end foreach
	delete $sql{'created_on'};
	$sql{'created_by'} = $session{'user_id'} if exists $fields{'created_by'} and ! $sql{'created_by'};
	$sql{'updated_by'} = $session{'user_id'} if exists $fields{'updated_by'};
	$sql{'updated_on'} = 'NOW()' if exists $fields{'updated_on'};
	if ( $debug ) {
		foreach my $k ( keys %sql ) {
			$openprint::log->debug("Saving $k => $sql{$k}");
		} # end foreach
	} # end if
	my @identified_by = eval '@'.$type.'::identified_by';
	my $ac = sql::start_transaction( $local_dbh );
	if ( @identified_by ) {
		my $insert = 0;
		my %serial = eval '%'.$type.'::serial';
		if ( ! %serial ) {
			# No serial columns defined, which means that we will do saving by delete/insert instead of insert/update
			my $where = join(' AND ', map { $fields{$_}.'=?' } @identified_by );
			sql::execute( undef, $local_dbh, 'DELETE FROM ' . $table. ' WHERE ' . $where, @$self{@identified_by} );  
			$insert = 1;
		} else {
			foreach my $id ( @identified_by ) {
				next if ! $serial{$id};
				($$self{$id}) = ($sql{$fields{$id}}) = sql::execute( undef, $local_dbh, q{SELECT nextval('} . $serial{$id} . q{')} );
				$insert = 1;
			} # end foreach
		} # end if
		if ( $insert ) {
			if ( my $error = sql::insert( undef, $local_dbh, $table, \%sql ) ) {
				$local_dbh->rollback();
				sql::end_transaction( $local_dbh, $ac );
				return $error;
			} # end if
		} else {
			my $where = join(' AND ', map { $fields{$_}.'=?' } @identified_by );
			if ( my $error = sql::update( undef, $local_dbh, $table, [$where, @$self{@identified_by}], \%sql ) ) {
				$local_dbh->rollback();
				sql::end_transaction( $local_dbh, $ac );
				return $error;
			} # end if
		} # end if
	} else {
		if ( ! $$self{'id'} ) {
			my $serial = eval '$'.$type.'::serial';
			if ( $serial ) {
				($$self{'id'}) = ($sql{$fields{'id'}}) = sql::execute( undef, $local_dbh, q{SELECT nextval('} . $serial . q{')} );
			} # end if
			if ( my $error = sql::insert( undef, $local_dbh, $table, \%sql ) ) {
				$local_dbh->rollback();
				sql::end_transaction( $local_dbh, $ac );
				return $error;
			} # end if
		} else {
			if ( my $error = sql::update( undef, $local_dbh, $table, [$fields{'id'}.'=?', $$self{id}], \%sql ) ) {
				$local_dbh->rollback();
				sql::end_transaction( $local_dbh, $ac );
				return $error;
			} # end if
		} # end if
	} # end if
	sql::end_transaction( $local_dbh, $ac );
	$self->load();
	return;
} # end sub save


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
	my %defaults = eval('%'.$type.'::defaults');

	foreach my $field ( keys %fields ) {
		if ( exists $$params{$field} ) {
$openprint::log->debug("field: $field, $$self{$field} =? param: ".$$params{$field}) if $debug;
			if ( ( ! defined $$self{$field} ) or ($$self{$field} ne $params->{$field}) ) {
# Only make changes to fields that have changed
				if ( defined $fields{$field} ) {
					$$self{$field} = $$params{$field};
					push @set_fields, $fields{$field}, $$params{$field};	#mark for sql updating
				} # end if
$openprint::log->debug("Running $field with $$params{$field}") if $debug;
				if ( my $func = $self->can( $field ) ) {
					$func->( $self, $$params{$field} );
				} # end if
			} # end if
		} # end if

		if ( defined $fields{$field} ) {
			my @transforms = eval('@{$'.$type.'::transforms{$field}}');
			$openprint::log->debug("Transforms: @transforms") if $debug;

			foreach my $transform ( @transforms ) {
				eval '$$self{$field} =~ ' . $transform;
			} # end foreach

			if ( ( ( ! defined $$self{$field} ) or ( $$self{$field} eq '' ) ) and exists $defaults{$field} ) {
				$openprint::log->debug("Setting default ($field) ($$self{$field}) ($defaults{$field}) ") if $debug;
				$$self{$field} = $defaults{$field};
				$self->$field( $defaults{$field} ) if $$self{$field} != $defaults{$field};;
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
	my @identified_by = eval '@'.$type.'::identified_by';
	@identified_by = ( 'id' ) if ! @identified_by;
	if ( ! $$self{$identified_by[0]} ) {
		$log->error("Called delete on object with no id of type $type");
		return;
	} # end if

	my $local_dbh = eval '$'.$type.'::dbh';
	$local_dbh = $openprint::dbh if ! $local_dbh;

	my $where = join(' AND ', map { $fields{$_}.'=?' } @identified_by );
	if ( exists $fields{'deleted'} ) {
		sql::update( undef, $local_dbh, $table, [$where, @$self{@identified_by}], 'deleted', 1 );
		return $local_dbh->errstr if $local_dbh->errstr;
		$$self{'deleted'}=1;
	} else {
		sql::execute( undef, $local_dbh, 'DELETE FROM '.$table.' WHERE '.$where, @$self{@identified_by} );
		return $local_dbh->errstr if $local_dbh->errstr;
		delete $openprint::Object::cache{$type}{join('-',@$self{@identified_by})};
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
} # end sub undelete

sub Creator {
	require openprint::User;
	return new openprint::User( $_[0]{'created_by'} );
} # end sub Creator
sub find {
	my $type = shift;
    my $table = eval '$'.$type.'::table';
	my %fields = eval '%'.$type.'::fields';

	my $debug = eval '$'.$type.'::debug';

	my %params = @_;
	my $sql = 'SELECT ';
	$sql .= 'DISTINCT ' if $params{'distinct'};
	delete $params{'distinct'};
	$sql .= '* FROM '.$table.' WHERE 1>0';
	my @values;
	my $local_dbh = eval '$'.$type.'::dbh';
	$local_dbh = $openprint::dbh if ! $local_dbh;
	if ( $params{'dbh'} ) {
		$local_dbh = $params{'dbh'};
		delete $params{'dbh'};
	} # end if
    if ( $fields{'deleted'} and ! exists $params{'deleted'} ) {
        $sql .= ' AND (deleted=? OR deleted IS NULL)';
        push @values, 0;
    } # end if

    if ( %params ) {
		foreach ( 'find_fields', 'fields' ) {
			my $f = eval '\%'.$type.'::'.$_;
			next if ! $f;

			foreach my $k ( keys %params ) {
				next if sets::isin( $k,[ 'order','limit','or' ] );
				next if ! $$f{$k};
				if ( ref $params{$k} eq 'ARRAY' ) {
					$sql .= " AND $$f{$k} IN (".join(',', map {'?'} @{$params{$k}} ) . ')';
					push @values, @{$params{$k}};
				} elsif ( ! defined $params{$k} ) {
					$sql .= " AND $$f{$k} IS NULL";
				} else {
					$sql .= " AND $$f{$k}=?";
					push @values, $params{$k};
				} # end if
				delete $params{$k};
			} # end foreach k

			foreach my $k ( keys %$f ) {
				if ( exists $params{$k.'_like'} ) {
					$sql .= " AND $$f{$k} LIKE ?";
					push @values, $params{$k.'_like'};
					delete $params{$k.'_like'};
				}
				if ( exists $params{$k.' like'} ) {
					$sql .= " AND $$f{$k} LIKE ?";
					push @values, $params{$k.' like'};
					delete $params{$k.' like'};
				}
				if ( exists $params{$k.'_ilike'} ) {
					$sql .= " AND $$f{$k} ILIKE ?";
					push @values, $params{$k.'_ilike'};
					delete $params{$k.'_ilike'};
				}
				if ( exists $params{$k.'_start'} ) {
					$sql .= " AND $$f{$k} >= ?";
					push @values, $params{$k.'_start'};
					delete $params{$k.'_start'};
				}
				if ( exists $params{$k.'_end'} ) {
					$sql .= " AND $$f{$k} <= ?";
					push @values, $params{$k.'_end'};
					delete $params{$k.'_end'};
				} # end if
				if ( exists $params{$k.'_<'} ) {
					$sql .= " AND $$f{$k} < ?";
					push @values, $params{$k.'_<'};
					delete $params{$k.'_<'};
				} # end if
				if ( exists $params{$k.'_<='} ) {
					$sql .= " AND $$f{$k} <= ?";
					push @values, $params{$k.'_<='};
					delete $params{$k.'_<='};
				} # end if
				if ( exists $params{$k.' <='} ) {
					$sql .= " AND $$f{$k} <= ?";
					push @values, $params{$k.' <='};
					delete $params{$k.' <='};
				} # end if
				if ( exists $params{$k.' <<='} ) {
					$sql .= " AND $$f{$k} <<= ?";
					push @values, $params{$k.' <<='};
					delete $params{$k.' <<='};
				} # end if
				if ( exists $params{$k.'_null_or_<='} ) {
					$sql .= " AND ( $$f{$k} <= ? OR $$f{$k} IS NULL )";
					push @values, $params{$k.'_null_or_<='};
					delete $params{$k.'_null_or_<='};
				} # end if
				if ( exists $params{$k.'_>='} ) {
					$sql .= " AND $$f{$k} >= ?";
					push @values, $params{$k.'_>='};
					delete $params{$k.'_>='};
				} # end if
				if ( exists $params{$k.' >='} ) {
					$sql .= " AND $$f{$k} >= ?";
					push @values, $params{$k.' >='};
					delete $params{$k.' >='};
				} # end if
				if ( exists $params{$k.'_null_or_>='} ) {
					$sql .= " AND ( $$f{$k} >= ? OR $$f{$k} IS NULL )";
					push @values, $params{$k.'_null_or_>='};
					delete $params{$k.'_null_or_>='};
				} # end if
				if ( exists $params{$k.'_>'} ) {
					$sql .= " AND $$f{$k} > ?";
					push @values, $params{$k.'_>'};
					delete $params{$k.'_>'};
				} # end if
				if ( exists $params{$k.'_in'} ) {
					$sql .= " AND ? IN $$f{$k}";
					push @values, $params{$k.'_in'};
					delete $params{$k.'_in'};
				} elsif ( exists $params{$k.' in'} ) {
					if ( ref $params{$k.' in'} eq 'ARRAY' ) {
						$sql .= ' AND ' . $$f{$k}. ' IN ('.join(',', map {'?'} @{$params{$k.' in'}} ) . ')';
						push @values, @{$params{$k.' in'}};
					} else {
						$sql .= " AND ? IN $$f{$k}";
						push @values, $params{$k.' in'};
					} # end if
					delete $params{$k.' in'};
				} # end if
				if ( exists $params{$k.' !='} ) {
					$sql .= " AND $$f{$k} != ?";
					push @values, $params{$k.' !='};
					delete $params{$k.' !='};
				} # end if
				if ( exists $params{$k.'_any'} ) {
					$sql .= " AND ? = ANY($$f{$k})";
					push @values, $params{$k.'_any'};
					delete $params{$k.'_any'};
				} # end if
				if ( exists $params{$k.' any'} ) {
					$sql .= " AND ? = ANY($$f{$k})";
					push @values, $params{$k.' any'};
					delete $params{$k.' any'};
				} # end if
				if ( exists $params{$k.'_lc'} ) {
					$sql .= " AND lower($$f{$k}) = ?";
					push @values, lc $params{$k.'_lc'};
					delete $params{$k.'_lc'};
				} elsif ( exists $params{$k.' lc'} ) {
					$sql .= " AND lower($$f{$k}) = ?";
					push @values, lc $params{$k.' lc'};
					delete $params{$k.' lc'};
				} # end if
				if ( exists $params{$k.'_null'} ) {
					if ( $params{$k.'_null'} ) {
						$sql .= " AND $$f{$k} IS NULL";
					} else {
						$sql .= " AND $$f{$k} IS NOT NULL";
					} # end if
					delete $params{$k.'_null'};
				} # end if
				if ( exists $params{$k.' is null'} ) {
					if ( $params{$k.' is null'} ) {
						$sql .= " AND $$f{$k} IS NULL";
					} else {
						$sql .= " AND $$f{$k} IS NOT NULL";
					} # end if
					delete $params{$k.' is null'};
				} # end if
			} # end foreach key
		} # end foreach fileds, find_fields
    } # end if

    # Check for Object references
    if ( %params ) {
        foreach my $k ( keys %params ) {
            next if sets::isin( ref $params{$k}, [ '', 'SCALAR','ARRAY','HASH' ] );
            my $f = (lc $k).'_id';
            if ( exists $fields{$f} ) {
                if ( $params{$k}->id() ) {
                $sql .= " AND $fields{$f} = ?";
#$openprint::log->debug("$params{$k}" . ref $params{$k});
                push @values, $params{$k}->id();
                } else {
                    $sql .= " AND $fields{$f} IS NULL";
                } # en dif
                delete $params{$k};
            } # end if
        } # end foreach
    } # end if

	foreach my $k ( keys %params ) {
		next if $k eq 'order';
		next if $k eq 'limit';
		$log->error("Unknown paramter in $type find: $k => $params{$k}");
	} # end foreach k


	$sql .= " OR $params{'or'}" if $params{'or'};
    $sql .= " ORDER BY $params{'order'}" if $params{'order'};
    $sql .= " LIMIT $params{'limit'}" if $params{'limit'};

    my $data = $local_dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
    if ( ! $data ) {
        $openprint::log->debug("Error loading $type ($sql) (@values) Reason: " . $local_dbh->errstr );
    } elsif ( ! @$data ) {
        $openprint::log->debug("No $type ($sql) (@values) " ) if $debug;
    } elsif ( $debug ) {
        $openprint::log->debug("Loading $type ($sql) (@values) # of results:" . @$data );
    } # end if
	if ( $fields{'id'} ) {
		return map { $type->new( $_->{$fields{'id'}}, $_ ) } @$data;
	} else {
		my @identified_by = eval '@'.$type.'::identified_by';
		return map { $type->new( \@identified_by, $_ ) } @$data;
	} # end if
		
} # end sub find

sub find_one {
#$openprint::log->debug("find_one @_ ");
	my $type = shift;
	my %params = @_;
	$params{'limit'}=1;
	my @Results = $type->find(%params);
	return $Results[0] if @Results;
} # end sub find_one

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self);
	my $name = $AUTOLOAD;
#if ( $self eq 'supplier' ) {
#$openprint::log->debug("Autoload $type $name");
#}
	$name =~ s/.*://;
	if ( @_ ) {
#$openprint::log->debug("Autoload $type $name $_[0]");
		return $self->{$name} = $_[0];
	} else {
		my $fields = eval '\%'.$type.'::fields';
		if ( $fields and exists $$fields{lc $name . '_id'} ) {
			if ( eval '\%openprint::'.$name.'::fields' ) {
				return new("openprint::$name", $$self{lc $name . '_id'});
			} # end if
		} # end if
		return $self->{$name};
	} # end if
} # end sub AUTOLOAD
sub to_string {
	my $type = ref($_[0]);
	my $fields = eval '\%'.$type.'::fields';
    return $type . ': '. join(' ' , map { "$_ => $_[0]{$_}" } keys %$fields );
}

sub dropdown {
    my $type = shift;
$log->debug("dropdown $type");
    return [ map { $_->id(), $_->name() } $type->find(@_) ];
} # end sub dropdown

sub transform {
	
	my $type = ref $_[0];
	$type = $_[0] if ! $type;
	my $fields = eval '\%'.$type.'::fields';

	if ( defined $$fields{$_[1]} ) {
		my @transforms = eval('@{$'.$type.'::transforms{$_[1]}}');
		$openprint::log->debug("Transforms: @transforms") if $debug;

		foreach my $transform ( @transforms ) {
			eval '$_[2] =~ ' . $transform;
		} # end foreach
	} else {
		$openprint::log->error("$_[1] not in fields for $type");
	} # end if
	return $_[2];

} # end sub transform

sub Assets {
	return () if ! $_[0]{'id'};
	my ( $self, %param ) = @_;
	$param{'object_id'} = $_[0]{'id'};
	$param{'order'}	= 'asset_id' if ! $param{'order'};
	$param{'object_type'} = ref $_[0];
	my @Assets = openprint::Object_Asset->find(%param);	
$openprint::log->debug("# of Assets: " . scalar @Assets );
	return @Assets;
} # end sub Assets

1;
__END__
