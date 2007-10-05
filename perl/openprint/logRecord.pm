package openprint::logRecord;
@ISA = qw( openprint::Object );
require openprint::Object;
require Date::Handler;
require openprint::User;
require openprint::logAction;

my $debug = 1;

use strict;

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM log WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) {
			$openprint::log->error('Error loading Log: reason:'.$openprint::dbh->errstr());
		} # end if
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

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

sub Action {
	my $self = shift;
	return new openprint::logAction( $$self{action_type} );	
} # end sub Action
return 1;
__END__
