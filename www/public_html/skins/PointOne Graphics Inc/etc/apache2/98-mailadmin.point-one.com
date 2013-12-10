<VirtualHost *:80>
	DocumentRoot /var/www/testing/mail
	ServerName mailadmin.point-one.com
	ServerAlias     mailadmin
	<IfModule mod_fcgid.c>
        <Directory /var/www/testing/mail>
            Options +ExecCGI
            AllowOverride All
            AddHandler fcgid-script .php
            FCGIWrapper /usr/bin/php5-cgi
            Order allow,deny
            Allow from all
        </Directory>
    </IfModule>

	<IfModule mod_php5.c>
        <Directory /var/www/testing/mail>
			php_flag register_globals off
			Options Indexes FollowSymLinks
			<IfModule mod_dir.c>
					DirectoryIndex index.php
			</IfModule>
        </Directory>
	</IfModule>
</VirtualHost>
