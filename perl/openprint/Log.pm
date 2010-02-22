package openprint::Log;
@ISA = qw( openprint::Object );
require openprint::Object;
require openprint::User;
require openprint::logAction;
require openprint::Host;
use strict;

my $debug = 1;
use vars qw( $log $dbh $table $serial %fields %tansforms %defaults %types );
$table = 'log';
$serial = 'log_id_seq';
%fields = (
	'id'	=>	'id',
	'user_id'		=>	'user_id',
	'company_id'	=>	'company_id',
	'date_time'		=>	'date_time',	
	'action_type'	=>	'action_type',
	'note'			=>	'note',
	'host_id'		=>	'host_id',
);

%types = (
2	=> 'Successful Login',
3	=>	'Logout', 
78	=>	'Failed Login',
79	=> '',
);
use openprint ();
*log = \$openprint::log;
*dbh = \$openprint::dbh;

sub find_one {
	my %params = @_;
	$params{'limit'}=1;
	my @Results = find(%params);
	return $Results[0] if @Results;
} # end sub find_one
sub find {
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM log WHERE 1>0};
	if ( $params{'id'} ) {
        if ( ref $params{'id'} eq 'ARRAY' ) {
            $sql .= q{ AND id IN (}.join(',', map {'?'} @{$params{'id'}} ).')';
            push @values, @{$params{'id'}};
        } else {
            $sql .= q{ AND id=?};
            push @values, $params{'id'};
        } # end if
	} # end if
	if ( $params{'user_id'} ) {
		$sql .= ' AND user_id=?';
		push @values, $params{'user_id'};
	} # end if
	if ( $params{'company_id'} ) {
		$sql .= ' AND company_id=?';
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'action_type'} ) {
        if ( ref $params{'action_type'} eq 'ARRAY' ) {
            $sql .= q{ AND action_type IN (}.join(',', map {'?'} @{$params{'action_type'}} ).')';
            push @values, @{$params{'action_type'}};
        } else {
            $sql .= q{ AND action_type=?};
            push @values, $params{'action_type'};
        } # end if
	} # end if
	
	if ( $params{'ip_address'} ) {
		$sql .= ' AND ip_address=?';
		push @values, $params{'ip_address'};
	} # end if
	if ( exists $params{'host_id'} ) {
		if ( ! defined $params{'host_id'} ) {
			$sql .= ' AND host_id IS NULL';
		} else {
			$sql .= ' AND host_id=?';
			push @values, $params{'host_id'};
		} # end if
	} # end if
	if ( $params{'when_start'} and $params{'when_end'} ) {
		$sql .= q{ AND (date_time BETWEEN ? AND ?)};
		push @values, @params{'when_start','when_end'};
	} elsif ( $params{'when_start'} ) {
		$sql .= q{ AND (date_time >= ?)};
		push @values, $params{'when_start'};
	} elsif ( $params{'when_end'} ) {
		$sql .= q{ AND (date_time <= ?)};
		push @values, $params{'when_end'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->error("Error loading Log: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$log->debug("Loading Log: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::Log( $_->{id}, $_ ); } @$data;
} # end sub find

sub User {
	my $self = shift;
return new openprint::User( $$self{user_id} );	
} # end sub User

sub Company {
	my $self = shift;
	return new openprint::Company( $$self{company_id} );	
} # end sub Company

sub Action {
	my $self = shift;
	return new openprint::logAction( $$self{action_type} );	
} # end sub Action

sub hostname {
	my ( $self, $new ) = @_;
	my $Host = $self->Host();

	if ( defined $new ) {
		$Host->save({'hostname'=>$new});
	} # end if
	return $Host->hostname();
} # end sub hostname

sub ip_address {
	my ( $self, $new ) = @_;
	my $Host = $self->Host();

	if ( defined $new ) {
		$Host->save({'ip'=>$new});
	} # end if
	return $Host->ip();
} # end sub ip_address

sub Host {
	return new openprint::Host( $_[0]{'host_id'} );
} # end sub Host

1;
__END__
