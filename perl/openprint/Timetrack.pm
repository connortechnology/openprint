use strict;
package openprint::Timetrack;
our @ISA = qw(openprint::Object);

use openprint ();

require openprint::Currency;
require openprint::Company;
require openprint::Service;
require openprint::Paycheque_Timetrack;

use vars qw( $debug $table $serial %fields %find_fields %defaults %transforms );
$debug = 0;

$table = 'timetracks';
$serial = 'timetracks_id_seq';
%fields = (
	id				=> 'id',
	starting		=>	'starting',
	ending			=>	'ending',
	duration		=>	'duration',
	duration_override	=>	'duration_override',
	company_id		=>	'company_id',
	project_id		=>	'project_id',
	description		=>	'description',
	invoice_id		=>	'invoice_id',
	service_id		=>	'service_id',
	owner_id		=>	'owner_id',
	time_associated	=>	'time_associated',
	user_id			=>	'user_id',
	rate			=>	'rate',
	created_on		=> 'created_on',
	updated_on		=> 'updated_on',
	deleted			=> 'deleted',
	currency_id		=>	'currency_id',
	travel_associated	=>	'travel_associated',
	distance			=>	'distance',
	billable			=>	'billable',
	po					=>	'po',
	keywords			=>	undef,
);
%find_fields = (
	paycheque_id		=>	'(SELECT paycheque_id FROM Paycheques_Timetracks WHERE timetrack_id=timetracks.id)',
);

%transforms = (
	rate		=>	[ 's/[^\d\.]//g' ],
	distance	=>	[ 's/[^\d\.]//g' ],
    po			=>	[ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
	created_on			=>	q`'NOW()'`,
	updated_on			=>	q`'NOW()'`,
	deleted				=>	0,
	rate				=>	undef,
	currency_id			=>	undef,
	owner_id			=>	q`$openprint::Owner->id()`,
	invoice_id			=>	undef,
	service_id			=>	undef,
	project_id			=>	undef,
	user_id				=>	undef,
	travel_associated	=>	0,
	distance			=>	undef,
	billable			=>	q`1`,
	duration_override	=>	0,
);

sub duration {
	if ( @_ > 1 ) {
		$_[0]{duration} = $_[1];
	}
	if ( ( ! $_[0]{duration} ) and ( ! $_[0]{duration_override} ) ) {
		$_[0]{duration} = misc::seconds2hms( $_[0]->elapsed() );
	} # end if
	return $_[0]{duration};
} # end sub duration

sub elapsed {
	my ( $self ) = @_;

	if ( $$self{duration_override} ) {
		return misc::hms2time( $_[0]{duration} );

	} elsif ( $$self{time_associated} ) {
		return Date::Parse::str2time( $$self{ending} ) - Date::Parse::str2time( $$self{starting} );
	} else {
		my ($start) = $$self{starting} =~ /(\d\d\d\d-\d\d-\d\d)/;
		my ($end) = $$self{ending} =~ /(\d\d\d\d-\d\d-\d\d)/;
		return Date::Parse::str2time( $end ) - Date::Parse::str2time( $start );
	} # end if
} # end sub elapsed

sub rate {
	my ( $self ) = @_;
	my $Service = $self->Service();
	my %Price = $Service->get_price( undef, undef, $self->Company()->Pricelist() );
	if ( $$self{rate} ) {
		$Price{Cost} = $Price{Price} = $$self{rate};
	} # end if
	return $Price{Price};
}
sub units {
	my ( $self ) = @_;
	my $Service = $self->Service();
	my %Price = $Service->get_price( undef, undef, $self->Company()->Pricelist() );
	return $Price{units};
} # end sub units

sub Price {
	my ( $self ) = @_;
	my $elapsed = $self->elapsed();
	my $Service = $self->Service();
	my %Price = $Service->get_price( undef, undef, $self->Company()->Pricelist(), $self->starting() );
	if ( $$self{rate} ) {
		$Price{Cost} = $Price{Price} = $$self{rate};
	} # end if

	if ( lc $Price{units} eq '/year' ) {
		$elapsed = Math::Round::nearest(1,$elapsed/(60*60*24*365));
		#$openprint::log->debug('Month pricing ' . $elapsed );
		$Price{Total} = $Price{Price} * $elapsed;
	} elsif ( lc $Price{units} eq '/month' ) {
		$elapsed = Math::Round::nearest(1,$elapsed/(60*60*24*30));
		#$openprint::log->debug('Month pricing ' . $elapsed );
		$Price{Total} = $Price{Price} * $elapsed;
	} elsif ( lc $Price{units} eq '/hr.' ) {
		$Price{Total} = $Price{Price} * $elapsed / 3600;
	} else {
		$openprint::log->warn('Unknown units in Timetrack Service ('.$Service->name().') ('.$Price{units}.') assuming Hrs');
		$Price{Total} = $Price{Price} * $elapsed / 3600;
	} # end if
	return \%Price;
} # end sub Price

sub value {
	my ( $self ) = @_;
	my $Price = $self->Price();
	return $$Price{Total};
} # end sub value 

sub wage {
	my ( $self ) = @_;
	my $elapsed = $self->elapsed();
	return $self->User()->wage() * $elapsed / 3600;
} # end sub  wage

sub Employee {
	return new openprint::User( $_[0]{user_id} );
} # end sub Employee

sub Paycheques {
	if ( ( ! exists $_[0]{Paycheques} ) and $_[0]{id} ) {
		$_[0]{Paycheques} = [ map { $_->Paycheque() } openprint::Paycheque_Timetrack->find( timetrack_id=>$_[0]{id}) ];
	} # end if
	return @{$_[0]{Paycheques}} if $_[0]{Paycheques};
	return ();
} # end sub Paycheques

sub paycheque_id {
	my $PT = openprint::Paycheque_Timetrack->find_one('timetrack_id'=>$_[0]{id});
	return $$PT{paycheque_id} if $PT;
	return;
} # end sub paycheque_id

sub paid {
	return $_[0]->Paycheques() ? 1 : 0;
} # end sub paid

sub invoiced {
	return $_[0]->invoice_id() ? 1 : 0;
} # end sub invoiced

sub copy {
	my $New = $_[0]->SUPER::copy();
	delete $$New{invoice_id};
	return $New;
} # end sub copy

1;
__END__
