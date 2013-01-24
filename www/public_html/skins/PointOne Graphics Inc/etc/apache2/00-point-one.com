<VirtualHost *:80>
	ServerAdmin		iconnor@point-one.com
	DocumentRoot	/var/www/point-one/www/public_html
	ServerName		point-one.com
	ServerAlias		*
	RewriteEngine	on
	RewriteRule	^/(.*)$	http://www.point-one.com/$1 [R,L]
</VirtualHost>
