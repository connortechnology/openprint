package logger;
use Encode;
use strict;

sub new {
	my $self = {};
    bless( $self, shift );
	my $opts = shift;
	if ( ref $opts eq 'HASH' ) {
		$$self{'level'} = $$opts{'level'};
		$self->file( $$opts{'file'} );
	} else {
		$self->{level} = $opts;
		$self->file();	
	} # end if
	return $self;
} # end sub new

sub level {
	$_[0]{level} = $_[1] if @_ > 1;
	return $_[0]{'level'};
} # end sub level

sub file {
	my ( $self, $file ) = @_;
	$$self{'file'} = $file;
	return;
} # end sub file

sub print {
	my ( $self, $message ) = @_;
	if ( $$self{file} ) {
		my $fh;
		if ( ! open( $fh, ">>$$self{file}" ) ) {
			print STDERR "Unable to open $$self{file}. : $!";
			return $!;
		} # end if
		print $fh $message;
		close($fh);
	} else {
		print STDERR $message;
	} # end if
} # end sub print

sub emerg {
	my $self = shift;
}

sub alert {
	$_[0]->print( "[alert] $_[1]\n" );
}
sub crit {
    my $self = shift;
	my $message = shift;
	$self->print( "[crit] $message\n" );
}
sub error {
	if ( $_[0]{level} eq 'error' or $_[0]->{level} eq 'warn' or $_[0]->{level} eq 'debug' ) {
		$_[0]->print( "[error] $_[1]\n" );
	} # end if
}
sub warn {
    my $self = shift;
	my $message = shift;
	if ( $self->{level} eq 'warn' or $self->{level} eq 'debug' ) {
		$self->print( "[warn] $message\n" );
	} # end if
}
sub notice {
    my $self = shift;
	my $message = shift;
	$self->print( "[notice] $message\n" );
}
sub info {
    my $self = shift;
	my $message = shift;
	if ( $self->{level} eq 'info' or $self->{level} eq 'debug' ) {
		$self->print( "[info] $message\n" );
	} # end if
}
sub debug {
    my $self = shift;
	my $message = shift;
	if ( $self->{level} eq 'debug' ) {
		$self->print( Encode::encode('utf-8',"[debug] $message\n") );
	} # end if
}

1;
__END__
