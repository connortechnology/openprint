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
			'id'				=>	'id',
			'name'				=>	'name',
			'description'		=>	'description',
			'projecttype_id'	=>	'projecttype_id',
);

%defaults = (
		'projecttype_id'	=>	undef,
);

my $debug = 0;

sub destroy {
	my $self = shift;
	return if ! $$self{'id'};
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $Product ( openprint::Product->find( 'category_id' => $$self{'id'} ) ) {
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

	return openprint::Product->find( %params );
	
} # end sub products

sub ProjectType {
	my $self = shift;

	return new openprint::ProjectType( $$self{projecttype_id} );
	
} # end sub Type

1;
__END__
