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

my $debug = 0;

use strict;
use vars qw( $table $serial %fields %defaults %transforms %find_cache );

require sql;

$table = 'timetracks';
$serial = 'timetracks_id_seq';
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
	'service_id'	=>	undef,
	'project_id'	=>	undef,
	'user_id'		=>	undef,
);

sub find {
	my %params = @_;

	my $hash_key = join(';',map { $_, ref $params{$_} eq 'HASH' ? join(';',%{$params{$_}}) :$params{$_} } sort keys %params );
	return map { new openprint::Timetrack( $_ ) } @{$find_cache{$hash_key}} if $find_cache{$hash_key};

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

	if ( $params{'service_id'} ) {
		if ( ref $params{'service_id'} eq 'ARRAY' ) {
			$sql .= q{ AND service_id IN (}.join(',', map {'?'} @{$params{'service_id'}} ).')';
			push @values, @{$params{'service_id'}};
		} else {
			$sql .= q{ AND service_id=?};
			push @values, $params{'service_id'};
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

	if ( exists $params{'invoice_id'} ) {
		if ( $params{'invoice_id'} ) {
			if ( ref $params{'invoice_id'} eq 'ARRAY' ) {
				$sql .= q{ AND invoice_id IN (}.join(',', map {'?'} @{$params{'invoice_id'}} ).')';
				push @values, @{$params{'invoice_id'}};
			} else {
				$sql .= q{ AND invoice_id=?};
				push @values, $params{'invoice_id'};
			} # end if
		} else {
			$sql .= q{ AND invoice_id IS NULL};
		} # end if
	} # end if

	if ( exists $params{'paycheque_id'} ) {
		if ( ! $params{'paycheque_id'} ) {
			$sql .= q{ AND paycheque_id IS NULL};
		} elsif ( ref $params{'paycheque_id'} eq 'ARRAY' ) {
			$sql .= q{ AND paycheque_id IN (}.join(',', map {'?'} @{$params{'invoice_id'}} ).')';
			push @values, @{$params{'paycheque_id'}};
		} else {
			$sql .= q{ AND paycheque_id=?};
			push @values, $params{'paycheque_id'};
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
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
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
	@{$find_cache{$hash_key}} = map { $_->{id} } @$data;
	return map { new openprint::Timetrack( $_->{id}, $_ ); } @$data;
} # end sub find

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

	if ( $$self{'time_associated'} ) {
		return Date::Parse::str2time( $$self{'ending'} ) - Date::Parse::str2time( $$self{'starting'} );
	} else {
		my ($start) = $$self{'starting'} =~ /(\d\d\d\d-\d\d-\d\d)/;
		my ($end) = $$self{'ending'} =~ /(\d\d\d\d-\d\d-\d\d)/;
		return Date::Parse::str2time( $end ) - Date::Parse::str2time( $start );
	} # end if
} # end sub elapsed

sub Price {
	my ( $self ) = @_;
	my $elapsed = $self->elapsed();
	my $Service = $self->Service();
	my %Price = $Service->get_price( undef, undef, $self->Company()->Pricelist() );
	if ( $$self{'rate'} ) {
		$Price{'Cost'} = $Price{'Price'} = $$self{'rate'};
	} # end if

	if ( lc $Price{'units'} eq '/month' ) {
		$elapsed = sprintf('%.0f',$elapsed/(60*60*24*30));
		$openprint::log->debug('Month pricing ' . $elapsed );
		$Price{'Total'} = $Price{'Price'} * $elapsed;
	} elsif ( lc $Price{'units'} eq '/hr.' ) {
		$Price{'Total'} = $Price{'Price'} * $elapsed / 3600;
	} else {
		$openprint::log->warn('Unknown units in Timetrack Service ('.$Service->name().') ('.$Price{'units'}.') assuming Hrs');
		$Price{'Total'} = $Price{'Price'} * $elapsed / 3600;
	} # end if
	return \%Price;
} # end sub Price

sub value {
	my ( $self ) = @_;
	my $Price = $self->Price();
	return $$Price{'Total'};
} # end sub value 

sub wage {
	my ( $self ) = @_;
	my $elapsed = $self->elapsed();
	return $self->User()->wage() * $elapsed / 3600;
} # end sub  wage

sub User {
	return new openprint::User( $_[0]{user_id} );
} # end sub User
sub Employee {
	return new openprint::User( $_[0]{user_id} );
} # end sub Employee

sub paid {
	return $_[0]->paycheque_id() ? 1 : 0;
} # end sub paid
sub invoiced {
	return $_[0]->invoice_id() ? 1 : 0;
} # end sub invoiced

sub save {
	%find_cache = ();
	my $self = shift;
	return $self->SUPER::save(@_);
}

sub copy {
	my $New = $_[0]->SUPER::copy();
	delete $$New{'invoice_id'};
	delete $$New{'paycheque_id'};
	return $New;
} # end sub copy

1;

__END__
~       
