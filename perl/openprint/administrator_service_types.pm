package openprint::administrator_service_types;

use strict;
use openprint ();

require sql;
require openprint::logs;

use vars qw( $log $dbh %variable %param );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;

sub edit {

	my $ServiceType = new openprint::ServiceType( $param{ServiceType_id} );

	if ( $param{'btnFunction'} eq '<<' ) {
		$ServiceType = $ServiceType->Prev();
	} elsif ( $param{'btnFunction'} eq '>>' ) {
		$ServiceType = $ServiceType->Next();
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$ServiceType->delete();
		$ServiceType = $ServiceType->Next();
		openprint::logs::insertLogRecord('23',sprintf('Service Type: %d - %s', $ServiceType->id(), $ServiceType->name() ) );
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} = $ServiceType->save( \%param );
		my $ac = sql::start_transaction( $dbh );
        foreach my $key ( keys %param ) {
            if ( $key =~ /^name\-(.*)$/ ) {
				my $SD = new openprint::ServiceType_Default( $1 );
				if ( $param{"name\-$1"} ne '' ) {
					$SD->save({
						'projecttype_id'	=>	$param{'projecttype_id-'.$$SD{'id'}},
						'name'				=>	$param{'name-'.$$SD{'id'}},
						'value'				=>	$param{'value-'.$$SD{'id'}},
						}) if (
							( $SD->projecttype_id() != $param{'projecttype_id-'.$$SD{'id'}} ) and
							( $SD->name() != $param{'name-'.$$SD{'id'}} ) and
							( $SD->value() != $param{'value-'.$$SD{'id'}} )
							);
				} else {
					$variable{'error'} .= $SD->delete();
				} # end if
            } # end if
        } # end foreach
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		my $New = $ServiceType->copy();
        
        if ( $_ = $New->save({'name'=>'Copy of' . $New->name()}) ) {
			$variable{'error'} = $_;
		} else {
			foreach my $Default ( $ServiceType->Defaults() ) {
				$Default = $Default->copy();
				$variable{'error'} .= $Default->save({'servicetype_id'=>$New->id()});
				last if $variable{'error'};
			} # end foreach Default
			$ServiceType = $New;
		} # end if
	} # end if

	$variable{'ServiceType'} = $ServiceType;
} # end sub types_edit

1;
__END__
