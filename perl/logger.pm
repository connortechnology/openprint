package logger;

sub new {
	my $self = {};
    bless( $self, shift );
	$self->{level} = shift;
	return $self;
} # end sub new

sub emerg {
    my $self = shift;
}

sub alert {
    my $self = shift;
	my $message = shift;
	print "[alert] $message\n";
}
sub crit {
    my $self = shift;
	my $message = shift;
	print "[crit] $message\n";
}
sub error {
    my $self = shift;
	my $message = shift;
	if ( $self->{level} eq 'error' or $self->{level} eq 'warn' or $self->{level} eq 'debug' ) {
		print "[error] $message\n";
	} # end if
}
sub warn {
    my $self = shift;
	my $message = shift;
	if ( $self->{level} eq 'warn' or $self->{level} eq 'debug' ) {
	print "[warn] $message\n";
	} # end if
}
sub notice {
    my $self = shift;
	my $message = shift;
	print "[notice] $message\n";
}
sub info {
    my $self = shift;
	my $message = shift;
	if ( $self->{level} eq 'info' or $self->{level} eq 'debug' ) {
		print "[info] $message\n";
	} # end if
}
sub debug {
    my $self = shift;
	my $message = shift;
	if ( $self->{level} eq 'debug' ) {
		print "[debug] $message\n";
	} # end if
}

1;

__END__

