package openprint::Label;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

my $debug = 1;

$table = 'labels';

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
	return openprint::Order->find('docket'=>$_[0]{'docket'});
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
