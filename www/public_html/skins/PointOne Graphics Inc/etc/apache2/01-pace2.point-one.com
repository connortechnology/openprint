<VirtualHost *:80>
    ServerAdmin     iconnor@point-one.com
    DocumentRoot    /var/www/point-one/www/public_html
    ServerName      pace2.point-one.com
    RewriteEngine on
    RewriteRule ^/(.*) http://192.168.1.132/$1 [P]
    ErrorLog        /var/log/apache2/point-one.com/pace2.log
    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>
</VirtualHost>
