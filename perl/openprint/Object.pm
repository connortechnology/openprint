use strict;
package openprint::Object;
use Time::HiRes qw{ gettimeofday tv_interval }; 
use Carp qw( cluck );
require Lingua::EN::Inflect;

use openprint ();
require sets;
require openprint::Opinion;
require openprint::Opinion_Type;
require openprint::Comment;
require openprint::View;
require openprint::Privacy;
require openprint::Object_Type;
require openprint::Opinion_Availability;
require openprint::Object_Asset;
use vars qw( $log $dbh $AUTOLOAD %cache %name_cache %fields %defaults %transforms $no_cache %session %config );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
*config = \%openprint::config;

my $debug = 0;
my $debug_all = 0;
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

	my $ref = ref $id;
	if ( ! $ref ) {
		if ( $id and (!$data) and $openprint::Object::cache{$config{'db_name'}}{$parent} and $openprint::Object::cache{$config{'db_name'}}{$parent}{$id} ) {
#$log->debug("Loading from cache $parent $id");
			# If the object is cached
			return $openprint::Object::cache{$config{'db_name'}}{$parent}{$id};
		} # end if
#$log->debug("Not Loading from cache $parent $id") if $id and ! $data;
		my $self = {};
		bless $self, $parent;

		if ( ( $$self{'id'} = $id ) or $data ) {
#$log->debug("loading $parent $id") if $debug;
			$self->load( $data );
			#$log->debug("loading $parent $id" . $self->to_string()) if $$self{'name'} eq 'Run Speed';
		} # end if
		if ( ! $no_cache ) {
			if ( $$self{'id'} ) {
				$openprint::Object::cache{$config{'db_name'}}{$parent}{$id} = $self;
			} # end if
		} # end if
		return $self;
	} elsif ( ref $id eq 'HASH' ) {
		#my $self = {};
		my @keys = keys %{$id};
		bless $id, $parent;
# First off, for now, don't cache figure that out later
		#@$id{@keys} = @$id{@keys};
#$log->debug("New by hash @keys : " . $self->to_string() );
#$log->debug("New by hash @keys : " . $id->to_string() );
		$id->load( $data );
#$log->debug("New by hash @keys : " . $id->to_string() );
		return $id;
	} elsif ( ref $id eq 'ARRAY' and $data ) {
		my $self = {};
		bless $self, $parent;
#$log->debug("Multi-key Obejct @$id @$data{@$id}" );
		@$self{@$id} = @$data{@$id};
		$self->load( $data );
#$log->debug( $parent . ': ' .$self->to_string() );
		return $self;
	} # end if ref id
#$log->error("test");
} # end sub new

sub load {
	my ( $self, $data ) = @_;
	my $type = ref $self;
	no strict 'refs';
	my $fields = \%{$type.'::fields'};
	my $debug = ${$type.'::debug'};
	$debug = $debug_all if ! $debug;
	my $starttime = [gettimeofday] if $debug;
	if ( ! $data ) {
#$log->debug("Object::load Loading from db $type");
		my $table = ${$type.'::table'};
		if ( ! $table ) {
			$log->error( 'NO table for type ' . $type );
			return;
		} # end if
		my @identified_by = @{$type.'::identified_by'};
		my $d = ${$type.'::dbh'};
		$d = $dbh if ! $d;

		if ( @identified_by ) {
			$log->debug('SELECT * FROM ' . $table . ' WHERE ' . join(' AND ', map { $$fields{$_} . '=' . $$self{$_} } @identified_by ) ) if $debug;
			$data = $d->selectrow_hashref( 'SELECT * FROM ' . $table . ' WHERE ' . join(' AND ', map { $$fields{$_} . '=?' } @identified_by ), {}, @$self{@identified_by} );
			$log->debug("Got $type: " . join(',', map { $_ . '=>' . $$data{$_} } keys %$data ) ) if $debug;
		} else {
			$data = $d->selectrow_hashref( 'SELECT * FROM ' . $table . " WHERE $$fields{id}=?", {}, $$self{'id'} );
		} # end if
		if ( ! $data ) {
			if ( $d->errstr ) {
				$log->error( 'Failure to load ' . $type . " $$self{id}: Reason: " . $d->errstr );
				Carp::cluck( 'Failure to load ' . $type . " $$self{id}: Reason: " . $d->errstr );
			} # end if
		} elsif ( $debug ) {
			#$log->debug("Got $type: " . join(',', map { $_ . '=>' . $$data{$_} } keys %$data ) . ' in ' . sprintf('%.4f', tv_interval($starttime)*1000) .' useconds' );
		} # end if
	} # end if
	@$self{keys %$fields} = @$data{values %$fields};
} # end sub load

