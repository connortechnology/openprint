use strict;
package openprint::Inventory_Check_Entry;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'inventory_check_entries';
$serial= 'inventory_check_entries_id_seq';
%fields = (
	id			=>	'id',
	ic_id		=>	'ic_id',
	skid_id		=>	'skid_id',
	rfidtag_id	=>	'rfidtag_id',
	created_on	=>	'created_on',
	operator_id	=>	'operator_id',
	quantity	=>	'quantity',
	dimension1	=>	'dimension1',
	dimension2	=>	'dimension2',
	notes		=>	'notes',	
);
%transforms = (
	notes	=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	created_on	=>	q`'NOW()'`,
	operator_id	=>	undef,
	skid_id		=>	undef,
	rfidtag_id	=>	undef,
	dimension1	=>	undef,
	dimension2	=>	undef,
	quantity	=>	undef,
);

sub skid_id {
    if ( @_ > 1 ) {
        $_[0]{skid_id} = $_[1] ? $_[1] : undef;
        delete $_[0]{Skid};
    } # end if
    if ( ( ! $_[0]{skid_id} ) and $_[0]{rfidtag_id} and ( ! $_[0]{Skid} ) ) {
        my $Tag = $_[0]->RFIDTag();
        $_[0]{Skid} = $Tag->Skid() if $Tag->skid_id();
    } # end if
    return $_[0]{Skid}->id() if ( ! $_[0]{skid_id} ) and $_[0]{Skid};
    return $_[0]{skid_id};
} # end sub skid_id

sub Skid {
    if ( @_ > 1 ) {
        $_[0]{Skid} = $_[1];
        $_[0]{skid_id} = ref $_[0]{Skid} eq 'openprint::Skid' ? $_[0]{Skid}{id} : undef;
        $_[0]{skid_id} = undef if ! $_[0]{skid_id};
    } # end if
    if ( ! $_[0]{Skid} ) {
        $_[0]{Skid} = new openprint::Skid( $_[0]->skid_id() );
    } # end if
    return $_[0]{Skid};
} # end sub Skid

sub RFIDTag {
    if ( @_ > 1 ) {
        $_[0]{RFIDTag} = $_[1];
        #$_[0]{rfidtag_id} = ref $_[0]{RFIDTag} eq 'openprint::RFIDTag' ? $_[0]{RFIDTag}{id} : undef;
    } # end if
    if ( ! $_[0]{RFIDTag} ) {
        if ( $_[0]{rfidtag_id} ) {
            $_[0]{RFIDTag} = new openprint::RFIDTag( $_[0]->rfidtag_id() );
            if ( ! $_[0]{RFIDTag}->id() ) {
                $_[0]{RFIDTag} = new openprint::RFIDTag();
                $_[0]{RFIDTag}->id( $_[0]->rfidtag_id() );
            } # end if
        } else {
            $_[0]{RFIDTag} = $_[0]->Skid()->RFIDTag();
        } # end if
    } # end if
    return $_[0]{RFIDTag};
} # end sub RFIDTag

sub rfidtag_id {
	if ( @_ > 1 ) {
		$_[0]{rfidtag_id} = $_[1];
	} # end if
	if ( ( ! $_[0]{rfidtag_id} ) and $_[0]{skid_id} ) {
		$_[0]{rfidtag_id} = $_[0]->Skid()->RFIDTag()->id();
	}

	if ( $_[0]{rfidtag_id} and ( length $_[0]{rfidtag_id} < 15 ) ) {
$openprint::log->debug("Formatting: $_[0]{rfidtag_id} to 2" . sprintf('%014d', $_[0]{rfidtag_id} ) );
		$_[0]{rfidtag_id} = '2'.sprintf('%014d', $_[0]{rfidtag_id} );
	}
	
	return $_[0]{rfidtag_id};
}

sub quantity {
	if ( ! $_[0]{quantity} ) {
		my $Skid = $_[0]->Skid();
		if ( $$Skid{id} ) {
			my @C = $Skid->Contents();
			if ( @C ==1 ) {
				if ( $_[0]{dimension2} and $_[0]{dimension1} ) {
				my $Paper = $C[0]->Paper();
				if ( $Paper->type() eq 'Roll' ) {
					$_[0]{quantity} = $_[0]{dimension2} * $_[0]{dimension2} - 9 * $_[0]{dimension1} * 0.37;
				} # end if
				} else {
					$_[0]{quantity} = $C[0]{quantity};
				}
			} # end if only 1 stock
		} # skid was found
	}
	return $_[0]{quantity};
}

1;
__END__
