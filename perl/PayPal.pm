package PayPal;

use strict;
use LWP::UserAgent;
use openprint;
use URI::Escape qw( uri_escape );

sub new {
    my $pkg=shift;
    my %params=@_;
    my $self = bless({}, $pkg);
    
    $self->{debug}=0;
    $self->{service}{url}='https://api-3t.sandbox.paypal.com/nvp';
    #$self->{service}{url}='https://api-3t.sandbox.paypal.com/2.0';
    $self->{service}{timeout}=10;    
    $self->{api}{VERSION}='51.0';
    
    $self->{debug}=$params{debug} if ($params{debug});
    $self->{service}{url}=$params{service_url} if ($params{service_url});
    $self->{service}{timeout}=$params{service_timeout} if ($params{service_timeout});

    foreach my $key (keys %params) {
        next if ($key!~m!^api_(.+)$!);
        $self->{api}{$1}=$params{$key};
    } # end foreach

    return $self;
}

sub Call_Service {
    my $self=shift;
    my ($req)=@_;

    my %req=%{$req};
    my %res=();
    
    my %params=(%{$self->{api}},%req); 
foreach my $k ( keys %params ) {
$params{$k} = uri_escape( $params{$k} );
#$params{$k} = uri_escape( $params{$k} ) if $k ne 'RETURNURL' and $k ne 'CANCELURL';
$openprint::log->debug("$k => $params{$k}");
} # end foreach
$openprint::log->debug( join('&', map { "$_=$params{$_}" } keys %params ) );
    my $ua=LWP::UserAgent->new;
    $ua->timeout($self->{service}{timeout});    
    my $uares=$ua->post($self->{service}{url},\%params);
    
    if ($uares->is_success) {
        warn "\nDEBUG: HTTP response:\n".$uares->content."\n\n" if ($self->{debug});    
        my $count = 0;
        my @pairs=split(/&/,$uares->content);
        foreach my $pair (@pairs) {
            my ($name,$value)=split(/=/,$pair);
            $value=~tr/+/ /;
            $value=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
            $name=lc($name);
            $res{$name}=$value;
            $count++;
        }
    } else {
        warn "\nDEBUG: HTTP error:\n".$uares->status_line."\n\n" if ($self->{debug});
        $res{ack}='Failure';
        $res{l_errorcode0}=$uares->code;
        $res{l_shortmessage0}="HTTP error: ".$uares->message;
        $res{l_longmessage0}="HTTP error: ".$uares->code." ".$uares->message;
        $res{l_severitycode0}='Error';
    }
    
    return \%res;
}

sub Parse_Errors {
    my $self=shift;
    my ($res)=@_;

    my %res=%{$res};
    
    my %errors=();
    foreach my $key (keys %res) {
        if ($key=~m!^l_(.+[^\d]+)(\d+)$!) {
            my $name=$1;
            my $id=$2;
            $errors{$id}{$name}=$res{$key};
        } 
    }
    
    my @errors=();
    foreach my $id (sort { $a <=> $b } keys %errors) {
        push(@errors,$errors{$id});
    }
    
    return @errors;
}

1;

__END__

