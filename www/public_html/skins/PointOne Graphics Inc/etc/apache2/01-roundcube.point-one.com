<VirtualHost *:80>
        DocumentRoot /var/lib/roundcube
        ServerName roundcube.point-one.com
		Alias /roundcube/program/js/tiny_mce/ /usr/share/tinymce/www/
		Alias /roundcube /var/lib/roundcube
		ErrorLog		/var/log/apache2/point-one.com/roundcube.log
</VirtualHost>

<VirtualHost *:80>
        DocumentRoot /var/lib/roundcube
        ServerName roundcube4.internal.point-one.com
		Alias /roundcube/program/js/tiny_mce/ /usr/share/tinymce/www/
		Alias /roundcube /var/lib/roundcube
		ErrorLog		/var/log/apache2/internal.point-one.com/roundcube4.log
</VirtualHost>

