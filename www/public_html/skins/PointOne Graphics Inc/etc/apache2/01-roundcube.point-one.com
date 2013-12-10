<VirtualHost *:80>
	DocumentRoot /var/lib/roundcube
	ServerName roundcube.point-one.com
	Alias /roundcube/program/js/tiny_mce/ /usr/share/tinymce/www/
	Alias /roundcube /var/lib/roundcube
	ErrorLog		/var/log/apache2/point-one.com/roundcube.log
	<IfModule mod_fcgid.c>
		<Directory /var/lib/roundcube/>
			Options +ExecCGI
			AllowOverride All
			AddHandler fcgid-script .php
			FCGIWrapper /usr/bin/php5-cgi
			Order allow,deny
			Allow from all
		</Directory>
	</IfModule>
</VirtualHost>

<VirtualHost *:80>
	DocumentRoot /var/lib/roundcube
	ServerName roundcube1.internal.point-one.com
	Alias /roundcube/program/js/tiny_mce/ /usr/share/tinymce/www/
	Alias /roundcube /var/lib/roundcube
	ErrorLog		/var/log/apache2/internal.point-one.com/roundcube1.log
	<IfModule mod_fcgid.c>
		<Directory /var/lib/roundcube/>
			Options +ExecCGI
			AllowOverride All
			AddHandler fcgid-script .php
			FCGIWrapper /usr/bin/php5-cgi
			Order allow,deny
			Allow from all
		</Directory>
	</IfModule>
</VirtualHost>

<VirtualHost *:80>
	DocumentRoot /var/lib/roundcube
	ServerName roundcube2.internal.point-one.com
	Alias /roundcube/program/js/tiny_mce/ /usr/share/tinymce/www/
	Alias /roundcube /var/lib/roundcube
	ErrorLog		/var/log/apache2/internal.point-one.com/roundcube2.log
	<IfModule mod_fcgid.c>
		<Directory /var/lib/roundcube/>
			Options +ExecCGI
			AllowOverride All
			AddHandler fcgid-script .php
			FCGIWrapper /usr/bin/php5-cgi
			Order allow,deny
			Allow from all
		</Directory>
	</IfModule>
</VirtualHost>

<VirtualHost *:80>
	DocumentRoot /var/lib/roundcube
	ServerName roundcube5.internal.point-one.com
	Alias /roundcube/program/js/tiny_mce/ /usr/share/tinymce/www/
	Alias /roundcube /var/lib/roundcube
	ErrorLog		/var/log/apache2/internal.point-one.com/roundcube5.log
	<IfModule mod_fcgid.c>
		<Directory /var/lib/roundcube/>
			Options +ExecCGI
			AllowOverride All
			AddHandler fcgid-script .php
			FCGIWrapper /usr/bin/php5-cgi
			Order allow,deny
			Allow from all
		</Directory>
	</IfModule>
</VirtualHost>

<VirtualHost *:80>
	DocumentRoot /var/lib/roundcube
	ServerName roundcube4.internal.point-one.com
	Alias /roundcube/program/js/tiny_mce/ /usr/share/tinymce/www/
	Alias /roundcube /var/lib/roundcube
	ErrorLog		/var/log/apache2/internal.point-one.com/roundcube4.log
	<IfModule mod_fcgid.c>
		<Directory /var/lib/roundcube/>
			Options +ExecCGI
			AllowOverride All
			AddHandler fcgid-script .php
			FCGIWrapper /usr/bin/php5-cgi
			Order allow,deny
			Allow from all
		</Directory>
	</IfModule>
</VirtualHost>

