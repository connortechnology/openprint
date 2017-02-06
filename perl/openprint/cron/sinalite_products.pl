#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use 5.10.0;
use utf8;

# INCLUDES
use strict;
use WWW::Mechanize;
use CGI qw/:standard/;
use HTML::TreeBuilder;
use JSON;

use Data::Dumper;
require configuration;
require sql;
require ssi;
require misc;
require openprint::Company;
require openprint::User;
require Email::Valid;
require openprint::Email;
require logger;
require openprint::Wall;
require Date::Parse;
require Date::Format;
require openprint;
require openprint::Product;
require openprint::Product_Category;
require openprint::Object_Specification;
require openprint::Pricelist;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use File::Basename qw(basename);
use Getopt::Long;
use Mail::Sendmail;
use MIME::QuotedPrint;
use Time::HiRes qw(usleep);
use Encode qw(encode);

my $program = basename($0);

my @args = @ARGV;

my $opts = {};
GetOptions($opts, 'help', 'log_file=s', 'log_level=s', 'markup=s',
	'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'db_port=s',
 );

if ($opts->{help}) {
	usage();
	exit 0;
}

$log = new logger( {level=>'debug'});
# Get our configuration information
configuration::from_file("/etc/openprint/$program.conf");
configuration::merge( $opts );
$log->level($config{log_level}) if $config{log_level};

# Declare variables
foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param
$openprint::dbh = sql::open_sql( $log, 
	host		=> $config{db_host},
	port		=> $config{db_port},
	database	=> $config{db_name},
	driver	=> 'Pg',
	login		=> $config{db_user},
	password	=> $config{db_pass},
);
die 'Error opening db' if ! $dbh;
configuration::init();
configuration::merge( $opts );

my $Pricelist = openprint::Pricelist->find_one(name=>'default');

my $input;
my $host = 'https://sinalite.com';

my $mech = WWW::Mechanize->new();
$mech->get($host.'/en_ca/customer/account/login');

$mech->submit_form(
        form_id => 'login-form',
        fields    => { 
			'login[password]'		=>	'pakistan',
			'login[username]'		=>	'imran@muizgraphics.com',
		},
		button	=>	'send',
    );
