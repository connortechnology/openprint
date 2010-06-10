package openprint::Label;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

my $debug = 1;

%fields = (
	'id'			=>	'id',
	'type_id'		=>	'type_id',
	'reference'		=>	'reference',
	'content'		=>	'content',
	'docket'		=>	'docket',
);

%transforms = (
);

%defaults = (
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM labels WHERE 1>0';

	if ( $params{'version'} ) {
		$sql .= ' AND version=?';
		push @values, $params{'version'};
	} else {
		#$sql .= ' AND version IS NULL';
	} # end if

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'name_id'} ) {
		$sql .= ' AND name_id=?';
		push @values, $params{'name_id'};
	} # end if
	if ( $params{'docket'} ) {
		$sql .= ' AND docket=?';
		push @values, $params{'docket'};
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'}
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND ( created_on >= ?)';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on <= ?)';
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'type_id'} ) {
		if ( ref $params{'type_id'} eq 'ARRAY' ) {
			$sql .= ' AND type_id IN (' . join(',', map { '?' } @{$params{'type'}} ) . ')';
			push @values, @{$params{'type_id'}};
		} else {
			$sql .= ' AND type_id=?';
			push @values, $params{'type_id'};
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading labels SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No labels loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded labels ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Label( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Labels WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
	delete $$self{'data'};
	%{$$self{'data'}} = sql::execute( undef, undef, 'SELECT name, value FROM label_Data WHERE label_id=?', $$self{'id'} );
} # end sub load

sub save {
	my ( $self, $hash ) = @_;

	if ( $hash ) {
		$self->set( $hash );
	} # end if

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$k} = $$self{$k};
	} # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('labels_id_seq')} );
		$sql{'id'} = $$self{'id'};

		if ( my $error = sql::insert( undef, undef, 'Labels', \%sql ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if

    } else {
		#sql::execute( undef, undef, 'UPDATE Labels SET version=(SELECT MAX(version) FROM Labels WHERE id=?)+1 WHERE id=? AND version IS NULL', @$self{'id','id'} );
		if ( my $error = sql::update( undef, undef, 'Labels', ['id=?', $$self{id}], [map { $_, $$self{$_} } keys %fields ] ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
    } # end if

	sql::execute(undef,undef,'DELETE FROM Label_Data WHERE label_id=?', $$self{'id'} );
	foreach my $k ( keys %{$$self{'data'}} ) {
		sql::insert( undef, undef, 'Label_data', 'label_id', $$self{'id'}, 'name', $k, 'value', $$self{'data'}{$k} );
	} # end foreach

	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return;
} # end sub save

sub delete {
    my $self = shift;
    my $ac = sql::start_transaction( );
    sql::execute( undef, undef, q{DELETE FROM Label_data WHERE label_id=?}, $$self{'id'} );
    sql::execute( undef, undef, q{DELETE FROM Labels WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

sub Order {
	return openprint::Order::find('docket'=>$_[0]{'docket'});
} # end sub Order

sub Project {
	return openprint::Project->find_one('docket'=>$_[0]{'docket'});
} # end sub Project

sub Type {
	return new openprint::LabelType( $_[0]{'type_id'} );
} # end sub Type

sub set_data {
	my $self = shift;
	my %new_data = @_;	
	foreach my $k ( keys %new_data ) {
		$$self{'data'}{$k} = $new_data{$k};
	} # end foreach
} # end sub set_data

sub get_data {
	my $self = shift;
	return @{$$self{'data'}}{@_};
} # end sub get_data

sub copy {
	my $self = shift;
	my $new = new openprint::Label();
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{'id'};
	foreach my $k ( keys %{$$self{'data'}} ) {
		$$new{'data'}{$k} = $$self{'data'}{$k};
	} # end foreach
	return $new;
} # end sub copy

1;
__END__