sub save {
	my ( $self, $data, $force_insert ) = @_;

	my $type = ref $self;
	my $local_dbh = eval '$'.$type.'::dbh';
	$local_dbh = $openprint::dbh if ! $local_dbh;
	$self->set( $data ? $data : {} );
if ( $debug ) {
	if ( $data ) {
	foreach my $k ( keys %$data ) {
	$log->debug("Object::save after set $k => $$data{$k} $$self{$k}");
	}
	} else {
	$log->debug("No data after set");
	}
}
#$debug = 0;

	my $table = eval '$'.$type.'::table';
	my $fields = eval '\%'.$type.'::fields';
	my $debug = eval '$'.$type.'::debug';
	$debug = $debug_all if ! $debug;

	my %sql;
	foreach my $k ( keys %$fields ) {
		$sql{$$fields{$k}} = $$self{$k} if defined $$fields{$k};
	} # end foreach
	$sql{$$fields{'updated_by'}} = $openprint::session{'user_id'} if exists $$fields{'updated_by'};
	$sql{$$fields{'updated_on'}} = 'NOW()' if exists $$fields{'updated_on'};
	#if ( 0 or $debug or $debug_all ) {
		#foreach my $k ( keys %sql ) {
			#$log->debug("Saving $k => $sql{$k}");
		#} # end foreach
	#} # end if
	my @identified_by = eval '@'.$type.'::identified_by';
	my $ac = sql::start_transaction( $local_dbh );
	if ( @identified_by ) {
		my $insert = $force_insert;
		my %serial = eval '%'.$type.'::serial';
		if ( ! %serial ) {
$log->debug("No serial") if $debug;
			# No serial columns defined, which means that we will do saving by delete/insert instead of insert/update
			my $where = join(' AND ', map { $$fields{$_}.'=?' } @identified_by );
			if ( ! ( ( $_ = $local_dbh->prepare("DELETE FROM $table WHERE $where") ) and $_->execute( @$self{@identified_by} ) ) ) {
				$where =~ s/\?/\%s/g;
				$log->error("Error deleting: DELETE FROM $table WHERE " .  sprintf($where, map { defined $_ ? $_ : 'undef' } ( @$self{@identified_by}) ).'):' . $local_dbh->errstr);
				$local_dbh->rollback();
				sql::end_transaction( $local_dbh, $ac );
				return $local_dbh->errstr;
			} # end if
			$insert = 1;
		} else {
			foreach my $id ( @identified_by ) {
				next if ! $serial{$id};
				($$self{$id}) = ($sql{$$fields{$id}}) = sql::execute( undef, $local_dbh, q{SELECT nextval('} . $serial{$id} . q{')} );
				$insert = 1;
			} # end foreach
		} # end if
		if ( $insert ) {
			my @keys = keys %sql;
			my $command = "INSERT INTO $table (" . join(',', @keys ) . ') VALUES (' . join(',', map { '?' } @sql{@keys} ) . ')';
			if ( ! ( $_ = $local_dbh->prepare($command) and $_->execute( @sql{@keys} ) ) ) {
				my $error = $dbh->errstr;
				$command =~ s/\?/\%s/g;
				$log->error('SQL statement execution failed: ('.sprintf($command, , map { defined $_ ? $_ : 'undef' } ( @sql{@keys}) ).'):' . $local_dbh->errstr);
				$local_dbh->rollback();
				sql::end_transaction( $local_dbh, $ac );
				return $error;
			} # end if
			if ( $debug or $debug_all ) {
				$command =~ s/\?/\%s/g;
				$log->debug('SQL statement execution: ('.sprintf($command, , map { defined $_ ? $_ : 'undef' } ( @sql{@keys} ) ).'):' );
			} # end if
		} else {
			my @keys = keys %sql;
			my $command = "UPDATE $table SET " . join(',', map { $_ . ' = ?' } @keys ) . ' WHERE ' . join(' AND ', map { $_ . ' = ?' } @$fields{@identified_by} );
			if ( ! ( $_ = $local_dbh->prepare($command) and $_->execute( @sql{@keys,@identified_by} ) ) ) {
				my $error = $local_dbh->errstr;
				$command =~ s/\?/\%s/g;
				$log->error('SQL failed: ('.sprintf($command, , map { defined $_ ? $_ : 'undef' } ( @sql{@keys, @identified_by}) ).'):' . $local_dbh->errstr);
				$local_dbh->rollback();
				sql::end_transaction( $local_dbh, $ac );
				return $error;
			} # end if
			if ( $debug or $debug_all ) {
				$command =~ s/\?/\%s/g;
				$log->debug('SQL DEBUG: ('.sprintf($command, map { defined $_ ? $_ : 'undef' } ( @sql{@keys,@identified_by} ) ).'):' );
			} # end if
		} # end if
	} else { # not identified_by
		if ( ( ! $$self{'id'} ) or $force_insert ) {
			if ( ! $$self{'id'} ) {
				my $serial = eval '$'.$type.'::serial';
				if ( $serial ) {
					($$self{'id'}) = ($sql{$$fields{'id'}}) = sql::execute( undef, $local_dbh, q{SELECT nextval('} . $serial . q{')} );
				} # end if
			} # end if
			my @keys = keys %sql;
			my $command = "INSERT INTO $table (" . join(',', @keys ) . ') VALUES (' . join(',', map { '?' } @sql{@keys} ) . ')';
			if ( ! ( $_ = $local_dbh->prepare($command) and $_->execute( @sql{@keys} ) ) ) {
				$command =~ s/\?/\%s/g;
				my $error = $local_dbh->errstr;
				$log->error('SQL failed: ('.sprintf($command, map { defined $_ ? $_ : 'undef' } ( @sql{@keys}) ).'):' . $error);
				$local_dbh->rollback();
				sql::end_transaction( $local_dbh, $ac );
				return $error;
			} # end if
			if ( $debug or $debug_all ) {
				$command =~ s/\?/\%s/g;
				$log->debug('SQL DEBUG: ('.sprintf($command, map { defined $_ ? $_ : 'undef' } ( @sql{@keys} ) ).'):' );
			} # end if
		} else {
			delete $sql{'created_on'};
			my @keys = keys %sql;
			my $command = "UPDATE $table SET " . join(',', map { $_ . ' = ?' } @keys ) . " WHERE $$fields{id} = ?";
			if ( ! ( $_ = $local_dbh->prepare($command) and $_->execute( @sql{@keys}, $sql{$$fields{'id'}} ) ) ) {
				my $error = $local_dbh->errstr;
				$command =~ s/\?/\%s/g;
				$log->error('SQL failed: ('.sprintf($command, map { defined $_ ? $_ : 'undef' } ( @sql{@keys}, $$fields{'id'} ) ).'):' . $error) if $log;
				$local_dbh->rollback();
				sql::end_transaction( $local_dbh, $ac );
				return $error;
			} # end if
			if ( $debug or $debug_all ) {
				$command =~ s/\?/\%s/g;
				$log->debug('SQL DEBUG: ('.sprintf($command, map { defined $_ ? ( ref $_ eq 'ARRAY' ? join(',',@{$_}) : $_ ) : 'undef' } ( @sql{@keys}, $$self{'id'} ) ).'):' );
			} # end if
		} # end if
	} # end if
	sql::end_transaction( $local_dbh, $ac );
	$self->load();
#$log->debug("Got here");
	delete $openprint::Object::cache{$config{'db_name'}}{$type}{$$self{id}};
#$log->debug("after delete");
	eval 'if ( %'.$type.'::find_cache ) { %'.$type.'::find_cache = (); }';
#$log->debug("after clear cache");
	return;
} # end sub save

