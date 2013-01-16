<VirtualHost *:80>
    ServerAdmin     iconnor@point-one.com
    DocumentRoot    /var/www/point-one/www/public_html
    ServerName      insite.point-one.com
    ServerAlias     insight.point-one.com
    ServerAlias     softproof.point-one.com
    ServerAlias     ins.point-one.com
    RewriteEngine on
    RewriteRule ^/(.*) http://192.168.1.143/$1 [P]
    ErrorLog        /var/log/apache2/point-one.com/insite.log
    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>
</VirtualHost>
