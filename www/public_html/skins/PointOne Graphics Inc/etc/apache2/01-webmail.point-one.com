
<VirtualHost *:80>
        DocumentRoot /usr/share/squirrelmail
        ServerName webmail.point-one.com
		ServerAlias	mail.point-one.com
        <Directory /usr/share/squirrelmail>
				<IfModule mod_php5.c>
                php_flag register_globals off
				</IfModule>
                Options Indexes FollowSymLinks
                <IfModule mod_dir.c>
                        DirectoryIndex index.php
                </IfModule>
        </Directory>
</VirtualHost>