sub get {
	my $self = shift;
	return map { $self->$_() } @_;
} # end sub get

sub set {
	my ( $self, $params ) = @_;
	my @set_fields = ();

	my $type = ref $self;
	my $fields = eval ('\%'.$type.'::fields');
	if ( ! $fields ) {
$log->warn('Object::set called on an object with no fields');
	} # end if
	my %defaults = eval('%'.$type.'::defaults');

	foreach my $field ( keys %$fields ) {
$log->debug("field: $field, param: ".$$params{$field}) if $debug;
		if ( exists $$params{$field} ) {
$openprint::log->debug("field: $field, $$self{$field} =? param: ".$$params{$field}) if $debug;
			if ( ( ! defined $$self{$field} ) or ($$self{$field} ne $params->{$field}) ) {
# Only make changes to fields that have changed
				if ( defined $$fields{$field} ) {
					$$self{$field} = $$params{$field} if defined $$fields{$field};
					push @set_fields, $$fields{$field}, $$params{$field};	#mark for sql updating
				} # end if
$openprint::log->debug("Running $field with $$params{$field}") if $debug;
				if ( my $func = $self->can( $field ) ) {
					$func->( $self, $$params{$field} );
				} # end if
			} # end if
		} # end if

		if ( defined $$fields{$field} ) {
			if ( $$self{$field} ) {
				my @transforms = eval('@{$'.$type.'::transforms{$field}}');
				$log->debug("Transforms: @transforms") if $debug;

				foreach my $transform ( @transforms ) {
					eval '$$self{$field} =~ ' . $transform;
				} # end foreach
			} # end if $$self{field}

			if ( ( ( ! exists $$self{$field} ) or ( $$self{$field} eq '' ) ) and exists $defaults{$field} ) {
				$log->debug("Setting default ($field) ($$self{$field}) ($defaults{$field}) ") if $debug;
				$$self{$field} = eval($defaults{$field});
				$log->error( "Eval error of object default $field Reason: " . $@ ) if $@;
				$log->debug("Setting default ($field) ($$self{$field}) ($defaults{$field}) ") if $debug;
			} # end if
		} # end if
	} # end foreach
	return @set_fields;
} # end sub set

sub copy {
	no strict 'refs';
	my $type = ref $_[0];
	my $new = new $type;
	my $fields = \%{$type.'::fields'};
	@$new{keys %$fields} = @{$_[0]}{keys %$fields};
	delete $$new{id};

	return $new;
} # end sub copy

sub clone {
	my $new = new ref $_[0];
	my @keys = keys %{$_[0]};
	@$new{@keys} = @{$_[0]}{@keys};
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
		$log->error("Called delete on object with no id of type $type : " . $self->to_string());
		return "Object::delete: No id in object: " . $self->to_string();
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
		delete $openprint::Object::cache{$config{'db_name'}}{$type}{join('-',@$self{@identified_by})};
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
	delete $openprint::Object::cache{$config{'db_name'}}{$type}{$$self{id}};
	return;
} # end sub undelete

sub destroy {
	my ( $self ) = @_;
	my $type = ref $self;
	my $table = eval '$'.$type.'::table';
	my $fields = eval '\%'.$type.'::fields';
	sql::execute( undef, undef, 'DELETE FROM '.$table.' WHERE '.$$fields{'id'}.'=?', $$self{'id'} );
	delete $openprint::Object::cache{$config{'db_name'}}{$type}{$$self{id}};
	eval 'if ( %'.$type.'::find_cache ) { %'.$type.'::find_cache = (); }';
} # end sub destroy

sub Creator {
	require openprint::User;
	return new openprint::User( $_[0]{'created_by'} );
} # end sub Creator

my @sql_functions = (
	'NOW()','CURRENT_TIME',
);

