package openprint::Object;

use strict;
use openprint ();
use vars qw( %variable $AUTOLOAD %cache %fields %defaults %transforms $no_cache );
my $debug;
$no_cache = 0;

sub init_cache {
	$no_cache = 0;
    %cache = ();
} # end sub init_cache

sub debug {
$openprint::log->debug("Dumping Object cache");
    foreach my $o ( keys %cache ) {
        foreach my $id ( keys %{$cache{$o}} ) {
            $openprint::log->debug( "$o : $id" );
        } # end foreach
    } # end foreach
} # end sub debug

sub new {
	my ( $parent, $id, $data ) = @_;

    if ( (! $no_cache) and $id and $openprint::Object::cache{$parent} and $openprint::Object::cache{$parent}{$id} ) {
        return $openprint::Object::cache{$parent}{$id};
    } # end if

    my $self = {};
    bless $self, $parent;

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
	$openprint::log->warn("Object needs a load routine:" . ref $self );
} # end sub load

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
	if ( $debug ) {
		my $type = ref $self;
		my %fields = eval ('%'.$type.'::fields');

		foreach my $field ( @_ ) {
			if ( ! defined $fields{$field} ) {
				$openprint::log->warn( $type . ": Invalid field requested: ($field)." );
			} # end if
		} # end foreach
	} # end if

    return @$self{@_};
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

		my %defaults = eval('%'.$type . '::defaults');

		if ( (!$$self{$field})  and exists $defaults{$field} ) {
$openprint::log->debug("Setting default ($field) ($$self{$field}) ($defaults{$field}) ");
			$$self{$field} = $defaults{$field};
		} else {
$openprint::log->debug("Not Setting default ($field) ($$self{$field}) ($defaults{$field}) ");
		} # end if
	} # end foreach
	return @set_fields;
} # end sub set

1;
__END__
