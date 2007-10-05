package openprint::Manufacturer;
@ISA = qw(openprint::Object);

use strict;

require sql;
require openprint::Object;

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM Manufacturers WHERE 1>0';
	my @values;

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::Manufacturer::find( $sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::Manufacturer( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Manufacturers WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{qw/id shortname longname/} = @$data{qw/id shortname longname/};

} # end sub load

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM Manufacturers WHERE id=?}, $$self{'id'} );
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('manufacturers_id_seq')});
		sql::insert( undef, undef, 'Manufacturers', $self );
	} else {
		sql::update( undef, undef, 'Manufacturers', ['id=?', $$self{'id'}], $self );
	} # end if
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::Manufacturer();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

1;

__END__
~       