sub find_operators {
	my ( $params, $k, $f ) = @_;
	my %results;

	if ( exists $$params{$k.' ='} ) {
			push @{$results{' ='}}, $f.' = ?', $$params{$k.' ='};
	} # end if
	if ( exists $$params{$k.'_like'} ) {
		push @{$results{'_like'}}, $f.'::text LIKE ?', $$params{$k.'_like'};
	} 
	if ( exists $$params{$k.' like'} ) {
		push @{$results{' like'}}, $f.'::text LIKE ?', $$params{$k.' like'};
	} 
	if ( exists $$params{$k.' ilike'} ) {
		push @{$results{' ilike'}}, $f.'::text ILIKE ?', $$params{$k.' ilike'};
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
		push @{$results{'_null_or_<='}}, "( $f <= ? OR $f IS NULL )", $$params{$k.'_null_or_<='};
	} # end if
	if ( exists $$params{$k.' >='} ) {
		push @{$results{' >='}}, $f.' >= ?', $$params{$k.' >='};
	} # end if
	if ( exists $$params{$k.'_null_or_>='} ) {
		push @{$results{'_null_or_>='}}, "( $f >= ? OR $f IS NULL )", $$params{$k.'_null_or_>='};
	} # end if
	if ( exists $$params{$k.'_null_or_>'} ) {
		push @{$results{'_null_or_>'}}, "( $f > ? OR $f IS NULL )", $$params{$k.'_null_or_>'};
	} # end if
	if ( exists $$params{$k.'_null_or_<'} ) {
		push @{$results{'_null_or_<'}}, "( $f < ? OR $f IS NULL )", $$params{$k.'_null_or_<'};
	} # end if
	if ( exists $$params{$k.' is null or ='} ) {
		push @{$results{' is null or ='}}, "( $f = ? OR $f IS NULL )", $$params{$k.' is null or ='};
	} # end if
	if ( exists $$params{$k.' exists'} ) {
		push @{$results{' exists'}}, ( $$params{$k.' exists'} ? ' EXISTS' : ' NOT EXISTS ' ) . $f;
	} # end if
	if ( exists $$params{$k.' >'} ) {
		push @{$results{' >'}}, $f.' > ?', $$params{$k.' >'};
	} # end if
	if ( exists $$params{$k.' !='} ) {
		push @{$results{' !='}}, $f.' != ?', $$params{$k.' !='};
	} # end if
	if ( exists $$params{$k.' <<='} ) {
		push @{$results{' <<='}}, "$f <<= ?", $$params{$k.' <<='};
	} # end if
	if ( exists $$params{$k.' &&'} ) {
		if ( ref $$params{$k.' &&'} eq 'ARRAY' ) {
			if ( @{$$params{$k.' &&'}} ) {
				push @{$results{' &&'}}, $f . ' && ARRAY['. join(',', map { '?' } @{$$params{$k.' &&'}} ).']', @{$$params{$k.' <@'}};
			} # end if
		} else {
			push @{$results{' &&'}}, "$f && ?", $$params{$k.' &&'};
		} # end if
	} # end if
	if ( exists $$params{$k.' <@'} ) {
		if ( ref $$params{$k.' <@'} eq 'ARRAY' ) {
			if ( @{$$params{$k.' <@'}} ) {
				push @{$results{' <@'}}, $f . ' <@ ARRAY['. join(',', map { '?' } @{$$params{$k.' <@'}} ).']', @{$$params{$k.' <@'}};
			} # end if
		} else {
			push @{$results{' <@'}}, "$f <@ ?", $$params{$k.' <@'};
		} # end if
	} # end if
	if ( exists $$params{$k.' @>'} ) {
		if ( ref $$params{$k.' @>'} eq 'ARRAY' ) {
			if ( @{$$params{$k.' @>'}} ) {
				push @{$results{' @>'}}, $f . ' @> ARRAY['. join(',', map { '?' } @{$$params{$k.' @>'}} ).']', @{$$params{$k.' @>'}};
			} # end if
		} else {
			push @{$results{' @>'}}, "$f @> ?", $$params{$k.' @>'};
		} # end if
	} # end if
	if ( exists $$params{$k.' in'} ) {
		if ( ref $$params{$k.' in'} eq 'ARRAY' ) {
			if ( @{$$params{$k.' in'}} ) {
				push @{$results{' in'}}, $f.' IN (' . join(',', map { '?' } @{$$params{$k.' in'}} ).')', @{$$params{$k.' in'}};
			} # end if
		} elsif ( $$params{$k.' in'} ) {
			push @{$results{' in'}}, $f.' IN (?)', $$params{$k.' in'};
		} # end if
	} # end if
	if ( exists $$params{$k.' not in'} ) {
		if ( ref $$params{$k.' not in'} eq 'ARRAY' ) {
			if ( @{$$params{$k.' not in'}} ) {
				push @{$results{' not in'}}, $f.' NOT IN (' . join(',', map { '?' } @{$$params{$k.' not in'}} ).')', @{$$params{$k.' not in'}};
			} else {
					push @{$results{' not in'}}, ();
			} # end if
		} elsif ( $$params{$k.' not in'} ) {
			push @{$results{' not in'}}, $f.' != ?', $$params{$k.' not in'};
		} else {
			push @{$results{' not in'}}, ();
		} # end if
	} # end if
	if ( exists $$params{$k.'_lc'} ) {
		push @{$results{'_lc'}}, "lower($f) = ?", $$params{$k.'_lc'};
	} # end if
	if ( exists $$params{$k.' lc'} ) {
		push @{$results{' lc'}}, "lower($f) = ?", $$params{$k.' lc'};
	} # end if
	if ( exists $$params{$k.' uc'} ) {
		push @{$results{' uc'}}, "upper($f) = ?", $$params{$k.' uc'};
	} # end if
	if ( exists $$params{$k.' any'} ) {
		if ( ref $$params{$k.' any'} eq 'ARRAY' ) {
			push @{$results{' any'}}, '(' . join(',', map { '?' } @{$$params{$k.' any'}} ).") = ANY($f)", @{$$params{$k.' any'}};
		} else {
			push @{$results{' any'}}, "? = ANY($f)", $$params{$k.' any'};
		} # end if
	} # end if
	if ( exists $$params{$k.' is null'} ) {
		if ( $$params{$k.' is null'} ) {
			push @{$results{' is null'}}, "$f IS NULL";
		} else {
			push @{$results{' is null'}}, "$f IS NOT NULL";
		} # end if
	} # end if

	return \%results;
} # end sub

