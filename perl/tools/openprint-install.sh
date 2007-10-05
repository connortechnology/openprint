#!/bin/bash


apt-get install apache2 libapache2-mod-perl2 libapache2-request-perl libapache-session-perl libtext-csv-perl libxml-dom-perl

apt-get install libmail-sendmail-perl
apt-get install libdate-calc-perl libbit-vector-perl libcarp-clan-perl

apt-get libtext-csv-perl
apt-get install libemail-valid-perl libdigest-hmac-perl libdigest-sha1-perl libmailtools-perl libnet-dns-perl libnet-domain-tld-perl libtimedate-perl libcrypt-ssleay-perl
apt-get install libtext-unaccent-perl libauthen-captcha-perl
apt-get install  libdbi-perl libapache-dbi-perl libdbd-pg-perl
apt-get install libxml-libxml-common-perl libxml-libxml-perl libxml-namespacesupport-perl libxml-sax-perl
apt-get install perlmagick libgd-barcode-perl libbarcode-code128-perl
# Also need Barcode-Code128-2.00

ln -sf /etc/apache2/mods-available/rewrite.load   /etc/apache2/mods-enabled/
ln -sf /etc/apache2/mods-available/apreq.load /etc/apache2/mods-enabled/

mkdir /etc/apache2/lib
ln -sf /etc/apache2/lib/perl /var/www/topknotch/perl
