use strict;
require JSON::RPC::Client;
require Data::Dumper;

require openprint::Object_Type;
package openprint::Bitcoin_Address;
our @ISA = qw(openprint::Object);
use vars qw( $debug $table $serial %fields %find_fields %defaults %transforms );

$debug = 1;
$table = 'bitcoin_addresses';
$serial = 'bitcoin_addresses_id_seq';
%fields = (
	id				=>	'id',
	object_type_id	=>	'object_type_id',
	object_type		=>	undef,
	object_id		=>	'object_id',
	address			=>	'address',
);
%find_fields = (
	object_type	=>	'(SELECT name FROM object_types WHERE id=object_type_id)',
);
%defaults = (
	created_on	=>	q`'NOW()'`,
	deleted		=>	0,
	approved	=>	0,
	user_id		=>	q`$session{user_id}`,
	approved	=>	0,
);

sub generate {

	my $ac = sql::start_transaction( $openprint::dbh );
	$openprint::dbh->do( "LOCK TABLE $table IN ACCESS EXCLUSIVE MODE" ) or $openprint::log->error( DBI->errstr );
	my $New = openprint::Bitcoin_Address->find_one('object_id is null'=>1);
	if ( ! $New ) {
		my $client = new JSON::RPC::Client;

		$client->ua->credentials(
				($openprint::config{bitcoin_server} ? $openprint::config{bitcoin_server} : 'localhost').':'.
				($openprint::config{bitcoin_port} ? $openprint::config{bitcoin_port} : '8332'),
				, $openprint::config{bitcoin_user}, $openprint::config{bitcoin_password} 
				);

		my $uri = 'http://'.($openprint::config{bitcoin_server} ? $openprint::config{bitcoin_server} : 'localhost').':'.
                ($openprint::config{bitcoin_port} ? $openprint::config{bitcoin_port} : '8332').'/';
		my $obj = {
			method  => 'getnewaddress',
			params  => {
				account	=>	$openprint::config{getnewaddress},
			},
		};
$openprint::log->debug("Asking bitcon for a new addres $uri");

		my $res = $client->call( $uri, $obj );

		if ( $res ) {
			if ( $res->is_error ) {
				$openprint::log->error( "Error : ", $res->error_message );
			} else {
				$openprint::log->debug( Data::Dumper::Dumper($res->result) );
			}
		} else {
			$openprint::log->debug( $client->status_line );
		}
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub generate
1;
__END__
