package openprint::Object;

use strict;
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
	my $d = eval '$'.$type.'::dbh';
	$d = $dbh if ! $d;

	if ( ! $data ) {
		if ( @identified_by ) {
#$log->debug("Loading multiple-key row: " . 'SELECT * FROM ' . $table . ' WHERE ' . join(' AND ', map { $fields{$_} . '=' . $$self{$_} } @identified_by ) );
			$data = $d->selectrow_hashref( 'SELECT * FROM ' . $table . ' WHERE ' . join(' AND ', map { $fields{$_} . '=?' } @identified_by ), {}, @$self{@identified_by} );
		} else {
			$data = $d->selectrow_hashref( q{SELECT * FROM } . $table . " WHERE $fields{id}=?", {}, $$self{'id'} );
		} # end if
		if ( ! $data ) {
			$log->error( 'Failure to load ' . $type . " $$self{id}: Reason: " . $d->errstr ) if $d->errstr;
		} # end if
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load

sub save {
	my ( $self, $data ) = @_;
	my $type = ref $self;
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
	$sql{'updated_by'} = $session{'user_id'} if exists $fields{'updated_by'};
	$sql{'updated_on'} = 'NOW()' if exists $fields{'updated_on'};
	if ( $debug ) {
		foreach my $k ( keys %sql ) {
			$openprint::log->debug("Saving $k => $sql{$k}");
		} # end foreach
	} # end if
	my @identified_by = eval '@'.$type.'::identified_by';
	my $ac = sql::start_transaction( $dbh );
	if ( @identified_by ) {
		my $insert = 0;
		my %serial = eval '%'.$type.'::serial';
		if ( ! %serial ) {
			# No serial columns defined, which means that we will do saving by delete/insert instead of insert/update
			my $where = join(' AND ', map { $fields{$_}.'=?' } @identified_by );
			sql::execute( undef, undef, 'DELETE FROM ' . $table. ' WHERE ' . $where, @$self{@identified_by} );  
			$insert = 1;
		} else {
			foreach my $id ( @identified_by ) {
				next if ! $serial{$id};
				($$self{$id}) = ($sql{$fields{$id}}) = sql::execute( undef, undef, q{SELECT nextval('} . $serial{$id} . q{')} );
				$insert = 1;
			} # end foreach
		} # end if
		if ( $insert ) {
			if ( my $error = sql::insert( undef, undef, $table, \%sql ) ) {
				$dbh->rollback();
				sql::end_transaction( $dbh, $ac );
				return $error;
			} # end if
		} else {
			my $where = join(' AND ', map { $fields{$_}.'=?' } @identified_by );
			if ( my $error = sql::update( undef, undef, $table, [$where, @$self{@identified_by}], \%sql ) ) {
				$dbh->rollback();
				sql::end_transaction( $dbh, $ac );
				return $error;
			} # end if
		} # end if
	} else {
		if ( ! $$self{'id'} ) {
			my $serial = eval '$'.$type.'::serial';
			if ( $serial ) {
				($$self{'id'}) = ($sql{$fields{'id'}}) = sql::execute( undef, undef, q{SELECT nextval('} . $serial . q{')} );
			} # end if
			if ( my $error = sql::insert( undef, undef, $table, \%sql ) ) {
				$dbh->rollback();
				sql::end_transaction( $dbh, $ac );
				return $error;
			} # end if
		} else {
			if ( my $error = sql::update( undef, undef, $table, [$fields{'id'}.'=?', $$self{id}], \%sql ) ) {
				$dbh->rollback();
				sql::end_transaction( $dbh, $ac );
				return $error;
			} # end if
		} # end if
	} # end if
	sql::end_transaction( $dbh, $ac );
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

			if ( ( ( ! defined $$self{$field} ) or ( $$self{$field} eq '' ) ) and exists $defaults{$field} ) {
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
	my @identified_by = eval '@'.$type.'::identified_by';
	@identified_by = ( 'id' ) if ! @identified_by;
	if ( ! $$self{$identified_by[0]} ) {
		$log->error("Called delete on object with no id of type $type");
		return;
	} # end if

	my $where = join(' AND ', map { $fields{$_}.'=?' } @identified_by );
	if ( exists $fields{'deleted'} ) {
		sql::update( undef, undef, $table, [$where, @$self{@identified_by}], 'deleted', 1 );
		return $dbh->errstr if $dbh->errstr;
		$$self{'deleted'}=1;
	} else {
		sql::execute( undef, undef, 'DELETE FROM '.$table.' WHERE '.$where, @$self{@identified_by} );
		return $dbh->errstr if $dbh->errstr;
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
	my $local_dbh = $params{'dbh'} ? $params{'dbh'} : $openprint::dbh;
	delete $params{'dbh'};

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
				if ( exists $params{$k.'_lc'} ) {
					$sql .= " AND lower($$f{$k}) = ?";
					push @values, lc $params{$k.'_lc'};
					delete $params{$k.'_lc'};
				} # end if
				if ( defined $params{$k.'_null'} ) {
					if ( $params{$k.'_null'} ) {
						$sql .= " AND $$f{$k} IS NULL";
					} else {
						$sql .= " AND $$f{$k} IS NOT NULL";
					} # end if
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
		$log->error("Unknown paramter in find: $k => $params{$k}");
	} # end foreach k

    if ( $fields{'deleted'} and ! exists $params{'deleted'} ) {
        $sql .= ' AND (deleted=? OR deleted IS NULL)';
        push @values, 0;
    } # end if

	$sql .= " OR $params{'or'}" if $params{'or'};
    $sql .= " ORDER BY $params{'order'}" if $params{'order'};
    $sql .= " LIMIT $params{'limit'}" if $params{'limit'};

    my $data = $local_dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
    if ( ! $data ) {
        $openprint::log->debug("Error loading $type ($sql) (@values) Reason: " . $local_dbh->errstr );
    } elsif ( ! @$data ) {
        $openprint::log->debug("No $type ($sql) (@values) " );
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
	my @Results = eval($type.'->find(%params);');
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
		return $self->{$name} = shift;
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
    return join(' ' , map { "$_ => $_[0]{$_}" } keys %fields );
}

1;
__END__
