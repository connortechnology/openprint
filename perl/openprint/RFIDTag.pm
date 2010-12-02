package openprint::RFIDTag;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %fields %transforms %defaults $table $serial );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

require openprint::RFIDTagType;
require openprint::Location;

my $debug = 1;
$table = 'rfidtags';
$serial = 'rfidtags_id_seq';
%fields = (
	'id'			=>	'id',
	'location_id'	=>	'location_id',
	'type_id'		=>	'type_id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'valid'			=>	'valid',
);

%transforms = (
);

%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'location_id'	=>	undef,
	'type_id'		=>	undef,
	'valid'			=>	0,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM RFIDTags WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( ( exists $params{'valid'} ) and ( $params{'valid'} ne '' ) ) {
		$sql .= ' AND valid=?';
		push @values, $params{'valid'};
	} # end if
	if ( $params{'type_id'} ) {
		$sql .= ' AND type_id=?';
		push @values, $params{'type_id'};
	} # end if
	if ( $params{'type'} ) {
		$sql .= ' AND type_id=(SELECT id FROM RFIDTagTypes WHERE lower(name)=lower(?))';
		push @values, $params{'type'};
	} # end if
	if ( $params{'id_like'} ) {
		$sql .= ' AND id LIKE ?';
		push @values, $params{id_like};
	} # end if
	if ( $params{'short_id'} ) {
		$sql .= ' AND id = ?';
		push @values, sprintf('%.15d', $params{'short_id'} );
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
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->error("Error loading RFIDTag SQL($sql)" . DBI->errstr );
	} elsif ( $debug and ! @$data ) {
		$log->debug('No RFIDTag loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded RFIDTag ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::RFIDTag( $_->{id}, $_ ) } @$data;
} # end sub find

sub save {
	my ( $self, $hash ) = @_;

	$self->set( $hash );

	if ( ! $$self{'id'} ) {
		return 'RFID Tag must have an id';
	} # end if

	if ( ! $$self{'type_id'} ) {
		my $type;
		if ( $$hash{'type'} ) {
			$type = $$hash{'type'};
		} elsif ( $$self{'type'} ) {
			$type = $$self{'type'};
		} # end if
		if ( ! $type ) {
			my $type_digit = substr( $$self{'id'}, 0, 1 );
			if ( $type_digit == 1 ) {
				$type='Location';
			} elsif ( $type_digit == 2 ) {
				$type='Skid';
			} # end if
		} # end if
                    
		if ( $type ) {
			my ( $type_id ) = sql::execute( undef, undef, 'SELECT id FROM RFIDTagTypes WHERE lower(name)=lower(?)', $type );
			if ( ! $type_id ) {
				my $Type = new openprint::RFIDTagType();
				$Type->save( {'name'=>$type } );
				$$self{'type_id'} = $Type->id();
			} else {
				$$self{'type_id'} = $type_id;
			} # end if
			$$self{'type'} = $type;
		} # end if
	} # end if

	if ( $self->type() eq 'Skid' ) {
		$self->Skid()->save({location_id=>$$self{'location_id'}});
	} # end if

	delete $$self{'type'};
	$$self{'updated_on'} = 'NOW()';
	
	my $ac = sql::start_transaction( $dbh );

	if ( ! sql::execute( undef, undef, 'SELECT * FROM RFIDTags WHERE id=?', $$self{'id'} ) ) {
		if ( my $error = sql::insert( undef, undef, 'RFIDTags', map { $_, $$self{$_} } keys %fields ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
    } else {
		if ( my $error = sql::update( undef, undef, 'RFIDTags', ['id=?', $$self{id}], map { $_, $$self{$_} } keys %fields ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
    } # end if

	sql::end_transaction( $dbh, $ac );
	$self->load();
	return;
} # end sub save

sub delete {
    my $self = shift;
    my $ac = sql::start_transaction( );
	sql::update( undef, undef, 'Skids', ['rfidtag_id=?', $$self{'id'}], 'rfidtag_id', undef );
    sql::execute( undef, undef, q{DELETE FROM RFIDTagHistory WHERE rfidtag_id=?}, $$self{'id'} );
    sql::execute( undef, undef, q{DELETE FROM RFIDTags WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
	delete $openprint::Object::cache{'openprint::RFIDTag'}{$$self{'id'}};
	return '';
} # end sub delete

sub Type {
	return new openprint::RFIDTagType( $_[0]->type_id() );
} # end sub Type

sub type {
	my ( $self, $new ) = @_;
	if ( $new and $new ne $$self{'type'} ) {
		$$self{'type'} = $new;
		$$self{'type_id'} = '';
	} # end if
	if ( $$self{'type_id'} and ! $$self{'type'} ) {
		$$self{'type'} = $self->Type()->name();
	} # end if
	return $$self{'type'};
} # end sub type

sub Location {
	return new openprint::Location( $_[0]->location_id() );
} # end sub Location

sub location_id {
    my ( $self, $new, $scanner_id ) = @_;
    if ( $new ) {
        if ( (!defined $$self{'location_id'}) or ( $new != $$self{'location_id'} ) ) {
            sql::insert( undef, undef, 'RFIDTagHistory', {'rfidtag_id'=>$$self{'id'},'location_id'=>$new, 'scanner_id'=>$scanner_id} ) if $$self{'id'};
            $$self{'location_id'} = $new;
        } # end if
    } # end if
    return $$self{'location_id'};
} # end sub location_id

sub skid_id {
	my ( $self ) = @_;
	if ( ! $$self{'id'} ) {
		$openprint::log->error('Cant load skid on a tag without an id');
		return;
	} # end if
	if ( ! $$self{'skid_id'} ) {
		my @Skids = openprint::Skid::find('rfidtag_id'=>$$self{'id'},'deleted'=>[0,1]);
		if ( @Skids ) {
			$$self{'skid_id'} = $Skids[0]->id();
		} # end if
	} # end if
	return $$self{'skid_id'};
} # end sub skid_id

sub Skid {
	my ( $self ) = @_;
	if ( ! $$self{'id'} ) {
		$openprint::log->error('Cant load skid on a tag without an id');
		return;
	} # end if
	if ( ! $$self{'skid_id'} ) {
		my @Skids = openprint::Skid::find('rfidtag_id'=>$$self{'id'},'deleted'=>[0,1]);
		if ( @Skids ) {
			$$self{'skid_id'} = $Skids[0]->id();
		} # end if
	} # end if
	return new openprint::Skid( $$self{'skid_id'} );
} # end sub Skid

sub id_short {
	my ( $self ) = @_;
	return '' if ! $$self{'id'};
	return $$self{'id'} if $self->is_invalid_id();

	my ( $type, $significant ) = $$self{'id'} =~ /^(\d)(\d{14})$/;
	return 1*$significant;
} # end sub id_short

sub is_invalid_id {
	my ( $id ) = @_;
	if ( ref $id eq 'openprint::RFIDTag' ) {
		$id = $id->id();
	} # end if

	if ( length $id != 15 ) {
		return 'Invalid length.  A valid tag should be 15 characters long. This one is ' . length $id;
	} # end if

	my $type_digit = substr( $id, 0, 1 );
	if ( $type_digit =~ /\D/ ) {
		return "Invalid type digit ($type_digit)";
	} # end if

	if ( $id =~ /\D/ ) {
		return 'Should not contain anything other than integers.';
	} # end if

	return 0;
} # end sub is_valid_id

1;
__END__
