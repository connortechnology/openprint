<VirtualHost *:80>
    ServerAdmin     iconnor@point-one.com
    DocumentRoot    /var/www/point-one/www/public_html
    ServerName      pace1.point-one.com
    RewriteEngine on
    RewriteRule ^/(.*) http://192.168.1.131/$1 [P]
    ErrorLog        /var/log/apache2/point-one.com/pace1.log
    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>
</VirtualHost>
