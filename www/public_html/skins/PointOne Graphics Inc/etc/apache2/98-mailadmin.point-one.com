<VirtualHost *:80>
        DocumentRoot /var/www/testing/mail
        ServerName mailadmin.point-one.com
        ServerAlias     mailadmin
        <Directory /var/www/testing/mail>
                php_flag register_globals off
                Options Indexes FollowSymLinks
                <IfModule mod_dir.c>
                        DirectoryIndex index.php
                </IfModule>
        </Directory>
</VirtualHost>
