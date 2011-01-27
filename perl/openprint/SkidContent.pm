package openprint::SkidContent;
@ISA = qw(openprint::Object);

use strict;

require sql;
use vars qw( $log $dbh $debug %fields %transforms %defaults $table $serial );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$debug = 0;

%fields = (
	'id'			=>	'id',
	'skid_id'		=>	'skid_id',
	'paper_id'		=>	'paper_id',
	'quantity'		=>	'quantity',
	'purpose_id'	=>	'purpose_id',
	'units'			=>	'units',
	'quality_id'	=>	'quality_id',
);
%defaults = (
	'purpose_id'	=>	undef,
	'quality_id'	=>	undef,
);
%transforms = (
);
$table = 'Skid_Contents';
$serial = 'skid_contents_id_seq';

sub purpose {
	my $self = shift;
	return $self->Purpose()->name();
} # end sub purpose

sub Purpose {
	my $self = shift;
	my $Purpose = new openprint::StockPurpose( $$self{'purpose_id'} );
	return $Purpose;
} # end sub Purpose

sub Paper {
	my $self = shift;
	my $Paper = new openprint::Paper( $$self{'paper_id'} );
	return $Paper;
} # end sub Paper

sub Skid {
	return new openprint::Skid( $_[0]{'skid_id'} );
} # end sub Skid
sub delete {
	my $self = $_[0];
	my $error = $self->SUPER::delete();
	if ( !$error ) {
		$self->Paper()->save();
	} # end if
} # end sub delete
sub allocateable {
    my ( $self ) = @_;
    return $self->quantity() - $self->allocation();
} # end sub allocateable
sub allocated {
	my $PA = openprint::PaperAllocation->find_one('paper_id'=>$_[0]{'paper_id'},'skid_id'=>$_[0]{'skid_id'});
	return $PA->quantity() if $PA;
	return 0;
} # end sub allocated

sub quality {
    my ( $self, $quality ) = @_;

    if ( defined $quality ) {
		$quality =~ s/^\s+//;
		$quality =~ s/\s+$//;
		$quality =~ s/\s\s+$/ /;
        @$self{'quality_id','quality'} = sql::execute( undef, undef, q{SELECT id, longname FROM PaperQualities WHERE lower(longname)=?}, lc $quality );
        if ( ! $$self{'quality_id'} ) {
			$$self{'quality'} = $quality;
        } # end if
    } elsif ( $$self{'quality_id'} and ! $$self{'quality'} ) {
        $$self{'quality'} = new openprint::StockQuality( $$self{'quality_id'} )->longname();
    } # end if
    return $$self{'quality'};
} # end sub quality

# Looks to find a PO matching this stock and pulls the value from it.
sub cost {
	my $self = $_[0];
	my $MC = openprint::ManifestContent->find_one('skid_id'=>$$self{'skid_id'},'paper_id'=>$$self{'paper_id'});
	if ( ! $MC ) {
		#$log->debug("No Manifest Content found for skid_id $$self{'skid_id'}, paper_id $$self{'paper_id'}");
		return;
	} # end if
	if ( ! $MC->Type()->po_id() ) {
		#$log->debug("No Po_id skid_id $$self{'skid_id'}, paper_id $$self{'paper_id'}");
		return;
	} # end if
 if ( $MC->cost() ) {
#$log->debug("Returning cost from Manifest");
	return $MC->cost();
	} # end if
#$log->debug("Returning cost from PO");
	return $MC->Type()->cost_from_po();
} # end sub cost

1;
__END__
