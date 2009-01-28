package openprint::Object;

use strict;
use openprint ();
use vars qw( $log $dbh %variable $AUTOLOAD %cache %fields %defaults %transforms $no_cache );

*log = \$openprint::log;
*dbh = \$openprint::dbh;

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

	if ( $id and $openprint::Object::cache{$parent} and $openprint::Object::cache{$parent}{$id} ) {
		return $openprint::Object::cache{$parent}{$id};
	} # end if

	my $self = {};
	bless $self, $parent;

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

	return $self;
} # end sub new

sub load {
	my ( $self, $data ) = @_;
	my $type = ref $self;
	my $table = eval '$'.$type.'::table';
	my %fields = eval '%'.$type.'::fields';

	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT * FROM } . $table . q{ WHERE id=?}, {}, $$self{'id'} );
		if ( ! $data ) {
			$log->error( 'Failure to load ' . ref $self . " $$self{'id'}: Reason: " . $dbh->errstr );
			return;
		} # end if
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};

} # end sub load

sub save {
	my ( $self, $data ) = @_;

	$self->set( $data ) if $data;

	my $type = ref $self;
	my $table = eval '$'.$type.'::table';
	my $serial = eval '$'.$type.'::serial';
	my %fields = eval '%'.$type.'::fields';

	my %sql;
	@sql{@fields{keys %fields}} = @$self{keys %fields};
	delete $sql{'created_on'};

	if ( ! $$self{'id'} ) {
		my $ac = sql::start_transaction( $dbh );
		($$self{'id'}) = ($sql{'id'}) = sql::execute( undef, undef, q{SELECT nextval('} . $serial . q{')} );
		if ( my $error = sql::insert( undef, undef, $table, \%sql ) ) {
			$dbh->rollback();
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
		sql::end_transaction( $dbh, $ac );
	} else {
		if ( my $error = sql::update( undef, undef, $table, ['id=?', $$self{id}], \%sql ) ) {
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
		
		if ( exists $$params{$field} ) {
			if ( ( ! defined $$self{$field} ) or ($$self{$field} ne $params->{$field}) ) {
# Only make changes to fields that have changed
				$$self{$field} = $$params{$field};
				push @set_fields, $fields{$field}, $$params{$field};	#mark for sql updating
			} # end if
		} # end if

#$openprint::log->debug("Transforms: @transforms");
		my @transforms = eval('@{$'.$type.'::transforms{$field}}');

		foreach my $transform ( @transforms ) {
			eval '$$self{$field} =~ ' . $transform;
		} # end foreach

		my %defaults = eval('%'.$type.'::defaults');

		if ( ( $$self{$field} eq '' or ! defined $$self{$field} )  and exists $defaults{$field} ) {
#$openprint::log->debug("Setting default ($field) ($$self{$field}) ($defaults{$field}) ");
			$$self{$field} = $defaults{$field};
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
		$$self{'deleted'}=1;
	} else {
		sql::execute( undef, undef, 'DELETE FROM '.$table.' WHERE id=?', $$self{'id'} );
		delete $openprint::Object::cache{$type}{$$self{id}};
	} # end if
	return;
} # end sub delete


1;
__END__
