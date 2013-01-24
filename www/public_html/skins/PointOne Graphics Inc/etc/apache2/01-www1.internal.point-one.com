

<VirtualHost *:80>
	ServerAdmin	 iconnor@point-one.com
	DocumentRoot	/var/www/point-one/www/public_html
	ServerName		www1.internal.point-one.com
	ErrorLog		/var/log/apache2/internal.point-one.com/www1.log

	LogLevel debug
	#LogLevel warn
	
	Alias	/images			"/var/www/point-one/skins/PointOne Graphics Inc/images"
	Alias	/favicon.ico	"/var/www/point-one/skins/PointOne Graphics Inc/images/favicon.ico"
	Alias	/css			"/var/www/point-one/skins/PointOne Graphics Inc/css"
	Alias	/main/company	"/var/www/point-one/skins/PointOne Graphics Inc/main/company"
	Alias	/main/services	"/var/www/point-one/skins/PointOne Graphics Inc/main/services"
	Alias	/video			"/var/www/point-one/skins/PointOne Graphics Inc/video"
	Alias	/newsletters	"/var/www/point-one/skins/PointOne Graphics Inc/newsletters"
	Alias	/cache				"/var/www/point-one/skins/PointOne Graphics Inc/cache"
	Alias	/assets 		"/media/Storage/Assets/"
	Alias	/thumbnails		"/media/Storage/Assets/thumbnails/"

	PerlSetVar		SecureSiteURL	http://www1.internal.point-one.com
	PerlSetVar		siteURL			http://www1.internal.point-one.com
	PerlSetVar		ExternalSecureSiteURL	http://www.point-one.com
	PerlSetVar		ExternalSiteURL			http://www.point-one.com
	PerlSetVar		InternalSecureSiteURL	http://www1.internal.point-one.com
	PerlSetVar		InternalSiteURL			http://www1.internal.point-one.com
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

    <Directory /var/www/point-one/www/public_html>
		RewriteEngine on
		RewriteRule	^(.*);SSL$	http://%{SERVER_NAME}/$1 [NC,R,L]
		RewriteRule	^(.*);NOSSL$ http://%{SERVER_NAME}/$1 [NC,R,L]


		<FilesMatch "^JMF\.htm$">
			SetHandler		perl-script
			PerlHandler	 JMF
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
	</Directory>

   <Directory "/var/www/point-one/skins/PointOne Graphics Inc/cache">
        RewriteEngine On
        RewriteCond %{HTTP:Accept-Encoding} gzip
        RewriteCond %{REQUEST_FILENAME}.gz -f
        RewriteRule (.*\.(js|css))$ $1.gz [PT]
        RewriteBase /cache
		Header append Vary: Accept-Encoding
    </Directory>

    AddEncoding x-gzip .gz

    <FilesMatch .*\.css.gz>
        ForceType text/css
    </FilesMatch>

    <FilesMatch .*\.js.gz>
        ForceType application/x-javascript
    </FilesMatch>

	<FilesMatch "^barcode\.png$">
		SetHandler		perl-script
		PerlHandler	 Barcode
	</FilesMatch>
	<Location /images/maps>
		SetHandler		perl-script
		PerlHandler	 MapImage
	</Location>
		<DirectoryMatch '^/po'>
			SetHandler		perl-script
			PerlHandler	getfile 
		</DirectoryMatch>
	Alias /project_files "/media/Storage/Project Files/"
	PerlSetVar		PageFlipDir	 "/media/PageFlip"
	Alias	/PageFlip	"/media/PageFlip"
	Alias /pdfs "/media/Storage/PDFS/"

</VirtualHost>
