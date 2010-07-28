package openprint::QuotedProject;
@ISA = qw(openprint::Project);

use strict;
use openprint ();
use vars qw( $debug $log $dbh %session %config $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
*config = \%openprint::config;

require sql;
require openprint::QuoteLevel;

$debug = 1;

$table = 'tbl_quote_details';
$serial = 'tbl_quote_details_id_seq';
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
			'project_id'		=>	'project_id',
			'quote_id'			=>	'quote_id',
);

%transforms = (
	
);

%defaults = (
	'id'	=> undef,
	'markup1'	=> undef,
	'markup2'	=> undef,
	'markup3'	=> undef,
	'price1'	=> undef,
	'price2'	=> undef,
	'price3'	=> undef,
);

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
	if ( ! (1*$$self{'price'.$qty_index}) ) {
		$$self{'price'.$qty_index} = sprintf('%.2f', $self->Project()->price($qty_index) * ( 1 + $$self{'markup'}/100 ) );
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
