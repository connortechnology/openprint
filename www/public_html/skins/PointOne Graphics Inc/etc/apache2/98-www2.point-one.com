

<VirtualHost *:80>
	ServerAdmin	 iconnor@penultima.org
	DocumentRoot	/var/www/point-one/www/public_html
	ServerName	www2.point-one.com
	ErrorLog		/var/log/apache2/point-one.com/www2.log

	LogLevel debug
	#LogLevel warn

	RewriteEngine on
	RewriteRule	^/(.*);SSL$	http://%{SERVER_NAME}/$1 [R,L]
	RewriteRule	^/(.*);NOSSL$ http://%{SERVER_NAME}/$1 [R,L]
	#RewriteRule	^/employee/(.*)$ http://%{SERVER_NAME}/index.html [R,L]
	#RewriteRule	^/administrator/(.*)$ http://%{SERVER_NAME}/index.html [R,L]

	Alias	/images	"/var/www/point-one/www/public_html/skins/PointOne Graphics Inc/images"
	Alias	/favicon.ico	"/var/www/point-one/www/public_html/skins/PointOne Graphics Inc/images/favicon.ico"
	Alias	/css	"/var/www/point-one/www/public_html/skins/PointOne Graphics Inc/css"
	Alias	/main/company	"/var/www/point-one/www/public_html/skins/PointOne Graphics Inc/main/company"
	Alias	/main/services	"/var/www/point-one/www/public_html/skins/PointOne Graphics Inc/main/services"
	Alias	/video	"/var/www/point-one/www/public_html/skins/PointOne Graphics Inc/video"
	Alias	/newsletters	"/var/www/point-one/www/public_html/skins/PointOne Graphics Inc/newsletters"
	Alias	/assets "/media/Storage/Assets/"
	Alias	/thumbnails	"/media/Storage/Assets/thumbnails/"
	Alias /project_files "/media/Storage/Project Files/"
	Alias /pdfs "/media/Storage/PDFS/"
	PerlSetVar		PageFlipDir	 "/media/PageFlip"
	Alias	/PageFlip		"/media/PageFlip"

	PerlSetVar		SecureSiteURL	http://www2.point-one.com
	PerlSetVar		siteURL		http://www2.point-one.com
	PerlSetVar		ExternalSecureSiteURL	http://www2.point-one.com
	PerlSetVar		ExternalSiteURL		http://www2.point-one.com
	PerlSetVar		InternalSecureSiteURL	http://www2.internal.point-one.com
	PerlSetVar		InternalSiteURL		http://www2.internal.point-one.com
	PerlSetVar		SiteTitle		"PointOne Graphics Inc"
	PerlSetVar		SkinPath		"/var/www/point-one/skins/PointOne Graphics Inc/"
	PerlSetVar		Country		CA
	PerlSetVar		Currency	CAD
	PerlSetVar		Domain		.point-one.com
	PerlSetVar		ServerName	www1

	PerlSetVar		db_name		point-one
	PerlSetVar		db_host		database.internal.point-one.com
	PerlSetVar		db_user		 point-one
	PerlSetVar		db_password	 point-one
	PerlSetVar		db_driver		Pg

	<Location /images/maps>
		SetHandler		perl-script
		PerlHandler	 MapImage
	</Location>

	<FilesMatch "^jsrs\.htm$">
		SetHandler      perl-script
		PerlResponseHandler     openprint::jsrs_handler
	</FilesMatch>

	<FilesMatch "^barcode\.png$">
		SetHandler		perl-script
		PerlHandler	 Barcode
	</FilesMatch>

	<FilesMatch "^upload\.htm$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::upload_handler
	</FilesMatch>

	<Files ~ "\.json$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::www
	</Files>

	<Files ~ "\.html$">
		SetHandler		perl-script
		PerlResponseHandler	 openprint::www
	</Files>

</VirtualHost>
