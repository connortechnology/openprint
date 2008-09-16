package openprint::Timetrack;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
use MIME::QuotedPrint;
use MIME::Base64;

require openprint::Currency;
require openprint::Company;
require openprint::Service;

my $debug = 1;

use strict;
use vars qw( %fields %defaults %transforms );

require sql;

%fields = (
	'id'				=> 'id',
	'starting'			=>	'starting',
	'ending'			=>	'ending',
	'company_id'		=>	'company_id',
	'project_id'		=>	'project_id',
	'description'		=>	'description',
	'invoice_id'		=>	'invoice_id',
	'service_id'		=>	'service_id',
	'owner_id'			=>	'owner_id',
	'time_associated'	=>	'time_associated',
	'user_id'			=>	'user_id',
	'paycheque_id'		=>	'paycheque_id',
	'rate'				=>	'rate',
	'created_on'		=> 'created_on',
	'updated_on'		=> 'updated_on',
	'deleted'			=> 'deleted',
	'currency_id'		=>	'currency_id',
);

%transforms = (
);
%defaults = (
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'deleted'		=> 0,
	'rate'			=>	undef,
	'paycheque_id'	=>	undef,
	'currency_id'	=>	undef,
	'owner_id'		=>	undef,
	'invoice_id'	=>	undef,
);

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM Timetracks WHERE 1>0};
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

	if ( $params{'employee_id'} ) {
		if ( ref $params{'employee_id'} eq 'ARRAY' ) {
			$sql .= q{ AND user_id IN (}.join(',', map {'?'} @{$params{'employee_id'}} ).')';
			push @values, @{$params{'employee_id'}};
		} else {
			$sql .= q{ AND user_id=?};
			push @values, $params{'employee_id'};
		} # end if
	} # end if

	if ( $params{'company_id'} ) {
		if ( ref $params{'company_id'} eq 'ARRAY' ) {
			$sql .= q{ AND company_id IN (}.join(',', map {'?'} @{$params{'company_id'}} ).')';
			push @values, @{$params{'company_id'}};
		} else {
			$sql .= q{ AND company_id=?};
			push @values, $params{'company_id'};
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
	if ( $params{'starting_start'} and $params{'starting_end'} ) {
		$sql .= ' AND ( starting BETWEEN ? AND ? )';
		push @values, @params{'starting_start','starting_end'};
	} elsif ( $params{'starting_start'} ) {
		$sql .= ' AND starting >= ?';
		push @values, $params{'starting_start'};
	} elsif ( $params{'starting_end'} ) {
		$sql .= ' AND starting <= ?';
		push @values, $params{'starting_end'};
	} # end if
	if ( $params{'ending_start'} and $params{'ending_end'} ) {
		$sql .= ' AND ( ending BETWEEN ? AND ? )';
		push @values, @params{'ending_start','ending_end'};
	} elsif ( $params{'ending_start'} ) {
		$sql .= ' AND ending >= ?';
		push @values, $params{'ending_start'};
	} elsif ( $params{'ending_end'} ) {
		$sql .= ' AND ending <= ?';
		push @values, $params{'ending_end'};
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
		$openprint::log->warn("Error loading Timetracks: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug ) {
		$openprint::log->debug("openprint::Timetrack::find($sql) (@values)");
	} # end if
	return map { new openprint::Timetrack( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Timetracks WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub delete {
	my $self = shift;
	return sql::update( undef, undef, 'Timetracks', ['id=?', $$self{'id'} ], 'deleted', 1 );
} # end sub delete

sub destroy {
	my $self = shift;
    return sql::execute( undef, undef, q{DELETE FROM Timetracks WHERE id=?}, $$self{'id'} );
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
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('timetracks_id_seq')});
		$sql{'id'} = $$self{id};
		if ( my $error = sql::insert( undef, undef, 'Timetracks', \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'Timetracks', ['id=?', $$self{'id'}], \%sql ) ) {
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
	my $new = new openprint::Timetrack();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

sub Currency {
	return new openprint::Currency( $_[0]{currency_id} );
} # end sub Currency

sub Company {
	return new openprint::Company( $_[0]{company_id} );
} # end sub Company

sub Service {
	return new openprint::Service( $_[0]{service_id} );
} # end sub Service

sub elapsed {
	my ( $self ) = @_;

	return Date::Parse::str2time( $$self{'ending'} ) - Date::Parse::str2time( $$self{'starting'} );
} # end sub elapsed

sub value {
	my ( $self ) = @_;
	my $elapsed = $self->elapsed();

	if ( ! $$self{'rate'} ) {
		my $Service = $self->Service();
		my %Price = $Service->get_price( undef, undef, $self->Company()->Pricelist() );
$openprint::log->debug( "Elapsed: $elapsed : " . $elapsed/3600 . ' : Service: ' .$Service->name() .' Price:' . $Price{'Price'} );
		return $Price{'Price'} * $elapsed / 3600;
	} else {
$openprint::log->debug( "Elapsed: $elapsed : " . $elapsed/3600 . ' : Rate:' . $$self{'rate'} );
		return $$self{'rate'} * $elapsed / 3600;
	} # end if
	
} # end sub value 

sub User {
	return new openprint::User( $_[0]{user_id} );
} # end sub User

sub paid {
	return $_[0]->paycheque_id() ? 1 : 0;
} # end sub paid
sub invoiced {
	return $_[0]->invoice_id() ? 1 : 0;
} # end sub invoiced

1;

__END__
~       
