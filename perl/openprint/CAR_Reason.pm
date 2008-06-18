package openprint::CAR_Reason;
@ISA = qw(openprint::Object);

use MIME::QuotedPrint;
use MIME::Base64;
use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

use strict;
use vars qw( %fields %defaults %transforms );

require sql;

%fields = (
	'name'		=> 'name',
	'deleted'	=> 'deleted',
	'sorting'	=>	'sorting',
);

%transforms = (
);
%defaults = (
	'deleted'		=> 0,
);

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM CAR_Reasons WHERE 1>0};
	my @values;

	if ( $params{'deleted'} ) {
		$sql .= ' AND deleted=?';
		push @values, $params{'deleted'};
	} else {
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if
	if ( $params{'area_id'} ) {
		$sql .= ' AND area_id=?';
		push @values, $params{'area_id'};
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->warn("Error loading CAR_Reasons: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug ) {
		$openprint::log->debug("openprint::CAR_Reason::find($sql) (@values)");
	} # end if
	return map { new openprint::CAR_Reason( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM CAR_Reasons WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub delete {
	my $self = shift;
	return sql::update( undef, undef, 'CAR_Reasons', ['id=?', $$self{'id'} ], 'deleted', 1 );
} # end sub delete

sub destroy {
	my $self = shift;
    return sql::execute( undef, undef, q{DELETE FROM CAR_Reasons WHERE id=?}, $$self{'id'} );
} # end sub destroy

sub save {
	my ( $self, $param ) = @_;
	
	$self->set( $param ) if $param;

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$k} = $$self{$k};
	} # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('car_reasons_id_seq')});
		$sql{'id'} = $$self{id};
		if ( my $error = sql::insert( undef, undef, 'CAR_Reasons', \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'CAR_Reasons', ['id=?', $$self{'id'}], \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return '';
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::CAR_Reason();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

1;
__END__
