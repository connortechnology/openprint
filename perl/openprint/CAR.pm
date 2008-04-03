package openprint::CAR;
@ISA = qw(openprint::Object);

my $debug = 1;

use strict;
use vars qw( %fields %defaults %transforms );

require sql;

%fields = (
	'issued_to_id'	=> 'issued_to_id',
	'issued_on'		=> 'issued_on',
	'issued_by_id'	=> 'issued_by_id',
	'reply_by'		=> 'reply_by',
	'docket'		=> 'docket',
	'company_id'	=> 'company_id',
	'problem'		=> 'problem',
	'cause'			=> 'cause',
	'action'		=> 'action',	
	'effectiveness'	=> 'effectiveness',
	'area'			=> 'area',
	'reason'		=> 'reason',
	'presses'		=> 'presses',
	'part1_user_id'	=> 'part1_user_id',
	'part1_signed_on'	=> 'part1_signed_on',
	'part2_user_id'		=> 'part1_user_id',
	'part2_signed_on'	=> 'part2_signed_on',
	'part3_user_id'		=> 'part3_user_id',
	'part3_signed_on'	=> 'part3_signed_on',
	'part4_user_id'		=> 'part4_user_id',
	'part4_signed_on'	=> 'part4_signed_on',
	'reprint'			=> 'reprint',
	'reprint_approval'	=> 'reprint_approval',
	'artwork'			=> 'artwork',
	'reprint_on'		=> 'reprint_on',
	'approved_by_id'	=> 'approved_by_id',
	'created_on'		=> 'created_on',
	'approved_on'		=> 'approved_on',
	'updated_on'		=> 'updated_on',
	'deleted'			=> 'deleted',
);

%transforms = (
);
%defaults = (
	'issued_to_id'	=> undef,
	'issued_by_id'	=> undef,
	'docket'		=> undef,
	'company_id'	=> undef,
	'part1_user_id'	=> undef,
	'part2_user_id'	=> undef,
	'part3_user_id'	=> undef,
	'part4_user_id'	=> undef,
	'approved_by_id'	=> undef,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'deleted'		=> 0,
);

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM CAR WHERE 1>0};
	my @values;
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'};
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND created_on >= ?';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND created_on <= ?';
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'updated_on_start'} and $params{'updated_on_end'} ) {
		$sql .= ' AND ( updated_on BETWEEN ? AND ? )';
		push @values, @params{'updated_on_start','updated_on_end'};
	} elsif ( $params{'updated_on_start'} ) {
		$sql .= ' AND updated_on >= ?';
		push @values, $params{'updated_on_start'};
	} elsif ( $params{'updated_on_end'} ) {
		$sql .= ' AND updated_on <= ?';
		push @values, $params{'updated_on_end'};
	} # end if
	if ( $params{'issued_on_start'} and $params{'issued_on_end'} ) {
		$sql .= ' AND ( issued_on BETWEEN ? AND ? )';
		push @values, @params{'issued_on_start','issued_on_end'};
	} elsif ( $params{'issued_on_start'} ) {
		$sql .= ' AND issued_on >= ?';
		push @values, $params{'issued_on_start'};
	} elsif ( $params{'issued_on_end'} ) {
		$sql .= ' AND issued_on <= ?';
		push @values, $params{'issued_on_end'};
	} # end if

	if ( $params{'docket'} ) {
		$sql .= ' AND docket=?';
		push @values, $params{'docket'};
	} # end if
	if ( $params{'deleted'} ) {
		$sql .= ' AND deleted=?';
		push @values, $params{'deleted'};
	} else {
		$sql .= ' AND deleted=?';
		push @values, 0;
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->warn("Error loading CARs: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug ) {
		$openprint::log->debug("openprint::CAR::find($sql) (@values)");
	} # end if
	return map { new openprint::CAR( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM CAR WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub delete {
	my $self = shift;
	return sql::update( undef, undef, 'CAR', ['id=?', $$self{'id'} ], 'deleted', 1 );
} # end sub delete

sub destroy {
	my $self = shift;
    return sql::execute( undef, undef, q{DELETE FROM CAR WHERE id=?}, $$self{'id'} );
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
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('car_id_seq')});
		$sql{'id'} = $$self{id};
		if ( my $error = sql::insert( undef, undef, 'CAR', \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'CAR', ['id=?', $$self{'id'}], \%sql ) ) {
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
	my $new = new openprint::CAR();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

sub Company {
	return new openprint::Company( $_[0]{'company_id'} );
} # end sub Company

1;

__END__
~       
