

<VirtualHost *:80>
	ServerAdmin	 iconnor@penultima.org
	DocumentRoot	/var/www/point-one/www/public_html
	ServerName	www1.point-one.com
	ErrorLog		/var/log/apache2/point-one.com/www1.log

	LogLevel debug
	#LogLevel warn

	RewriteLog "/tmp/modrewrite.log"
	RewriteLogLevel 9


	Alias	/images	"/var/www/point-one/skins/PointOne Graphics Inc/images"
	Alias	/favicon.ico	"/var/www/point-one/skins/PointOne Graphics Inc/images/favicon.ico"
	Alias	/css	"/var/www/point-one/skins/PointOne Graphics Inc/css"
	Alias	/main/company	"/var/www/point-one/skins/PointOne Graphics Inc/main/company"
	Alias	/main/services	"/var/www/point-one/skins/PointOne Graphics Inc/main/services"
	Alias	/video	"/var/www/point-one/skins/PointOne Graphics Inc/video"
	Alias	/newsletters	"/var/www/point-one/skins/PointOne Graphics Inc/newsletters"
	Alias	/cache	"/var/www/point-one/skins/PointOne Graphics Inc/cache"
	Alias	/PageFlip		"/media/Storage/PageFlip"
	Alias	/assets "/media/Storage/Assets/"
	Alias	/thumbnails	"/media/Storage/Assets/thumbnails/"

	PerlSetVar		SecureSiteURL	http://www1.point-one.com
	PerlSetVar		siteURL		http://www1.point-one.com
	PerlSetVar		ExternalSecureSiteURL	http://www1.point-one.com
	PerlSetVar		ExternalSiteURL		http://www1.point-one.com
	PerlSetVar		InternalSecureSiteURL	http://www1.internal.point-one.com
	PerlSetVar		InternalSiteURL		http://www1.internal.point-one.com
	PerlSetVar		SiteTitle		"PointOne Graphics Inc"
	PerlSetVar		SkinPath		"/var/www/point-one/skins/PointOne Graphics Inc/"
	PerlSetVar		Country		CA
	PerlSetVar		Currency	CAD
	PerlSetVar		Domain		.point-one.com

	PerlSetVar		db_name		point-one
	PerlSetVar		db_host		database.internal.point-one.com
	PerlSetVar		db_user		 point-one
	PerlSetVar		db_password	 point-one
	PerlSetVar		db_driver		Pg

	<Location /images/maps>
		SetHandler		perl-script
		PerlHandler	 MapImage
	</Location>

	<FilesMatch "^barcode\.png$">
		SetHandler		perl-script
		PerlHandler	 Barcode
	</FilesMatch>

    <Directory /var/www/point-one/www/public_html>
        RewriteEngine on
        RewriteRule ^(.*);SSL$  http://%{SERVER_NAME}/$1 [NC,R,L]
        RewriteRule ^(.*);NOSSL$ http://%{SERVER_NAME}/$1 [NC,R,L]
		RewriteRule	^employee/(.*)$ http://%{SERVER_NAME}/index.html [R,L]
		RewriteRule	^administrator/(.*)$ http://%{SERVER_NAME}/index.html [R,L]

		<FilesMatch "^upload\.htm$">
			SetHandler		perl-script
			PerlResponseHandler	 openprint::upload_handler
		</FilesMatch>

		<FilesMatch "^jsrs\.htm$">
			SetHandler		perl-script
			PerlResponseHandler	 openprint::jsrs_handler
		</FilesMatch>
		<Files ~ "\.json$">
			SetHandler		perl-script
			PerlResponseHandler	 openprint::www
		</Files>

		<Files ~ "\.html$">
			SetHandler		perl-script
			PerlResponseHandler	 openprint::www
		</Files>
    </Directory>

    <Directory "/var/www/point-one/skins/PointOne Graphics Inc/cache">
        RewriteEngine On
        RewriteCond %{HTTP:Accept-Encoding} gzip
        RewriteCond %{REQUEST_FILENAME}.gz -f
        RewriteRule (.*\.(js|css))$ $1.gz [PT]
        RewriteBase /cache
    </Directory>
    AddEncoding x-gzip .gz

    <FilesMatch .*\.css.gz>
        ForceType text/css
    </FilesMatch>

    <FilesMatch .*\.js.gz>
        ForceType application/x-javascript
    </FilesMatch>

	Alias /project_files "/media/Storage/Project Files/"
	Alias /pdfs "/media/Storage/PDFS/"
	#PerlSetVar		PageFlipDir	 "/media/PageFlip"
	#Alias	/PageFlip	"/media/PageFlip"
