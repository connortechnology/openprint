#!/bin/bash


apt-get -y install make postgresql
apt-get -y install apache2 libapache2-mod-perl2 libapache2-request-perl libapache-session-perl libtext-csv-perl libxml-dom-perl

apt-get -y install libmail-sendmail-perl
apt-get -y install libdate-calc-perl libbit-vector-perl libcarp-clan-perl

apt-get -y libtext-csv-perl
apt-get -y install libemail-valid-perl libdigest-hmac-perl libdigest-sha1-perl libmailtools-perl libnet-dns-perl libnet-domain-tld-perl libtimedate-perl libcrypt-ssleay-perl
apt-get -y install libtext-unaccent-perl libauthen-captcha-perl
apt-get -y install  libdbi-perl libapache-dbi-perl libdbd-pg-perl
apt-get -f -y install libxml-libxml-common-perl libxml-libxml-perl libxml-namespacesupport-perl libxml-sax-perl
apt-get -f -y --force-yes install perlmagick libgd-barcode-perl 
apt-get -f -y --force-yes install  libbarcode-code128-perl
# Also need Barcode-Code128-2.00

ln -sf /etc/apache2/mods-available/rewrite.load   /etc/apache2/mods-enabled/
ln -sf /etc/apache2/mods-available/apreq.load /etc/apache2/mods-enabled/

mkdir /etc/apache2/lib
ln -sf /etc/apache2/lib/perl /var/www/$1/perl

perl -MCPAN -e shell << EOF
force install Date::Handler
force install Date::Handler
force install Math::Units
force install Barcode::Code128
EOF
