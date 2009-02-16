package openprint::QuotedProject;
@ISA = qw(openprint::Project);

use strict;
use openprint ();
use vars qw( $log $dbh %session %config %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
*config = \%openprint::config;

require sql;
require openprint::QuoteLevel;

my $debug = 0;


%fields = (
			'id'				=>	'id',
			'quantity1'			=>	'intquantity1',
			'quantity2'			=>	'intquantity2',
			'quantity3'			=>	'intquantity3',
			'markup1'			=>	'dblmarkup1',
			'markup2'			=>	'dblmarkup2',
			'markup3'			=>	'dblmarkup3',
			'price1'			=>	'dblprice1',
			'price2'			=>	'dblprice2',
			'price3'			=>	'dblprice3',
			'template_id'		=>	'template_id',
			'include_detailed'	=>	'include_detailed',
			'project_id'		=>	'projectindex',
			'quote_id'			=>	'quoteindex',
);

%transforms = (
	
);

%defaults = (
	'id'	=> undef,
	'markup1'	=> 0,
	'markup2'	=> 0,
	'markup3'	=> 0,
	'price1'	=> 0,
	'price2'	=> 0,
	'price3'	=> 0,
);

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM tbl_quote_details WHERE 1>0';
	my @values;

	if ( $params{'quote_id'} ) {
		$sql .= ' AND quoteindex=?';
		push @values, $params{'quote_id'};
	} # end if
	if ( $params{'project_id'} ) {
		$sql .= ' AND projectindex=?';
		push @values, $params{'project_id'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::QuotedProject::find( $sql)" . $openprint::dbh->errstr);
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("openprint::QuotedProject::find( $sql) : returned " . @$data );
	} # end if
	return map { new openprint::QuotedProject( $_->{id}, $_ ); } @$data;
} # end sub find
sub save {
	my ( $self, $hash ) = @_;

	$self->set( $hash ) if $hash;

	my %sql;
	@sql{@fields{keys %fields}} = @$self{keys %fields};

	my $ac = sql::start_transaction( $dbh );

	if ( ! $$self{'id'} ) {

		@sql{'id'} = @$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('tbl_quote_details_id_seq'::text)} );

		if ( my $e = sql::insert( undef, undef, 'tbl_Quote_Details', \%sql ) ) {
			$openprint::dbh->rollback;
			sql::end_transaction( $dbh, $ac );
			return $e;
		} # end if
	} else {
		if ( my $e = sql::update( undef, undef, 'tbl_Quote_Details', ['id=?', $$self{'id'}], \%sql ) ) {
			$dbh->rollback;
			sql::end_transaction( $dbh, $ac );
			return $e;
		} # end if
	} # end if
	$self->load();
	sql::end_transaction( $dbh, $ac );
	return;
} # eend sub save

sub load {
	my ( $self, $data ) = @_;

	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM tbl_quote_details WHERE id=?}, {}, $$self{'id'} );
	} # end if
	if ( ! $data ) {
		$openprint::log->error("Error loading Project $$self{'id'}: ".$openprint::dbh->errstr() );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
	if ( $debug ) {
		$openprint::log->debug("Loaded values of Quoted Project");
		foreach my $k ( keys %fields ) {
			$openprint::log->debug("$k => $$self{$k}");
		} # end foreach
	} # end if
	return;
} # end sub load

sub delete {
	sql::execute( undef, undef, 'DELETE FROM tbl_quote_details WHERE quote_id=? AND project_id=?', $_[0]{'quote_id'}, $_[0]{'project_id'} );
} # end sub delete

sub template_id {
	if ( @_ > 1 ) {
		$_[0]{'template_id'} = $_[1];
	} # end if
	if ( $_[0]{'template_id'} ) {
		return $_[0]{'template_id'};
	} else {
		return $_[0]->Project()->style_id();
	} # end if
} # end sub template_id

sub Template {
	if ( $_[0]{'template_id'} ) {
		return new openprint::QuoteLevel( $_[0]{'template_id'} );
	} else {
		return $_[0]->Project()->Template();
	} # end if
} # end sub Template

sub Project {
	return new openprint::Project( $_[0]{'project_id'} );
} # end sub Project
sub markup {
	my ( $self, $qty_index, $new_value ) = @_;
	if ( defined $new_value ) {
		$$self{'markup'.$qty_index} = $new_value;
	} # end if
	return $$self{'markup'.$qty_index};
} # end sub total
sub price {
	my ( $self, $qty_index, $new_value ) = @_;
	if ( defined $new_value ) {
		$$self{'price'.$qty_index} = $new_value;
	} # end if
	return $$self{'price'.$qty_index};
} # end sub total
sub quantity {
	my ( $self, $qty_index, $new_value ) = @_;
	if ( defined $new_value ) {
		$$self{'quantity'.$qty_index} = $new_value;
	} # end if
	return $$self{'quantity'.$qty_index};
} # end sub total
1;

__END__