sub find {
	no strict 'refs';
	my $type = shift;
	my $table = ${$type.'::table'};

	my $debug = ${$type.'::debug'};
	$debug = $debug_all if ! $debug;
	my $starttime = [gettimeofday] if $debug;

	my $params;
	if ( @_ == 1 ) {
		$params = $_[0];
	} else {
		$params = { @_ };
	} # end if
	if ( $$params{'table'} ) {
		$table = $$params{'table'};
		delete $$params{'table'};
	} # end if

	my @where;
	my $sql = 'SELECT';
	$sql .= ' DISTINCT' if $$params{'distinct'};
	delete $$params{'distinct'};
	if ( $$params{'columns'} ) {
		$sql .= ' ' . $$params{'columns'};
		delete $$params{'columns'};
	} else {
		$sql .= ' *';
	} # end if
	$sql .= ' FROM '.$table;
	my @values;
	my $local_dbh = ${$type.'::dbh'};
	$local_dbh = $openprint::dbh if ! $local_dbh;
	if ( $$params{'dbh'} ) {
		$local_dbh = $$params{'dbh'};
		delete $$params{'dbh'};
	} # end if
	return () if ! $local_dbh;
	delete $$params{'dbh'};

	my $cache_field = ${$type.'::cache_field'};
	if ( $cache_field and $$params{$cache_field} and ( ( 1 == keys %$params ) or ( 2 == keys %$params and exists $$params{'limit'} ) ) ) {

#$log->debug("have cache field $cache_field flr $$params{$cache_field}");
		if ( exists $name_cache{$type} and exists $name_cache{$type}{$$params{$cache_field}} ) {
#$log->debug("There is an object in the cache");
			if ( $name_cache{$type}{$$params{$cache_field}} ) {
#$log->debug("returning " . $name_cache{$type}{$$params{$cache_field}} . " for $type $cache_field $$params{$cache_field}");
				return $name_cache{$type}{$$params{$cache_field}} 
			} else {
#$log->debug("returning nothing for $type $cache_field $$params{$cache_field}");
				return ();
			} # end if
		} else {
#$log->debug("Undefing $type $cache_field $params{$cache_field}");
			$name_cache{$type}{$$params{$cache_field}} = undef;
		} # end if
	#} else {
		#$log->debug("Not doing caching using $cache_field with params $$params{$cache_field} ");
	} # end if

	# no operators, just which fields are being searched on. Mostly just useful for detetion of the deleted field.
	my @used_fields;

	my @param_keys = sets::exclude( [ 'order','limit','offset','or' ], [ keys %$params ] );

	foreach ( 'find_fields', 'fields' ) {
		my $f = \%{$type.'::'.$_};
		next if ! $f;

		foreach my $k ( @param_keys ) {
			next if ! $$f{$k};

			# This allows mainly for find_fields to reference multiple values, opinion in Project, value
			foreach my $field ( ref $$f{$k} eq 'ARRAY' ? @{$$f{$k}} : $$f{$k} ) {
				if ( ref $$params{$k} eq 'ARRAY' ) {
					if ( @{$$params{$k}} ) {
						push @where, "$field IN (".join(',', map {'?'} @{$$params{$k}} ) . ')';
						push @values, @{$$params{$k}};
					} # end if
				} elsif ( ref $$params{$k} eq 'HASH' ) {
					foreach my $p_k ( keys %{$$params{$k}} ) {
						my $v = $$params{$k}{$p_k};
						if ( ref $v eq 'ARRAY' ) {
							push @where, "$field IN (".join(',', map {'?'} @{$v} ) . ')';
							push @values, $p_k, @{$v};
						} else {
							push @where, "$field=?";
							push @values, $p_k, $v;
						} # end if
					} # end foreach p_k
				} elsif ( ! defined $$params{$k} ) {
					push @where, "$field IS NULL";
				} else {
					push @where, "$field=?";
					push @values, $$params{$k};
				} # end if
			} # end foreach field
			delete $$params{$k};
			push @used_fields, $k;
		} # end foreach k
		last if ! %$params;

		foreach my $k ( keys %$f ) {
			if ( ref $$f{$k} eq 'ARRAY' ) {
				my @w;
				my @d;

				foreach my $field ( @{$$f{$k}} ) {
					my $results = find_operators( $params, $k, $field );
					foreach my $operator ( keys %$results ) {
						if ( @{$$results{$operator}} ) {
							push @w, shift @{$$results{$operator}};
							push @d, $k.$operator;
							push @values, @{$$results{$operator}};
						} # end if
						push @used_fields, $k;
					} # end foreach
				} # end foreach field
				foreach ( @d ) { delete $$params{$_}; };
				push @where, '(' . join(' OR ', @w ) . ')' if @w;
			} else {
				my $results = find_operators( $params, $k, $$f{$k} );
				foreach my $operator ( keys %$results ) {
					delete $$params{$k.$operator};
					if ( @{$$results{$operator}} ) {
						push @where, shift @{$$results{$operator}};
						push @values, @{$$results{$operator}};
					} # end if
					push @used_fields, $k;
				} # end foraech
			} # end if
		} # end foreach k in fields
		last if ! %$params;
	} # end foreach set of fields

#$log->debug("Where: (@where)");

	my $fields = \%{$type.'::fields'};
	# Check for Object references
	if ( %$params ) {
		foreach my $k ( keys %$params ) {
			next if sets::isin( ref $$params{$k}, [ '', 'SCALAR','ARRAY','HASH' ] );
			my $f = (lc $k).'_id';
			if ( exists $$fields{$f} ) {
Carp::cluck("Use of deprecated Object ref in find");
				if ( $$params{$k}->id() ) {
					push @where, $$fields{$f}.' = ?';
					push @values, $$params{$k}->id();
				} else {
					push @where, "$$fields{$f} IS NULL";
				} # end if
				delete $$params{$k};
			} # end if
		} # end foreach
	} # end if
	if ( $$fields{'deleted'} and ! sets::isin( 'deleted', \@used_fields ) ) {
		push @where, '(deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if
	if ( $$params{'custom'} ) {
		push @where, shift @{$$params{'custom'}};
		push @values, @{$$params{'custom'}};
		delete $$params{'custom'};
	} # end if

	$sql .= ' WHERE ' . join(' AND ', @where ) if @where;
	if ( $$params{'or'} ) {
		$sql .= ' WHERE' if ! @where;
		$sql .= " OR $$params{'or'}";
		delete $$params{'or'};
	} # end if
	if ( $$params{'order'} ) {
		$sql .= " ORDER BY $$params{'order'}";
		delete $$params{'order'};
	} # end if
	if ( $$params{'group'} ) {
		$sql .= " GROUP BY $$params{'group'}";
		delete $$params{'group'};
	} # end if
	if ( exists $$params{'limit'} ) {
		$sql .= " LIMIT $$params{'limit'}" if $$params{'limit'};
		delete $$params{'limit'};
	} # end if
	if ( exists $$params{'offset'} ) {
		$sql .= " OFFSET $$params{'offset'}" if $$params{'offset'};
		delete $$params{'offset'};
	} # end if
	foreach my $k ( keys %$params ) {
		$log->error("Extra parameters in $type ::find $k => $$params{$k}");
		Carp::cluck("Extra parameters in $type ::find $k => $$params{$k}");
	} # end foreach
	
#$log->debug( 'find prepare: ' . sprintf('%.4f', tv_interval($starttime)*1000) ." useconds") if $debug;
	my $data = $local_dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug('Error ' . $local_dbh->errstr() . " loading $type ($sql) (@values) " );
		return ();
	#} elsif ( ( ! @$data ) and $debug ) {
		#$log->debug("No $type ($sql) (@values) " );
	} elsif ( $debug ) {
		$log->debug("Loading Debug:$debug $type ($sql) (@values) # of results:" . @$data . ' in ' . sprintf('%.4f', tv_interval($starttime)*1000) .' useconds' );
	} # end if
	if ( $$fields{'id'} ) {
		if ( $cache_field and 1 ) {
			my @results;
			foreach ( @$data ) {
				my $result = $type->new( $_->{$$fields{'id'}}, $_ );
				$name_cache{$type}{$$result{$$fields{$cache_field}}} = $result;
				push @results, $result;
			} # end foreach results
			return @results;
		} # end if
		return map { $type->new( $_->{$$fields{'id'}}, $_ ) } @$data;
	} else {
		my @identified_by = eval '@'.$type.'::identified_by';
		if ( ! @identified_by ) {
			$log->error("Multi key object $type but no identified by");
		} # end if
		return map { $type->new( \@identified_by, $_ ) } @$data;
#$log->debug("Objs: "  . scalar @objs );
		#return @objs;
	} # end if
} # end sub find

