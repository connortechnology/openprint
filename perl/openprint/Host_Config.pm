use strict;
use warnings;

require openprint::Object;

require JSON;

package openprint::Host_Config;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'host_config';
$serial = 'host_config_id_seq';

%fields = (
	id					=>	'id',
  host_id     =>  'host_id',
	name				=>	'name',
	data_json	=>	'data_json',
	created_on	=>	'created_on',
);
%defaults = (
  created_on  =>  q`'NOW()'`,
  updated_on  =>  q`'NOW()'`,
);


sub data_json {
	my $self = shift;
	if ( @_ ) {
		if ( ref $_[0] eq 'HASH' ) {
			$$self{data} = $_[0];
			$$self{data_json} = JSON::encode_json($_[0]);
		} else {
			$$self{data_json} = $_[0];
		}
	}
	return $$self{data_json};
}

sub data {
	my $self = shift;
	if ( @_ ) {
		$$self{data} = $_[0];
		$$self{data_json} = JSON::encode_json($_[0]);
	}
	if ( !$$self{data} ) {
		if ( $$self{data_json} ) {
$openprint::log->debug("Decodeing $$self{data_json}");
			$$self{data} = JSON::decode_json($$self{data_json});
		} else {
			$openprint::log->warn("No data_json in data()");
		}
	}
	return $$self{data};
}

1;
__END__
