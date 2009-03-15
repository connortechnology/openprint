package openprint::ProductCategory;
@ISA = qw( openprint::Object );

use strict;

use openprint ();
use vars qw($serial $table $log $dbh %variable %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require openprint::logs;

$serial = 'Product_Category_Id_seq';
$table = 'Product_Categories';

%fields = (
			'name'				=>	'name',
			'description'		=>	'description',
			'projecttype_id'	=>	'projecttype_id',
);

%defaults = (
		'projecttype_id'	=>	undef,
);

my $debug = 1;

sub find {
	my %params = @_;
	my $sql = 'SELECT * FROM Product_Categories WHERE 1>0';
	my @values = ();

	if ( $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
		} else {
		$sql .= ' AND id=?';
		push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'projecttype_id'} ) {
		$sql .= ' AND projecttype_id=?';
		push @values, $params{projecttype_id};
	} # end if
	if ( $params{'name'} ) {
		$sql .= ' AND name=?';
		push @values, $params{name};
	} # end if
	if ( exists $params{'deleted'} ) {
		if ( $params{'deleted'} ) {
			$sql .= ' AND (deleted=? OR deleted IS NULL)';
			push @values, $params{'deleted'};
		} else {
			$sql .= ' AND deleted=?';
			push @values, $params{'deleted'};
		} # end if
	} else {
		$sql .= ' AND (deleted=false OR deleted IS NULL)';
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
    if ( ! $data ) {
        $openprint::log->error("Error Loading Product Categories: ($sql) (@values): " . $openprint::dbh->errstr );
        return;
    } elsif ( $debug ) {
        $openprint::log->debug("Loading Product Categories: ($sql) (@$data)");
    } # end if
    return map { new openprint::ProductCategory( $_->{id}, $_ ) } @$data;
} # end sub find

# Returns a copy of the paper object.
# Will also save the data to db
sub copy {
	my $self = shift;
	my $copy = new openprint::ProductCategory();
	@$copy{keys %$self} = @$self{keys %$self};
	$$copy{name} .= 'Copy of ' . $$copy{name};
	delete $$copy{id};
	return $copy;
} # end sub copy

sub delete {
	my $self = shift;
	sql::update( undef, undef, 'Product_Categories', ['id=?', $$self{id}], 'deleted', 1 );
} # end sub delete

sub destroy {
	my $self = shift;
	return if ! $$self{'id'};
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $Product ( openprint::Product::find( 'category_id' => $$self{'id'} ) ) {
		$Product->category_id( '' );
		$Product->save();
	} # end foreach
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Product_Categories WHERE id=?}, $$self{'id'} );
	sql::end_transaction( $openprint::dbh, $ac );
	
	# Add record to audit log - action "Delete Product Category".
	openprint::logs::insertLogRecord('16', "Product Category ID: " . $$self{'id'} . " Name: " . $$self{'name'},);
} # end sub delete

sub products {
	my $self = shift;
	my %params = @_;
	$params{'category_id'} = $$self{'id'};

	return openprint::Product::find( %params );
	
} # end sub products

sub ProjectType {
	my $self = shift;

	return new openprint::ProjectType( $$self{projecttype_id} );
	
} # end sub Type

1;
__END__