sub find_one {
	my $type = shift;
	 
	my $params;
	if ( @_ == 1 ) {
		$params = $_[0];
	} else {
		%{$params} = @_;
	} # end if
	$$params{'limit'}=1;
	my @Results = $type->find($params);
	return $Results[0] if @Results;
} # end sub find_one

sub AUTOLOAD {
	my ( $self, $newvalue ) = @_;
	my $type = ref($_[0]);
	my $name = $AUTOLOAD;
	$name =~ s/.*://;
	return if $name eq 'DESTROY';
	if ( @_ > 1 ) {
#$openprint::log->debug("Autoload $type $name $_[0] $_[1] $self $newvalue");
		return $_[0]{$name} = $_[1];
	} else {
		my $fields = eval '\%'.$type.'::fields';
		if ( $fields ) {
			# This looks to handle returning Objects
			if ( exists $$fields{$name} ) {

# NOT SURE WE SHOULD DO THIS
				#if ( ! defined $_[0]{$name} ) {
					#my $defaults = eval '\%'.$type.'::defaults';
					#if ( exists $$defaults{$name} ) {
						#return $$defaults{$name};
					#}
				#} # end if
				return $_[0]{$name};
			} else {
				my $field = (lc $name) . '_id';
				if ( exists $$fields{$field} ) {
					my $O = eval {
						require "openprint/$name.pm";
						return ('openprint::'.$name)->new( $_[0]{$field} );
					}; # end eval
					if ( $@ ){
						$log->error( "Eval error of Object::AUTOLOAD $type -> $name, Reason: " . $@ );
						return undef;
					} # end if
					return $O;
				} # end if
			} # end if
		} # end if has fields
	} # end if setting
	Carp::cluck( "Bad autoload $type $name " );
	return;
} # end sub AUTOLOAD

