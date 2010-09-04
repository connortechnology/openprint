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
    my $self = shift;
	my $message = shift;
	$self->print( "[alert] $message\n" );
}
sub crit {
    my $self = shift;
	my $message = shift;
	$self->print( "[crit] $message\n" );
}
sub error {
    my $self = shift;
	my $message = shift;
	if ( $self->{level} eq 'error' or $self->{level} eq 'warn' or $self->{level} eq 'debug' ) {
		$self->print( "[error] $message\n" );
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
