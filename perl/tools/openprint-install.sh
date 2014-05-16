#!/bin/bash

apt-get -y install lm-sensors sensord smartmontools liblinux-inotify2-perl libdigest-md5-file-perl apache2 libapache2-mod-perl2 libapache2-request-perl libapache-session-perl libtext-csv-perl libxml-dom-perl libbsd-resource-perl apache2-mpm-prefork libxml-libxml-perl libyaml-perl libmath-calc-units-perl libxml-rss-perl libjson-rpc-perl libio-interface-perl libhtml-linkextractor-perl liblingua-en-inflect-perl libxml-rss-perl libhtml-format-perl  libgeo-distance-xs-perl libgeo-coder-googlev3-perl libimage-size-perl libgeo-ip-perl libemail-valid-perl libnet-twitter-lite-perl libipc-run3-perl libhtml-strip-perl libjson-rpc-perl libjavascript-minifier-xs-perl libfile-slurp-perl libcss-minifier-perl libauthen-passphrase-perl libfile-slurp-perl libtext-unidecode-perl

apt-get -y install libmail-sendmail-perl libjson-perl libjson-xs-perl libdate-calc-perl libbit-vector-perl libcarp-clan-perl libtext-csv-perl libdatetime-format-duration-perl libdatetime-format-pg-perl libdatetime-perl libemail-valid-perl libdigest-hmac-perl libmailtools-perl libnet-dns-perl libnet-domain-tld-perl libtimedate-perl libcrypt-ssleay-perl libtext-unaccent-perl libauthen-captcha-perl libdbi-perl libapache-dbi-perl libdbd-pg-perl libunicode-string-perl libsoap-lite-perl libxml-namespacesupport-perl libxml-sax-perl libmath-round-perl libnet-server-perl perlmagick libgd-barcode-perl libnumber-format-perl libbarcode-code128-perl liblinux-inotify2-perl libnet-arp-perl libchart-clicker-perl
# Also need Barcode-Code128-2.00
apt-get -y install jpegoptim pngcrush graphicsmagick imagemagick libgeo-ip-perl
apt-get -y install libav-tools
apt-get -y install ffmpeg

# FOr db servers:
#apt-get -y install postgresql

#ln -sf /etc/apache2/mods-available/rewrite.load   /etc/apache2/mods-enabled/
#ln -sf /etc/apache2/mods-available/apreq.load /etc/apache2/mods-enabled/

#mkdir /etc/apache2/lib
#rm /etc/apache2/lib/perl
#ln -sf /var/www/testing/perl /etc/apache2/lib/perl

#echo "PerlRequire      startup.pl" >> /etc/apache2/conf.d/perl
#echo "APREQ2_ReadLimit 1024M" >> /etc/apache2/conf.d/perl

#perl -MCPAN -e shell << EOF
#force install File::HashCache::JavaScript
#EOF
#force install Date::Handler
#force install Date::Parse
#force install Business::PayPal