sub to_string {
	my $type = ref($_[0]);
	my $fields = eval '\%'.$type.'::fields';
    return $type . ': '. join(' ' , map { "$_ => $_[0]{$_}" } keys %$fields );
}

sub dropdown {
	my $self = shift;
	return [ map { $$_{'id'}, $_->name() } $self->find(@_) ];
} # end sub dropdown

sub sort_value {
	return $_[0]->name();
}

sub sort {
	my $type = shift;
	return sort { $$a{'name'} cmp $$b{'name'} } @_;
} # end sub sort

sub transform {
	my $type = ref $_[0];
	$type = $_[0] if ! $type;
	my $fields = eval '\%'.$type.'::fields';

	if ( defined $$fields{$_[1]} ) {
		my @transforms = eval('@{$'.$type.'::transforms{$_[1]}}');
		$openprint::log->debug("Transforms: @transforms") if $debug;

		foreach my $transform ( @transforms ) {
			eval '$_[2] =~ ' . $transform;
$openprint::log->debug("After $transform: $_[2]") if $debug;
		} # end foreach
	} else {
		$openprint::log->error("Object::transform $_[1] not in fields for $type");
	} # end if
	return $_[2];

} # end sub transform

sub opinions {
	my $type = ref $_[0];
	my $html;
	my @Opinions = openprint::Opinion->find('object_type'=> $type, 'object_id'=>$_[0]->id() );
	my %Opinions;
	foreach my $Opinion ( @Opinions ) {
		push @{$Opinions{$$Opinion{'opinion_type_id'}}}, $Opinion;
	} # end foreach

	if ( ! @Opinions ) {
		$html = 'No one has an opinion on this yet.';
		$html .= '  Be the first!' if $session{'user_id'};
	} else {
		foreach my $opinion_type_id ( keys %Opinions ) {
			my $Opinion_Type = new openprint::Opinion_Type( $opinion_type_id );
			if ( @{$Opinions{$opinion_type_id}} == 1 ) {
				if ( $Opinions{$opinion_type_id}[0]->user_id() == $session{'user_id'} ) {
					$html .= 'You ' . $Opinion_Type->name() . ' this.';
				} else {
					$html = '1 person ' . Lingua::EN::Inflect::PL( $Opinion_Type->name(), @{$Opinions{$opinion_type_id}} ) . ' this.';
				} # end if
			} else {
				$html .= int(@{$Opinions{$opinion_type_id}}/@Opinions) . '% of '  . @Opinions . ' people ' . new openprint::Opinion_Type( $opinion_type_id )->name() . ' this.<br/>';
			} # end if
		} # end foreach opinion
	} # end if
	$html .= $_[0]->opinion_button( ( $_[1] ? $_[1] : 'Opinions' ), '/includes/_opinions.html' ) if $session{'user_id'};
	return $html;
} # end sub opinions

sub opinion_button {
	my $type = ref $_[0];

	my %Opinions;
	foreach my $Opinion ( openprint::Opinion->find('object_type'=> $type, 'object_id'=>$_[0]{'id'}, 'user_id'=>$session{'user_id'} ) ) {
		push @{$Opinions{$$Opinion{opinion_type_id}}}, $Opinion;
	} # end foreach
	my $html;
	my $div = $_[1];
	my $url = @_ > 2 ? $_[2] : '/includes/_opinion_button.html';
	if ( ! $div ) {
		$div = 'opinion_button';
		$html = '<span id="opinion_button">';
	} # end if
	my @Types = openprint::Opinion_Availability->find('object_type'=>$type, 'object_id'=>$_[0]->id() );
	@Types = openprint::Opinion_Availability->find('object_type'=>$type ) if ! @Types;
	foreach my $Type ( @Types ) {
		# Only need 1 button becuse it's a toggle
		if ( $Opinions{$$Type{opinion_type_id}} ) {
			$html .= ssi::button( $Type->Opinion_Type()->name(), { onclick=>sprintf( q`new Ajax.Updater( '%s', '%s', { parameters: { object_type: '%s', object_id: %d, opinion_type_id: %d } } );`, $div, $url, $type, $_[0]{'id'}, $Type->opinion_type_id() ), text=>'Remove Opinion' } );
		} else {
			$html .= ssi::button( $Type->Opinion_Type()->name(), { onclick=>sprintf( q`new Ajax.Updater( '%s', '%s', { parameters: { object_type: '%s', object_id: %d, opinion_type_id: %d } } );`, $div, $url, $type, $_[0]{'id'}, $Type->opinion_type_id() ) } );
		} # end if
	} # end foreach
	if ( ! $_[1] ) {
		$html .= '</span>';
	} # end if
	return $html;
} # end sub opinion_button

