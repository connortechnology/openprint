package openprint::Object;
use Time::HiRes qw{ gettimeofday tv_interval }; 

use strict;
use openprint ();
require sets;
use vars qw( $log $dbh $AUTOLOAD %cache %name_cache %fields %defaults %transforms $no_cache );

*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 0;
my $debug_all = 1;
$no_cache = 0;

sub init_cache {
	if ( @_ ) {
		if ( ! $name_cache{$_[0]} ) {
			my @items = $_[0]->find();
	$log->debug("init_cache of $_[0] # of items: " . @items );
			foreach ( @items ) {
				$name_cache{$_[0]}{$$_{$_->cache_field()}} = $_;
			} # end foreach
		} # end if
	} else {
		$no_cache = 0;
		%cache = ();
		%name_cache = ();
	} # end if
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
	} elsif ( ref $id eq 'ARRAY' and $data ) {
#$log->debug("Multi-key Obejct @$id @$data{@$id}" );
		@$self{@$id} = @$data{@$id};
		$self->load( $data );
		#$log->debug( $parent . ': ' .$self->to_string() );
	} else {
		if ( $id and $openprint::Object::cache{$parent} and $openprint::Object::cache{$parent}{$id} ) {
			if ( my $cache_field = $self->cache_field() ) {
				if ( ! ( exists $name_cache{$parent}{$$self{$cache_field}} and defined $name_cache{$parent}{$$self{$cache_field}} ) ) {
					$name_cache{$parent}{$$self{$cache_field}} = $self;
				} # end if
			} # end if
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
	my $fields = eval '\%'.$type.'::fields';
	if ( ! $data ) {
		my $table = eval '$'.$type.'::table';
		if ( ! $table ) {
			$log->error( 'NO table for type ' . $type );
			return;
		} # end if
		my @identified_by = eval '@'.$type.'::identified_by';
		my $d = eval '$'.$type.'::dbh';
		$d = $dbh if ! $d;

		if ( @identified_by ) {
			$data = $d->selectrow_hashref( 'SELECT * FROM ' . $table . ' WHERE ' . join(' AND ', map { $$fields{$_} . '=?' } @identified_by ), {}, @$self{@identified_by} );
		} else {
			$data = $d->selectrow_hashref( 'SELECT * FROM ' . $table . " WHERE $$fields{id}=?", {}, $$self{'id'} );
		} # end if
		if ( ! $data ) {
			$log->error( 'Failure to load ' . $type . " $$self{id}: Reason: " . $d->errstr ) if $d->errstr;
		} # end if
	} # end if
	@$self{keys %$fields} = @$data{@$fields{keys %$fields}};
	if ( my $cache_field = $self->cache_field() ) {
		if ( $$fields{$cache_field} and $$self{$cache_field} ) {
			$name_cache{$type}{$$self{$cache_field}} = $self;
		} # end if
	} # end if
} # end sub load

sub save {
	my ( $self, $data ) = @_;
	my $type = ref $self;
if ( $data ) {
#foreach my $k ( keys %$data ) {
#$log->debug("$type ::save $k => $$data{$k}");
#}
#} else {
#$log->debug("No data");
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
	my %fields = eval '%'.$type.'::fields';

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$fields{$k}} = $$self{$k} if defined $fields{$k};
	} # end foreach
	$sql{$fields{'updated_by'}} = $openprint::session{'user_id'} if exists $fields{'updated_by'};
	$sql{$fields{'updated_on'}} = 'NOW()' if exists $fields{'updated_on'};
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
			delete $sql{'created_on'};
			if ( my $error = sql::update( undef, undef, $table, [$fields{'id'}.'=?', $$self{id}], \%sql ) ) {
				$dbh->rollback();
				sql::end_transaction( $dbh, $ac );
				return $error;
			} # end if
		} # end if
	} # end if
	sql::end_transaction( $dbh, $ac );
	$self->load();
	delete $openprint::Object::cache{$type}{$$self{id}};
	eval 'if ( %'.$type.'::find_cache ) { %'.$type.'::find_cache = (); }';
	return;
} # end sub save

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

			my %defaults = eval('%'.$type.'::defaults');

			if ( ( ( ! exists $$self{$field} ) or ( $$self{$field} eq '' ) ) and exists $defaults{$field} ) {
				$openprint::log->debug("Setting default ($field) ($$self{$field}) ($defaults{$field}) ") if $debug;
				$$self{$field} = eval($defaults{$field});
				$openprint::log->error( "Eval error of object default $field Reason: " . $@ ) if $@;
				$openprint::log->debug("Setting default ($field) ($$self{$field}) ($defaults{$field}) ") if $debug;
			#} else {
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
	my %fields = eval '%'.$type.'::fields';
	sql::execute( undef, undef, 'DELETE FROM '.$table.' WHERE '.$fields{'id'}.'=?', $$self{'id'} );
	delete $openprint::Object::cache{$type}{$$self{id}};
	eval 'if ( %'.$type.'::find_cache ) { %'.$type.'::find_cache = (); }';
} # end sub destroy

