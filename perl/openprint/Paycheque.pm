package openprint::Paycheque;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
use MIME::QuotedPrint;
use MIME::Base64;

my $debug = 1;

use strict;
use vars qw( %fields %defaults %transforms );

require sql;

%fields = (
	'id'				=>	'id',
	'employer_id'		=>	'employer_id',
	'employee_id'		=>	'employee_id',
	'total'				=>	'total',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'currency_id'		=>	'currency_id',
	'internal_notes'	=>	'internal_notes',
	'external_notes'	=>	'external_notes',
	'paid_on'			=>	'paid_on',
	'deleted'			=>	'deleted',
);

%transforms = (
);
%defaults = (
	'deleted'		=>	0,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'paid_on'		=> 'NOW()',
	'total'			=>	undef,
);

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM Paycheques WHERE 1>0};
	my @values;
	if ( $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= q{ AND id IN (}.join(',', map {'?'} @{$params{'id'}} ).')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= q{ AND id=?};
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'employer_id'} ) {
		if ( ref $params{'employer_id'} eq 'ARRAY' ) {
			$sql .= q{ AND employer_id IN (}.join(',', map {'?'} @{$params{'employer_id'}} ).')';
			push @values, @{$params{'employer_id'}};
		} else {
			$sql .= q{ AND employer_id=?};
			push @values, $params{'employer_id'};
		} # end if
	} # end if
	if ( $params{'employee_id'} ) {
		if ( ref $params{'employee_id'} eq 'ARRAY' ) {
			$sql .= q{ AND employee_id IN (}.join(',', map {'?'} @{$params{'employee_id'}} ).')';
			push @values, @{$params{'employee_id'}};
		} else {
			$sql .= q{ AND employee_id=?};
			push @values, $params{'employee_id'};
		} # end if
	} # end if
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

	if ( $params{'paid_on_start'} and $params{'paid_on_end'} ) {
		$sql .= ' AND ( paid_on BETWEEN ? AND ? )';
		push @values, @params{'paid_on_start','paid_on_end'};
	} elsif ( $params{'paid_on_start'} ) {
		$sql .= ' AND paid_on >= ?';
		push @values, $params{'paid_on_start'};
	} elsif ( $params{'paid_on_end'} ) {
		$sql .= ' AND paid_on <= ?';
		push @values, $params{'paid_on_end'};
	} # end if

	if ( $params{'deleted'} ) {
		$sql .= ' AND deleted=?';
		push @values, $params{'deleted'};
	} else {
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if
	if ( $params{'completed'} ) {
		$sql .= ' AND completed=?';
		push @values, $params{'completed'};
	} # end if
	if ( $params{'order_id'} ) {
		$sql .= ' AND order_id=?';
		push @values, $params{'order_id'};
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->warn("Error loading Paycheques: ($sql) (@values)" . $dbh->errstr );
		return;
	} elsif ($debug ) {
		$log->debug("openprint::Paycheque::find($sql) (@values)");
	} # end if
	return map { new openprint::Paycheque( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $dbh->selectrow_hashref( 'SELECT * FROM Paycheques WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $log->debug($dbh->errstr ); }
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load

sub delete {
	my $self = shift;
	return sql::update( undef, undef, 'Paycheques', ['id=?', $$self{'id'} ], 'deleted', 1 );
} # end sub delete

sub destroy {
	my $self = shift;
    return sql::execute( undef, undef, q{DELETE FROM Paycheques WHERE id=?}, $$self{'id'} );
} # end sub destroy

sub save {
	my ( $self, $param ) = @_;
	
	$self->set( $param ) if $param;

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$fields{$k}} = $$self{$k};
	} # end foreach

	my $ac = sql::start_transaction( $dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('paycheque_id_seq')});
		$sql{'id'} = $$self{id};
		if ( my $error = sql::insert( undef, undef, 'Paycheques', \%sql ) ) {
			delete $$self{'id'};
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'Paycheques', ['id=?', $$self{'id'}], \%sql ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
	} # end if
	sql::end_transaction( $dbh, $ac );
	$self->load();
	return '';
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::Paycheque();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

sub Employer {
	return new openprint::Company( $_[0]{employer_id} );
} # end sub Payor

sub Employee {
	return new openprint::User( $_[0]{employee_id} );
} # end sub Recipient

sub Currency {
	return new openprint::Currency( $_[0]{currency_id} );
} # end sub Currency

sub add_Timetrack {
	my ( $self, $Timetrack ) = @_;
	sql::insert( undef, undef, 'paycheques_timetracks', 'timetrack_id', $Timetrack->id(), 'paycheque_id', $$self{id} );
} # end sub add_Timetrack

sub del_Timetrack {
	my ( $self, $Timetrack ) = @_;

	sql::execute( undef, undef, 'DELETE FROM paycheques_timetracks WHERE paycheque_id=? AND timetrack_id=?', $$self{id}, $$Timetrack{'id'} );
} # end sub del_Timetrack

1;

__END__
~       
