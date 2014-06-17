use strict;
package openprint::Service;
our @ISA = qw( openprint::Object );
use vars qw($debug $table $serial %fields %find_fields %transforms %defaults %session $log $dbh $cache_field $cached );

require sql;
require openprint::Object;
require openprint::pricing;
require openprint::logs;

use Memoize;
use openprint ();
*session = \%openprint::session;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$debug = 0;
$cached = 0;

$table = 'services';
$serial = 'services_id_seq';

%fields = (
		id				=>	'id',
		name			=>	'name',
		description		=>	'description',
		supplier_id		=>	'supplier_id',
		category_id		=>	'category_id',
		category		=>	undef,
		taxexempt1		=>	'taxexempt1',
		taxexempt2		=>	'taxexempt2',
		owner_id		=>	'owner_id',
		activity_code	=>	'activity_code',
	 	);	
%find_fields = (
		category		=> '(SELECT name FROM Service_Categories WHERE service_categories.id=category_id)',
		equipment_id	=> '(SELECT equipment_id FROM service_prices WHERE service_id=services.id)',
);


%transforms = (
		);

%defaults = (
		supplier_id	=>	undef,
		category_id	=>	undef,
		taxexempt1	=>	q`'N'`,
		taxexempt2	=>	q`'N'`,
		);

$cache_field = 'name';
sub cache_field {
	return $cache_field;
}

sub save {
	my ( $self, $params ) = @_;

	$self->set( $params );

	if ( $$self{'category'} and ! $$self{'category_id'} ) {
		$_ = new openprint::ServiceCategory();
		$_->save({'name'=>$$self{'category'}});
		$$self{'category_id'} = $_->id();
	} # end if
	$$self{'owner_id'} = $session{'company_id'} if ! $$self{'owner_id'};

	if ( ( my $error = $self->SUPER::save( ) ) ) {
		return $error;
	} # end if
	return;

} # end sub save

sub delete {
	my $self = shift;

	delete $openprint::Object::cache{'openprint::Service'}{$$self{id}} if $openprint::Object::cache{'openprint::Service'};	
	my $ac = sql::start_transaction( $dbh );
    sql::execute( undef, undef, q{DELETE FROM Service_Prices WHERE service_id=?}, $$self{id} );
	$self->SUPER::delete();
	openprint::logs::insertLogRecord('10', "Service Index: " . $$self{id},);
	sql::end_transaction( $dbh, $ac );
	return $dbh->errstr();
} # end sub delete

sub prices {
	return openprint::ServicePrice->find( service_id=>$_[0]{id} );
} # end sub prices

sub get_Price {
    my ( $self, $quantity, $Equipment, $Pricelist, $period ) = @_;

    if ( ! $period ) {
        $period = 'NOW()';
        if ( $debug ) {
            $log->debug("No period specified defaulting to $period");
        } # end if
    } # end if

    $Pricelist = openprint::Pricelist::get_current() if ! $Pricelist;
    my %price = openprint::pricing::get_best_price_object( $openprint::session{company_id}, $$self{id}, $$Pricelist{id}, 'openprint::service_priceset', $quantity, $$Equipment{id}, $period );

    if ( ! %price ) {
        $log->debug("No price returned for $$self{name} $$Equipment{strid} $quantity $period") if $debug;
        return ;
    } # end if

    $price{'currency_id'} = $Pricelist->currency_id();
    $price{'ServiceName'} = $$self{'name'};
    $price{'Service'} = $self;
    openprint::Currency::convert( \%price );
    return \%price;
} # end sub get_Price

sub get_price {
    my ( $self, $quantity, $Equipment, $Pricelist, $period ) = @_;

	if ( ! $period ) {
		$period = 'NOW()';
		if ( $debug ) {
			$log->debug("No period specified defaulting to $period");
		} # end if
	} # end if

	$Pricelist = openprint::Pricelist::get_current() if ! $Pricelist;
    my %price = openprint::pricing::get_best_price_object( $openprint::session{company_id}, $$self{id}, $$Pricelist{id}, 'openprint::service_priceset', $quantity, $$Equipment{id}, $period );

	if ( ! %price ) {
		$log->debug("No price returned for $$self{name} $$Equipment{strid} $quantity $period") if $debug;
		return ;
	} # end if

	$price{'currency_id'} = $Pricelist->currency_id();
	$price{'ServiceName'} = $$self{'name'};
	$price{'Service'} = $self;
	openprint::Currency::convert( \%price );
    return %price;
} # end sub get_price

sub next {
	my ($self, $params) = shift;
	my $sql = q{SELECT min(name) FROM Services WHERE name > ?};
	my @values = ($$self{'name'});
	if ( $params and $$params{category_id} ) {
		$sql .= ' AND category=?';
		push @values, $$params{category_id};
	} # end if
    my ($name) = sql::execute( undef, undef, $sql, @values );
	( $_ ) = sql::execute( undef, undef, q{SELECT id FROM Services WHERE name=?}, $name );
    return $_;
} # end sub next

sub Next {
	my ($self, $params) = shift;
	return new openprint::Service( $self->next($params) );
} # end sub Next

sub prev {
    my ( $self, $params ) = shift;
	my $sql = q{SELECT max(name) FROM Services WHERE name < ?};
	my @values = ($$self{'name'});
	if ( $params and $$params{category_id} ) {
		$sql .= ' AND category=?';
		push @values, $$params{category_id};
	} # end if
    my ($name) = sql::execute( undef, undef, $sql, @values );
	( $_ ) = sql::execute( undef, undef, q{SELECT id FROM Services WHERE name=?}, $name );
    return $_;
} # end sub next

sub Previous {
	my ($self, $params) = shift;
	return new openprint::Service( $self->prev($params) );
} # end sub Next

sub category {
    my ( $self, $category ) = @_;

    if ( defined $category ) {
        $category =~ s/^\s*(.*)\s*$/$1/;
		@$self{'category_id','category'} = sql::execute( undef, undef, q{SELECT id, name FROM Service_Categories WHERE lower(name)=?}, lc $category );
		if ( ! $$self{'category_id'} ) {
			$$self{'category'} = $category;
		} # end if
    } elsif ( $$self{'category_id'} and ! $$self{'category'} ) {
        $$self{'category'} = new openprint::ServiceCategory( $$self{'category_id'} )->name();
    } # end if
    return $$self{'category'};
} # end sub category


1;
__END__
