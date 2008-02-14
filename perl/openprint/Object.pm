package openprint::Object;

use strict;
use openprint ();
use vars qw( %variable $AUTOLOAD %cache %fields %defaults %transforms $no_cache );

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

    if ( $id and $openprint::Object::cache{$parent} and $openprint::Object::cache{$parent}{$id} ) {
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
    my @requested_fields = @_;

    foreach my $field ( @requested_fields ) {
        if ( ! defined $fields{$field} ) {
            $openprint::log->warn( ref $self . ": Invalid field requested: ($field)." );
        } # end if
    } # end foreach

    return @$self{@requested_fields};
} # end sub get

sub set {
	my ( $self, $params ) = @_;
	my @set_fields = ();

	my $type = ref $self;

	foreach my $field ( keys %{$params} ) {
		
		if ( eval( 'defined $' . $type . '::fields{$field}') ) {
$openprint::log->debug("Blah: $!") if $!;

			my @transforms = eval('@{$'.$type.'::transforms{$field}}');
$openprint::log->debug("Transforms: @transforms");

			foreach my $transform ( @transforms ) {
				eval '$params->{$field} =~ ' . $transform;
			} # end foreach

			if ( $params->{$field} eq '' and eval('exists $'.$type.'::defaults{$field}') ) {
				$params->{$field} = $defaults{$field};
			} # end if

# if valid db field
			if ( ( ! defined $$self{$field} ) or ($$self{$field} ne $params->{$field}) ) {
# Only make changes to fields that have changed
				$$self{$field} = $$params{$field};
				push @set_fields, eval('$'.$type.'::fields{$field}'), $$params{$field};	#mark for sql updating
			} # end if
		} else {
			$openprint::log->warn( $type."::Set::Invalid field requested: ($field)." );
		} # end if
	} # end foreach
	return @set_fields;
} # end sub set

1;
__END__
