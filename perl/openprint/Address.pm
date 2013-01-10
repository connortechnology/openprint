use strict;
package openprint::Address;
our @ISA = qw( openprint::Object );

use vars qw( $table $serial %fields %transforms %defaults );

$table = 'tbl_addresses';
$serial = 'Address_Index_seq';
%fields = (
		id				=>	'lngindex',
		company_id		=>	'company_id',
		companyname	=>	'strCompanyName', 
		firstname	 =>	'strFirstName', 
		lastname		=>	'strLastName', 
		salutation	=>	'strSalutation',
		address1		=>	'strAddress1', 
		address2		=>	'strAddress2', 
		city			=>	'strCity', 
		state =>	'strStateProvince', 
		postalcode	=>	'strPostalCode', 
		country		=>	'strCountry', 
		phone		=>	'strPhone', 
		extension	 =>	'strExtension', 
		fax			=>	'strFax',
		email			=>	'strEmail',
		); # end %fields


sub to_string {
	return join( ' ', $_[0]->firstname(), $_[0]->lastname() ) . ' @ ' . join(',', (
		( $_[0]->address1() ? $_[0]->address1() : () )
		( $_[0]->address2() ? $_[0]->address2() : () )
		( $_[0]->city() ? $_[0]->city() : () )
		( $_[0]->state() ? $_[0]->state() : () )
		( $_[0]->country() ? $_[0]->country() : () )
		) );
} # end sub to_string

1;
__END__
