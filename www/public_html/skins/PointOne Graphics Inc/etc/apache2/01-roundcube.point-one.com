<VirtualHost *:80>
        DocumentRoot /var/lib/roundcube
        ServerName roundcube.point-one.com
		Alias /roundcube/program/js/tiny_mce/ /usr/share/tinymce/www/
		Alias /roundcube /var/lib/roundcube
</VirtualHost>

