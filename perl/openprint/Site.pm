use strict;
package openprint::Site;
our @ISA = qw( openprint::Object );
require openprint::Object;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'sites';
$serial = 'sites_id_seq';

%fields = (
	id	        =>	'id',
	company_id	=>	'company_id',
	name      	=>	'name',
  created_on  => 'created_on',
  updated_on  => 'updated_on',
  deleted     => 'deleted',
);
%transforms = (
	name							=>	[ 's/[\.\,]//g', 's/^\s+//', 's/\s+$//','s/\///g' ],
);
%defaults = (
	created_on			=>	q`'NOW()'`,
	updated_on			=>	q`'NOW()'`,
  deleted         =>  0,
);

sub Host_Sites {
  my $self = shift;
  if (@_) {
    $$self{Host_Sites} = shift;
  }
  if (!$$self{Host_Sites}) {
    if ($$self{id}) {
      $$self{Host_Sites} = [ openprint::Host_Site->find(site_id=>$$self{id}) ];
    } else {
      $$self{Host_Sites} = [];
    }
  }
  return @{$$self{Host_Sites}} if wantarray;
  return $$self{Host_Sites};
}

sub Hosts {
  my $self = shift;
  if (@_) {
    $$self{Hosts} = shift;
  }
  if (!$$self{Hosts}) {
    if ($$self{id}) {
      $$self{Hosts} = [ openprint::Host->find(id=>map { $$_{host_id} } $self->Host_Sites()) ];
    } else {
      $$self{Hosts} = [];
    }
  }
  return @{$$self{Hosts}} if wantarray;
  return $$self{Hosts};
}

1;
__END__
