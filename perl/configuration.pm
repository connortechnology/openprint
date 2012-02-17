use strict;
package configuration;

require openprint;
use vars qw( %cache );

require sql;

*cache = \%openprint::config;

sub init_cache {
	
	if ( $openprint::dbh ) {
		#my $data = $openprint::dbh->selectall_arrayref( 'SELECT Name, Value FROM Configuration' );
		my $data = $openprint::dbh->selectall_arrayref( 'SELECT name, value FROM Configuration', {Slice=>{}} );
		#%cache = @{$data};
		foreach (@{$data}) {
			$cache{$$_{name}} = $$_{value};
		} # end foreach
	} else {
		%cache = ();
	} # end if
	
	# Anything specified in dir_config override configuration
	if ( @_ ) {
		@cache{ keys %{$_[0]}} = values %{$_[0]};
	} # end if
	#return %cache;
}

sub get_values {
	my ( $log, $dbh, @names ) = @_;

	$_ = "SELECT Name, Value FROM Configuration WHERE Name IN ('".join("','", @names ) ."')";
	my %results = sql::execute( $log, $dbh, $_ );
	return @results{@names};

} # end sub get_values 

sub get_entry {
	my ( $log, $dbh, $name ) = @_;

	return sql::execute( $log, $dbh, 'SELECT Name, Value FROM Configuration WHERE Name=?', $name );
} # end sub get_entry

sub save_entry {
	my ( $log, $dbh, $name, $value ) = @_;

	my %entry = get_entry( $log, $dbh, $name );
	if ( %entry ) {
		if ( $entry{$name} ne $value ) {
			update_entry( $log, $dbh, $name, $value );
		} # end if
	} else {
		insert_entry( $log, $dbh, $name, $value );
	} # end if
} # end sub save_entry

sub insert_entry {
	my ( $log, $dbh, $name, $value ) = @_;
	$name =~ s/^\s*(.*?)\s*$/$1/;
	$value =~ s/^\s*(.*?)\s*$/$1/;
	sql::insert( $log, $dbh, 'Configuration', 'Name', $name, 'Value', $value ); 
	$cache{$name} = $value;
} # end sub insert_entry

sub update_entry {
	my ( $log, $dbh, $name, $value ) = @_;
	
	$name =~ s/^\s*(.*?)\s*$/$1/;
	$value =~ s/^\s*(.*?)\s*$/$1/;
	sql::update( $log, $dbh, 'Configuration', ['Name=?', $name], 'Value', $value );
	$cache{$name} = $value;
} # end sub update_entry

sub save_config {
}

sub get_config {
	my ( $log, $dbh ) = @_;
   
	my %config = sql::execute( $log, $dbh, 'SELECT Name, Value FROM Configuration' );
	return \%config;
} # end sub get_config

1;
__END__
