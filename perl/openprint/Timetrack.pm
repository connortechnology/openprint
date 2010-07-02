package openprint::Timetrack;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require openprint::Currency;
require openprint::Company;
require openprint::Service;


use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms %find_cache );
$debug = 1;

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
	'travel_associated'	=>	'travel_associated',
	'distance'			=>	'distance',
);

%transforms = (
	'rate'	=>	[ 's/[^\d\.]//g' ],
	'distance'	=>	[ 's/[^\d\.]//g' ],
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
	'travel_associated'	=>	0,
	'distance'		=>	undef,
);

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

sub rate {
	my ( $self ) = @_;
	my $Service = $self->Service();
	my %Price = $Service->get_price( undef, undef, $self->Company()->Pricelist() );
	if ( $$self{'rate'} ) {
		$Price{'Cost'} = $Price{'Price'} = $$self{'rate'};
	} # end if
	return $Price{'Price'};
}
sub units {
	my ( $self ) = @_;
	my $Service = $self->Service();
	my %Price = $Service->get_price( undef, undef, $self->Company()->Pricelist() );
	return $Price{'units'};
} # end sub units

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