sub Creator {
	require openprint::User;
	return new openprint::User( $_[0]{'created_by'} );
} # end sub Creator

sub find_operators {
	my ( $params, $k, $f ) = @_;
	my %results;

	if ( exists $$params{$k.'_like'} ) {
		push @{$results{'_like'}}, $f.'::text LIKE ?', $$params{$k.'_like'};
	} 
	if ( exists $$params{$k.'_ilike'} ) {
		push @{$results{'_ilike'}}, $f.'::text LIKE ?', $$params{$k.'_ilike'};
	} 
	if ( exists $$params{$k.'_start'} ) {
		push @{$results{'_start'}}, $f.' >= ?', $$params{$k.'_start'};
	} 
	if ( exists $$params{$k.'_end'} ) {
		push @{$results{'_end'}}, $f.' <= ?', $$params{$k.'_end'};
	} # end if
	if ( exists $$params{$k.' <'} ) {
		push @{$results{' <'}}, $f.' < ?', $$params{$k.' <'};
	} # end if
	if ( exists $$params{$k.' <='} ) {
		push @{$results{' <='}}, $f.' <= ?', $$params{$k.' <='};
	} # end if
	if ( exists $$params{$k.'_null_or_<='} ) {
		push @{$results{'_null_or_<='}}, "$f <= ? OR $f IS NULL", $$params{$k.'_null_or_<='};
	} # end if
	if ( exists $$params{$k.' >='} ) {
		push @{$results{' >='}}, $f.' >= ?', $$params{$k.' >='};
	} # end if
	if ( exists $$params{$k.'_null_or_>='} ) {
		push @{$results{'_null_or_>='}}, "( $f >= ? OR $f IS NULL )", $$params{$k.'_null_or_>='};
	} # end if
	if ( exists $$params{$k.' >'} ) {
		push @{$results{' >'}}, $f.' > ?', $$params{$k.' >'};
	} # end if
	if ( exists $$params{$k.' !='} ) {
		push @{$results{' !='}}, $f.' != ?', $$params{$k.' !='};
	} # end if
	if ( exists $$params{$k.'_in'} ) {
		push @{$results{'_in'}}, "? IN $f", $$params{$k.'_in'};
	} # end if
	if ( exists $$params{$k.'_lc'} ) {
		push @{$results{'_lc'}}, "lower($f) = ?", $$params{$k.'_lc'};
	} # end if
	if ( exists $$params{$k.'_any'} ) {
		push @{$results{'_any'}}, "? = ANY($f)", $$params{$k.'_any'};
	} # end if
	if ( defined $$params{$k.'_null'} ) {
		if ( $$params{$k.'_null'} ) {
			push @{$results{'_null'}}, "$f IS NULL";
		} else {
			push @{$results{'_null'}}, "$f IS NOT NULL";
		} # end if
	} # end if
	return \%results;
} # end sub
sub find {

	my $type = shift;
	my $table = eval '$'.$type.'::table';
	my %fields = eval '%'.$type.'::fields';
	my $cache_field = eval $type.'->cache_field()';

	my $debug = eval '$'.$type.'::debug';
	$debug = $debug_all if ! $debug;
	my $starttime = [gettimeofday] if $debug;

	my %params = @_;
	my @where;
	my $sql = 'SELECT';
	$sql .= ' DISTINCT' if $params{'distinct'};
	delete $params{'distinct'};
	$sql .= ' * FROM '.$table;
	my @values;
	my $local_dbh = $params{'dbh'} ? $params{'dbh'} : $openprint::dbh;
	return () if ! $local_dbh;
	delete $params{'dbh'};

	if ( $cache_field and $params{$cache_field} and ( ( 1 == keys %params ) or ( 2 == keys %params and exists $params{'limit'} ) ) ) {
		if ( exists $name_cache{$type} and exists $name_cache{$type}{$params{$cache_field}} ) {
			if ( $name_cache{$type}{$params{$cache_field}} ) {
#$openprint::log->debug("returning " . $name_cache{$type}{$params{$cache_field}} . " for $type $cache_field $params{$cache_field}");
				return $name_cache{$type}{$params{$cache_field}} 
			} else {
#$openprint::log->debug("returning nothing for $type $cache_field $params{$cache_field}");
				return ();
			} # end if
		} else {
#$openprint::log->debug("Undefing $type $cache_field $params{$cache_field}");
			$name_cache{$type}{$params{$cache_field}} = undef;
		} # end if
	} # end if

	foreach ( 'find_fields', 'fields' ) {
		my $f = eval '\%'.$type.'::'.$_;
		next if ! $f;

		foreach my $k ( keys %params ) {
			next if sets::isin( $k,[ 'order','limit','or' ] );
			next if ! $$f{$k};

			# This allows mainly for find_fields to reference multiple values, like in Project, value
			foreach my $field ( ref $$f{$k} eq 'ARRAY' ? @{$$f{$k}} : $$f{$k} ) {
				if ( ref $params{$k} eq 'ARRAY' ) {
					push @where, "$field IN (".join(',', map {'?'} @{$params{$k}} ) . ')';
					push @values, @{$params{$k}};
				} elsif ( ! defined $params{$k} ) {
					push @where, "$field IS NULL";
				} else {
					push @where, "$field=?";
					push @values, $params{$k};
				} # end if
			} # end foreach field
			delete $params{$k};
		} # end foreach k
		last if ! %params;

		foreach my $k ( keys %$f ) {
			if ( ref $$f{$k} eq 'ARRAY' ) {
				my @w;
				my @d;

				foreach my $field ( @{$$f{$k}} ) {
$openprint::log->debug("find: $field");
					my $results = find_operators( \%params, $k, $field );
					foreach my $operator ( keys %$results ) {
						push @w, shift @{$$results{$operator}};
						push @d, $k.$operator;
						push @values, @{$$results{$operator}};
					} # end foreach
				} # end foreach field
				foreach ( @d ) { delete $params{$_}; };
				push @where, '(' . join(' OR ', @w ) . ')' if @w;
			} else {
				my $results = find_operators( \%params, $k, $$f{$k} );
				foreach my $operator ( keys %$results ) {
					delete $params{$k.$operator};
					push @where, shift @{$$results{$operator}};
					push @values, @{$$results{$operator}};
				} # end foraech
			} # end if
		} # end foreach k in fields
		last if ! %params;
	} # end foreach set of fields

	# Check for Object references
	if ( %params ) {
		foreach my $k ( keys %params ) {
			next if sets::isin( ref $params{$k}, [ '', 'SCALAR','ARRAY','HASH' ] );
			my $f = (lc $k).'_id';
			if ( exists $fields{$f} ) {
				if ( $params{$k}->id() ) {
					push @where, "$fields{$f} = ?";
	#$openprint::log->debug("$params{$k}" . ref $params{$k});
					push @values, $params{$k}->id();
				} else {
					push @where, "$fields{$f} IS NULL";
				} # en dif
				delete $params{$k};
			} # end if
		} # end foreach
	} # end if

	if ( $fields{'deleted'} and ! exists $params{'deleted'} ) {
		push @where, '(deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if

	$sql .= ' WHERE ' . join(' AND ', @where ) if @where;
	if ( $params{'or'} ) {
		$sql .= ' WHERE' if ! @where;
		$sql .= " OR $params{'or'}";
		delete $params{'or'};
	} # end if
	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
		delete $params{'order'};
	} # end if
	if ( exists $params{'limit'} ) {
		$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
		delete $params{'limit'};
	} # end if
	foreach my $k ( keys %params ) {
		$log->error("Extra parameters in $type ::find $k => $params{$k}");
	} # end foreach
	
#$openprint::log->debug( 'find prepare: ' . sprintf('%.4f', tv_interval($starttime)*1000) ." useconds") if $debug;
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug('Error ' . $openprint::dbh->errstr() . " loading $type ($sql) (@values) " );
		return ();
	#} elsif ( ( ! @$data ) and $debug ) {
		#$openprint::log->debug("No $type ($sql) (@values) " );
	} elsif ( $debug ) {
		$openprint::log->debug("Loading $debug $type ($sql) (@values) # of results:" . @$data . ' in ' . sprintf('%.4f', tv_interval($starttime)*1000) ." useconds" );
	} # end if
	if ( $fields{'id'} ) {
		return map { $type->new( $_->{$fields{'id'}}, $_ ) } @$data;
	} else {
		my @identified_by = eval '@'.$type.'::identified_by';
		if ( ! @identified_by ) {
			$openprint::log->error("Multi key object $type but no identified by");
		} # end if
		my @objs = map { $type->new( \@identified_by, $_ ) } @$data;
$openprint::log->debug("Objs: "  . scalar @objs );
		return @objs;
	} # end if
} # end sub find

sub find_one {
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
#$openprint::log->debug("Autoload $self $type $name $field $$fields{$field} ($$self{$field}) " );
		if ( $fields ) {
			my $field = (lc $name) . '_id';
			if ( exists $$fields{$field} ) {
				if ( eval '\%openprint::'.$name.'::fields' ) {
					return new("openprint::$name", $$self{$field});
				} # end if
			} # end if
		} # end if
#$openprint::log->debug("NO Autoload $type $name $field $$fields{$field}" );
		return $$self{$name};
	} # end if
} # end sub AUTOLOAD
sub to_string {
	my $type = ref($_[0]);
	my $fields = eval '\%'.$type.'::fields';
    return join(' ' , map { $_ . ' => '.$_[0]{$_} } keys %$fields );
}

1;
__END__
