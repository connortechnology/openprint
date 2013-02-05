use strict;
package openprint::Operator_Shift;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

require ssi;
require misc;
require openprint::User;
require openprint::Equipment_Shift;

$debug = 0;

$table = 'operator_shifts';
$serial = 'operator_shifts_id_seq';

%fields = (
	'id'			=>	'id',
	'equipment_id'	=>	'equipment_id',
	'operator_id'	=>	'operator_id',
	'shift_id'		=>	'shift_id',
	'starttime'		=>	'starttime',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
	'shift_id'		=>	[ 's/\D//g' ],
	'equipment_id'	=>	[ 's/\D//g' ],
	'operator_id'	=>	[ 's/\D//g' ],
);

%defaults = (
);

sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment

sub get_li {
    my ( $self, $ul_id ) = @_;

# a 12hour shift ~= 600px, so each hour gets 50px;

    my $html;
	$html .= sprintf( '<li id="item_%d">', $$self{'id'} );
	$html .= '<span class="Buttons">';
	$html .= ssi::button( 'Remove'.$$self{'id'}, { onclick=> "if(confirm('Are you sure?')){f1.schedule_id.value=$$self{'id'};f1.btnFunction.value='RemoveJob';f1.submit();}", text=>'D', title=>'Delete' );
	$html .= '</span>';

	$html .= "<br/></li>\n";
	return $html;
} # end sub get_li

sub Shift {
	return new openprint::Equipment_Shift( $_[0]{'shift_id'} );
} # end sub Shift

sub starttime_seconds {
	return misc::hms2time( $_[0]{'starttime'} );
} # end sub starttime_seconds

sub duration_seconds {
	return $_[0]->Shift()->duration_seconds();
} # end sub duration_seconds

sub Operator {
	return new openprint::User( $_[0]{'operator_id'} );
} # end sub Operator

1;
#__END__