sub toggle_Opinion {
	my $ac = sql::start_transaction(  $dbh );
	$dbh->do('LOCK TABLE opinions IN ROW EXCLUSIVE MODE');
	my $Opinion = $_[0]->Opinion( $_[1] );
	if ( $Opinion ) {
		$Opinion->delete();
		delete $_[0]{'Opinions'}{$_[1]};
	} else {
		$Opinion = new openprint::Opinion();
		$Opinion->save({'user_id'=>$session{'user_id'}, 'object_type'=>ref $_[0], 'object_id'=>$_[0]{'id'},'opinion_type_id'=>$_[1]});
	} # end if
	sql::end_transaction( $dbh, $ac );
} # end sub toggle_Opinion

#Param is opinion_type_id
# second param could be for setting it, so should be an Opinion Object
sub Opinion {
	if ( @_ > 2 ) {
		$_[0]{'Opinions'}{$_[1]} = $_[2];
	} # end if
	$_[0]{'Opinions'} = {} if ! $_[0]{'Opinions'};
	my $type = ref $_[0];
	if ( ! defined $_[0]{'Opinions'}{$_[1]} ) {
		$_[0]{'Opinions'}{$_[1]} = openprint::Opinion->find_one( 'user_id'=>$session{'user_id'}, 'object_type'=>$type, 'opinion_type_id'=>$_[1], 'object_id'=>$_[0]{'id'});
	} # end if
	return $_[0]{'Opinions'}{$_[1]};
} # end sub Opinion

sub Object_Type {
	if ( $_[0]{'object_type_id'} ) {
		$_[0]{'Object_Type'} = new openprint::Object_Type( $_[0]{'object_type_id'} );
	} else {
		$_[0]{'Object_Type'} = openprint::Object_Type->find_one('name'=>ref $_[0] );
		$_[0]{'Object_Type'} = new openprint::Object_Type() if ! $_[0]{'Object_Type'};
	} # end if
	return $_[0]{'Object_Type'};
} # end sub Object_Type

sub object_type {
	if ( @_ > 1 ) {
		my $Type = openprint::Object_Type->find_one('name'=> $_[1] );
		if ( ! $Type ) {
			$Type = new openprint::Object_Type();
			$Type->save({'name'=>$_[1], 'human'=>$_[1]});
		} # end if
		$_[0]{'object_type'} = $Type->name();
		$_[0]{'object_type_id'} = $Type->id();
	} # end if
	if ( ! $_[0]{'object_type'} ) {
		$_[0]{'object_type'} = new openprint::Object_Type( $_[0]{'object_type_id'} )->name();
	} # end if
	return $_[0]{'object_type'};
} # end sub object_type
sub Object {
	if ( @_ > 1 ) {
		$_[0]->object_type( ref $_[1] );
		$_[0]{'object_id'} = $_[1]{'id'};
	} # end if
	my $type =  $_[0]->object_type();
	if ( ! $type ) {
		$log->error("No type in Object::Object". $_[0]->to_string());
		return undef;
	} # end if
	$_ = $type->new( $_[0]{'object_id'} );
	$openprint::log->debug( "Returning object of type " . ref $_ );
	return $_;
} # end sub Object

sub date_format {
	return Date::Format::time2str( $config{'DateFormat'}, Date::Parse::str2time( $_[0]{$_[1]} ) );
} # end sub date_format 
sub datetime_format {
	return Date::Format::time2str( $config{'DateTimeFormat'}, Date::Parse::str2time( $_[0]{$_[1]} ) );
} # end sub datetime_format 

sub Views {
	if ( $_[1] ) {
		$_[1]{'object_id'} = $_[0]{'id'};
		$_[1]{'object_type'} = ref $_[0],
		$_[1]{'order'} = 'created_on' if ! $_[1]{'order'};
		return openprint::View->find($_[1]);
	} # end if

	if ( ! defined $_[0]{'Views'} ) {
		@{$_[0]{'Views'}} = openprint::View->find({'object_type'=>ref $_[0], 'object_id'=>$_[0]{'id'}, 'order'=>'created_on'});
	} # end if
	return @{$_[0]{'Views'}};
} # end sub Views

sub Comments {
	if ( $_[1] ) {
		$_[1]{'object_id'} = $_[0]{'id'};
		$_[1]{'object_type'} = ref $_[0],
		$_[1]{'order'} = 'created_on' if ! $_[1]{'order'};

		return openprint::Comment->find($_[1]);
	} # end if

	if ( ! defined $_[0]{'Comments'} ) {
		@{$_[0]{'Comments'}} = openprint::Comment->find({'object_type'=>ref $_[0], 'object_id'=>$_[0]{'id'}, 'order'=>'created_on'});
	} # end if
	return @{$_[0]{'Comments'}};
} # end sub Comments

sub Privacy {
	if ( ! exists $_[0]{'Privacy'} ) {
		$_[0]{'Privacy'} = openprint::Privacy->find_one('object_type'=>ref $_[0], 'object_id'=>$_[0]{'id'} );
		if ( ! $_[0]{'Privacy'} ) {
			$_[0]{'Privacy'} = new openprint::Privacy();
			$_[0]{'Privacy'}->object_type( ref $_[0] );
			$_[0]{'Privacy'}{'object_id'} = $_[0]{'id'};
		} # end if
	} # end if
	return $_[0]{'Privacy'};
} # end sub Privacy

sub can_view {
return 1;
} # end sub can_view
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