</VirtualHost>

<VirtualHost *:80>
	ServerAdmin	 iconnor@penultima.org
	DocumentRoot	/var/www/point-one/www/public_html
	ServerName	www.point-one.com
	ErrorLog		/var/log/apache2/point-one.com/www.log

	LogLevel debug
	#LogLevel warn

	RewriteEngine on
	RewriteRule	^/(.*);SSL$	https://%{SERVER_NAME}/$1 [R,L]
	RewriteRule	^/(.*);NOSSL$ http://%{SERVER_NAME}/$1 [R,L]
	RewriteRule	^/(.*);ssl$	http://%{SERVER_NAME}/$1 [R,L]
	RewriteRule	^/(.*);nossl$ http://%{SERVER_NAME}/$1 [R,L]
	RewriteRule	^/employee/(.*)$ http://%{SERVER_NAME}/index.html [R,L]
	RewriteRule	^/administrator/(.*)$ http://%{SERVER_NAME}/index.html [R,L]
	
	Alias	/images			"/var/www/point-one/skins/PointOne Graphics Inc/images"
	Alias	/favicon.ico	"/var/www/point-one/skins/PointOne Graphics Inc/images/favicon.ico"
	Alias	/css			"/var/www/point-one/skins/PointOne Graphics Inc/css"
	Alias	/main/company	"/var/www/point-one/skins/PointOne Graphics Inc/main/company"
	Alias	/main/services	"/var/www/point-one/skins/PointOne Graphics Inc/main/services"
	Alias	/video			"/var/www/point-one/skins/PointOne Graphics Inc/video"
	Alias	/sitemap.xml 	"/var/www/point-one/skins/PointOne Graphics Inc/sitemap.xml"
	Alias	/newsletters	"/var/www/point-one/skins/PointOne Graphics Inc/newsletters"
	Alias	/cache			"/var/www/point-one/skins/PointOne Graphics Inc/cache"

	Alias	/PageFlip		"/media/Storage/PageFlip"
	Alias	/assets "/media/Storage/Assets/"
	Alias	/thumbnails	"/media/Storage/Assets/thumbnails/"

	PerlSetVar		SecureSiteURL	https://www.point-one.com
	PerlSetVar		siteURL		http://www.point-one.com
	PerlSetVar		ExternalSecureSiteURL	https://www.point-one.com
	PerlSetVar		ExternalSiteURL		http://www.point-one.com
	PerlSetVar		InternalSecureSiteURL	http://www.internal.point-one.com
	PerlSetVar		InternalSiteURL		http://www.internal.point-one.com
	PerlSetVar		SiteTitle		"PointOne Graphics Inc"
	PerlSetVar		SkinPath		"/var/www/point-one/skins/PointOne Graphics Inc/"
	PerlSetVar		Country		CA
	PerlSetVar		Currency	CAD
	PerlSetVar		Domain		.point-one.com

	PerlSetVar		db_name		point-one
	PerlSetVar		db_host		database.internal.point-one.com
	PerlSetVar		db_user		 point-one
	PerlSetVar		db_password	 point-one
	PerlSetVar		db_driver		Pg

	<Location /images/maps>
		SetHandler		perl-script
		PerlHandler	 MapImage
	</Location>
	<FilesMatch "^barcode\.png$">
		SetHandler		perl-script
		PerlHandler	 Barcode
	</FilesMatch>

	<FilesMatch "^upload\.htm$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::upload_handler
	</FilesMatch>

	<FilesMatch "^jsrs\.htm$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::jsrs_handler
	</FilesMatch>

	<Files ~ "\.json$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::www
	</Files>
	<Files ~ "\.html$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::www
	</Files>

	Alias /project_files "/media/Storage/Project Files/"
	Alias /pdfs "/media/Storage/PDFS/"
	#PerlSetVar		PageFlipDir	 "/media/PageFlip"
	#Alias	/PageFlip	"/media/PageFlip"

</VirtualHost>

