package openprint::logRecord;
@ISA = qw( openprint::Object );
require openprint::Object;
require Date::Handler;
require openprint::User;
require openprint::logAction;
use strict;

my $debug = 1;
use vars qw( $log $dbh $table $serial %fields %tansforms %defaults );
$table = 'log';
$serial = 'log_id_seq';
%fields = (
	'id'	=>	'id',
	'ip_address'	=>	'ip_address',
	'hostname'		=>	'hostname',
	'user_id'		=>	'user_id',
	'company_id'	=>	'company_id',
	'date_time'		=>	'date_time',	
	'action_type'	=>	'action_type',
);

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
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading logRecord: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading logRecord: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::logRecord( $_->{id}, $_ ); } @$data;
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
	if ( defined $new ) {
		$$self{'hostname'} = $new;
	} # end if
	if ( ! defined $$self{'hostname'} ) {
		return $$self{'ip_address'} unless $$self{'ip_address'} =~ /\d+\.\d+\.\d+\.\d+/;
		my @h = gethostbyaddr(pack('C4',split('\.',$$self{'ip_address'})),2);
		if ( @h ) {
			$self->save({'hostname' => $h[0] } );
		} # end if
	} # end if
	return $$self{'hostname'} ? $$self{'hostname'} : $$self{'ip_address'};
} # end sub hostname
1;
__END__
