<VirtualHost *:80>
        DocumentRoot /usr/share/squirrelmail
        ServerName webmail.point-one.com
        <Directory /usr/share/squirrelmail>
                php_flag register_globals off
                Options Indexes FollowSymLinks
                <IfModule mod_dir.c>
                        DirectoryIndex index.php
                </IfModule>
        </Directory>
</VirtualHost>