<VirtualHost *:443>
	ServerAdmin	 iconnor@penultima.org
	DocumentRoot	/var/www/point-one/www/public_html
	ServerName	www.point-one.com
	ErrorLog		/var/log/apache2/point-one.com/www.log

	LogLevel debug
	#LogLevel warn

	SSLEngine	On
	SSLCertificateFile	/etc/apache2/ssl.crt/www.point-one.com.crt
	SSLCertificateKeyFile	/etc/apache2/ssl.key/www.point-one.com.key
	SSLCACertificateFile	/etc/apache2/ssl.crt/www_point-one_com.ca-bundle

	RewriteEngine on
	RewriteRule	^/(.*);SSL$	https://%{SERVER_NAME}/$1 [R,L]
	RewriteRule	^/(.*);NOSSL$ http://%{SERVER_NAME}/$1 [R,L]
	RewriteRule	^/(.*);ssl$	http://%{SERVER_NAME}/$1 [R,L]
	RewriteRule	^/(.*);nossl$ http://%{SERVER_NAME}/$1 [R,L]
	RewriteRule	^/employee/(.*)$ http://%{SERVER_NAME}/index.html [R,L]
	RewriteRule	^/administrator/(.*)$ http://%{SERVER_NAME}/index.html [R,L]
	
	Alias	/images			"/var/www/point-one/skins/PointOne Graphics Inc/images"
	Alias	/favicon.ico	"/var/www/point-one/skins/PointOne Graphics Inc/images/favicon.ico"
	Alias	/css			"/var/www/point-one/skins/PointOne Graphics Inc/css"
	Alias	/main/company	"/var/www/point-one/skins/PointOne Graphics Inc/main/company"
	Alias	/main/services	"/var/www/point-one/skins/PointOne Graphics Inc/main/services"
	Alias	/video			"/var/www/point-one/skins/PointOne Graphics Inc/video"
	Alias	/newsletters	"/var/www/point-one/skins/PointOne Graphics Inc/newsletters"
	Alias	/PageFlip		"/media/Storage/PageFlip"
	Alias	/assets 		"/media/Storage/Assets/"
	Alias	/thumbnails		"/media/Storage/Assets/thumbnails/"
	Alias	/cache			"/var/www/point-one/skins/PointOne Graphics Inc/cache"

	PerlSetVar		SecureSiteURL	https://www.point-one.com
	PerlSetVar		siteURL		http://www.point-one.com
	PerlSetVar		ExternalSecureSiteURL	https://www.point-one.com
	PerlSetVar		ExternalSiteURL		http://www.point-one.com
	PerlSetVar		InternalSecureSiteURL	http://www.internal.point-one.com
	PerlSetVar		InternalSiteURL		http://www.internal.point-one.com
	PerlSetVar		SiteTitle		"PointOne Graphics Inc"
	PerlSetVar		SkinPath		"/var/www/point-one/skins/PointOne Graphics Inc/"
	PerlSetVar		Country		CA
	PerlSetVar		Currency	CAD
	PerlSetVar		Domain		.point-one.com

	PerlSetVar		db_name		point-one
	PerlSetVar		db_host		database.internal.point-one.com
	PerlSetVar		db_user		point-one
	PerlSetVar		db_password	point-one
	PerlSetVar		db_driver	Pg

	<Location /images/maps>
		SetHandler		perl-script
		PerlHandler	 MapImage
	</Location>
	<FilesMatch "^barcode\.png$">
		SetHandler		perl-script
		PerlHandler	 Barcode
	</FilesMatch>

	<FilesMatch "^upload\.htm$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::upload_handler
	</FilesMatch>
	<FilesMatch "^jsrs\.htm$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::jsrs_handler
	</FilesMatch>

	<Files ~ "\.json$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::www
	</Files>
	<Files ~ "\.html$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::www
	</Files>

	Alias /project_files "/media/Storage/Project Files/"
	Alias /pdfs "/media/Storage/PDFS/"
	#PerlSetVar		PageFlipDir	 "/media/PageFlip"
	#Alias	/PageFlip	"/media/PageFlip"

</VirtualHost>

<VirtualHost *:443>
	ServerAdmin		iconnor@penultima.org
	DocumentRoot	/var/www/point-one/www/public_html
	ServerName		www.point-one.com
	ServerAlias		*.point-one.com
	ErrorLog		/var/log/apache2/point-one.com/www.log

	#LogLevel debug
	LogLevel warn

	SSLEngine	On
	SSLCertificateFile		/etc/apache2/ssl.crt/www.point-one.com.crt
	SSLCertificateKeyFile	/etc/apache2/ssl.key/www.point-one.com.key
	SSLCACertificateFile	/etc/apache2/ssl.crt/www_point-one_com.ca-bundle

	RewriteEngine on
	RewriteRule	^/(.*)$	https://www.point-one.com/$1 [R,L]

</VirtualHost>

<VirtualHost *:80>
	ServerAdmin		iconnor@point-one.com
	DocumentRoot	/var/www/point-one/www/public_html
	ServerName		point-one.com
	ServerAlias		*.point-one.com
	RewriteEngine	on
	RewriteRule	^/(.*)$	http://www.point-one.com/$1 [R,L]
</VirtualHost>