#print $mech->content();
print "Getting $host/en_ca/all-products.html\n";
$mech->get($host.'/en_ca/all-products.html');
#print $mech->content();
print "parsing...";
my $tree = HTML::TreeBuilder->new;
$tree->parse_content($mech->content());
$tree->elementify();
print "done\n";
foreach my $category ( $tree->look_down('class','all-products') ) {
	#$category->dump();
	my $product_name_h2 = $category->look_down('class','product-name');
	my $product_name_a = $product_name_h2->look_down(_tag=>'a');
	my $url = $product_name_a->attr_get_i('href');
	print "$url \n";
	print $product_name_a->as_text()."\n";

	$mech->get($url);
	my $product_tree = HTML::TreeBuilder->new;
	$product_tree->parse_content( $mech->content() );
	$product_tree->elementify();

	my $first_div = $product_tree->look_down(id=>'firstDiv');
	my $header = $first_div->look_down(id=>'product-header');
	my $name = $header->look_down(_tag=>'h1')->as_text();

	
	my ( $type_p, $description_p ) = $first_div->look_down(_tag=>'p');
	my $type = $type_p->as_text() if $type_p;
	my $description = $description_p->as_text() if $description_p;

	my $Category = openprint::Product_Category->find_one( name=>$name );
	if ( ! $Category ) {
		$Category = new openprint::Product_Category();
		$Category->save({name=>$name, description=>$description });
	} else {
		if ( $Category->description() ne $Category->transform(description=>$description) ) {
			print "Update description from\n$$Category{description}\n\nto\n\n$description\n? (Y/n)";
			$input = <STDIN>;
			chomp $input;
			if ( $input eq 'Y' or $input eq '' ) {
				$Category->save({description=>$description});
			}
		}
	}
	my %category_specs = map { $$_{name} => $_ } $Category->Specifications();

	foreach my $spec ( $first_div->look_down(id=>'product-spec') ) {
		my $title_div = $spec->look_down(id=>'spec-title');
		my $title = Encode::encode('utf-8', $title_div->look_down(_tag=>'p')->as_text() );
		my $value_div = $spec->look_down(id=>'spec-info');
		if ( ! $value_div ) {
			print "No value_div for $title\n";
			next;
		}
		my $value_p = $value_div->look_down(_tag=>'p');
		my $value;
		if ( ! $value_p ) {
			print "No value_p for $title\n";
			$value = $value_div->as_HTML();
		} else {
			my $p = $value_div->look_down(_tag=>'p');	
			$value = $p->as_HTML();
		}
		$value =~ s/”/"/g;
		$value = Encode::encode('utf-8', $value );
		$title = openprint::Object_Specification->transform(name=>$title);
		$value = openprint::Object_Specification->transform(value=>$value);

		my $Spec;
		if ( ! $category_specs{$title} ) {
			print "add specification $title = $value ? (Y|n)";
			$input = <STDIN>;
            chomp $input;
            if ( $input eq 'Y' or $input eq '' ) {
				my $Spec = new openprint::Object_Specification();
				$Spec->save({ Object=>$Category, name=>$title, value=>$value });
				$category_specs{$title} = $Spec;
            }
		} else {
			$Spec = $category_specs{$title};
			if ( $$Spec{value} ne $value ) {
				print "Change specification $title from\n\n$$Spec{value}\n\nto\n\n$value\n\n ? (Y|n)";
				$input = <STDIN>;
				chomp $input;
				if ( $input eq 'Y' or $input eq '' ) {
					$Spec->save({ value=>$value });
					$category_specs{$title} = $Spec;
				}
			}
		}
	} # end foreach spce

	my $second_div = $product_tree->look_down(id=>'secondDiv');
	my $product_container = $product_tree->look_down(id=>'productContainer');
	if ( ! $product_container ) {
		print "No product_container\n";
		print $second_div->as_HTML();
		next;
	}
	my $objData;
	foreach my $script ( $product_tree->look_down(_tag=>'script') ) {
		my $text = $script->as_HTML();
		if ( $text =~ /var objData=([^;]+);'/ ) {
			$objData = decode_json( $1 );
			last;
		}
	} # end foreach script
	if ( $objData ) {
		print Data::Dumper::Dumper( $objData ) . "\n";
	} else {
		print "No objData\n";
	}
	foreach my $type ( keys %{$objData} ) {
		my $blah = $$objData{$type};

		my $fields = $$blah{fields};
		my $product = $$fields{Product};

		foreach my $name_key ( keys %{$product} ) {
			$name_key =~ /Product_(.*)/;
			my $name = $1;
			
			my $option_hash = $$product{$name_key};

			foreach my $option ( keys %{$option_hash} ) {
			
				print "Option $option\n";
				if ( $option eq 'size' ) {
					foreach my $size_key ( keys %{$$option_hash{$option}} ) {
						my ( $size ) = $size_key =~ /size_(.*)/;
						
						my $product_name = join(' ', $name, $size );;
						my $Product = openprint::Product->find_one( name=>$product_name );
						if ( ! $Product ) {
							print "Add Product $product_name ? (Y|n)";
							$input = <STDIN>;
							chomp $input;
							if ( $input eq 'Y' or $input eq '' ) {
								$Product = new openprint::Product();
								$Product->save({name=>$product_name, description=>$product_name, category_id=>$Category->id() });
							} else {
								next;
							}
						} # end if ! Product 
						my %product_specs = map {$$_{name} => $_} $Product->Specifications();
						my %product_prices = map { $$_{min} => $_ } $Product->Prices();
						my $units = $$option_hash{$option}{$size_key}{eachorlot};

						my $qty_hash = $$option_hash{$option}{$size_key}{qty};
						foreach my $qty_key ( keys %{$qty_hash} ) {
							next if $qty_key eq 'eachorlot';
							my ( $qty ) = $qty_key =~ /qty_(\d+)/;
print "qty_key $qty_key $qty\n";
							my $Price;
							my $cost = $$qty_hash{$qty_key};

							if ( ! $product_prices{$qty} ) {
	
								print "Add Price for $qty $units $cost on $product_name ? (Y|n)";
								$input = <STDIN>;
								chomp $input;
								if ( $input eq 'Y' or $input eq '' ) {
									$Price = new openprint::ProductPrice();
									$Price->save({product_id=>$Product->id(), min=>$qty, max=>$qty, units=>$units, cost=>$cost, pricelist_id=>$$Pricelist{id}, owner_id=>$config{owner_id} });
								} else {
									next;
								}
							} else {
								$Price = $product_prices{$qty};
								if ( $$Price{cost} != $cost ) {
									print "Price has changed $product_name for $qty from $$Price{cost}$$Price{units} to $cost $units Update? (Y|n)";
									$input = <STDIN>;
									chomp $input;
									if ( $input eq 'Y' or $input eq '' ) {
										$Price->save({ units=>$units, cost=>$cost });
									}
								}

							} # end if no prices
							
						} # end foreach qty_key
					} # end foreach size_key
				} # end if size
			}  # end foreach option

		} # end foreach product_type
	} # end foreach product_name
	print "Hit enter to continue...";
	$input = <STDIN>;

} # end foreach post


1;
__END__
