use strict;
package openprint::SRED_Content;
our @ISA = qw(openprint::Object);
require openprint::Object;
require openprint::SRED_Asset;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'sred_contents';
$serial = 'sred_contents_id_seq';

%fields = (
	'id'			=>	'id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'starting'			=>	'starting',
	'ending'			=>	'ending',
	'project_id'		=>	'project_id',
	'description'		=>	'description',
	'unknown_time'		=>	'unknown_time',
	'all_day_event'		=>	'all_day_event',
	'user_id'			=>	'user_id',
	'deleted'			=> 'deleted',

);

%transforms = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'name' => [ 's/^\s+//', 's/\s+$//' ],
);

%defaults = (
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'deleted'		=> 0,
	'project_id'	=>	undef,
	'user_id'		=>	undef,
	'unknown_time'	=>	1,
	'all_day_event'	=>	0,
);

sub duration {
	if ( @_ > 1 ) {
		$_[0]{'duration'} = $_[1];
		$_[0]->Duration( undef );
	} # end if
	if ( ( ! $_[0]{'duration'} ) and ( $_[0]{'unknown_time'} ) ) {
		if ( $_[0]{'all_day_event'} ) {
			return Date::Parse::str2time( $_[0]{'ending'} ) - Date::Parse::str2time( $_[0]{'starting'} );
		} else {
			my ($start) = $_[0]{'starting'} =~ /(\d\d\d\d-\d\d-\d\d)/;
			my ($end) = $_[0]{'ending'} =~ /(\d\d\d\d-\d\d-\d\d)/;
			return Date::Parse::str2time( $end ) - Date::Parse::str2time( $start );
		} # end if
	} # end if
} # end sub duration

sub duration_days {
	my $parser = 'DateTime::Format::Pg';
	my $duration = $parser->parse_interval( $_[0]{'duration'} );
	return $duration->days();
} # end sub duration_days

sub duration_hours {
	my $parser = 'DateTime::Format::Pg';
	my $duration = $parser->parse_interval( $_[0]{'duration'} );
	return $duration->hours();
} # end sub duration_hours
sub duration_minutes {
	my $parser = 'DateTime::Format::Pg';
	my $duration = $parser->parse_interval( $_[0]{'duration'} );
	return $duration->minutes();
} # end sub duration_minutes

sub Duration {
	if ( @_ > 1 ) {
		$_[0]{'Duration'} = $_[1];
	} # end if
	if ( ! $_[0]{'Duration'} ) {
		my $parser = 'DateTime::Format::Pg';
		$_[0]{'Duration'} = $parser->parse_interval( $_[0]{'duration'} );
	} # end if
	return $_[0]{'Duration'};
} # end sub Duration

sub Assets {
	my $self = shift;
	my %params = @_;
	$params{'content_id'} = $$self{'id'};
	return openprint::SRED_Asset->find(%params);
} # end sub Assets

1;
__END__
