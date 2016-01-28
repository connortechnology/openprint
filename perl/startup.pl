#!/usr/bin/perl 

BEGIN {
# Debugging Stuff
	#use	APR::Pool ();
#use	Apache::DB ();
	#Apache::DB->init();
	#use Apache::DProf;
	#use Apache::SmallProf;
	use 5.10.0;
	use utf8;
	#use threads;
	#use threads::shared;
	use Apache2::Request ();
	use Apache2::RequestRec ();
	use Apache2::Connection ();
	use APR::URI ();
	use Apache2::Const ();
	use Apache2::Log ();
	use Apache2::ServerUtil ();
	use Apache2::RequestIO ();
	use Apache::Session::Postgres ();
	use Apache2::Cookie ();
	use Apache2::Upload ();
	#use Apache2::SizeLimit;
	use Apache::DBI ();
	use URI::Escape ();
	use HTML::Strip ();
	use HTML::Entities ();
	use Data::Dumper ();

	use MIME::QuotedPrint ();
	use MIME::Base64 ();
	use Mail::Sendmail ();
	use Text::CSV_XS ();
	use	Authen::Captcha ();
	#use GD::Barcode;
	use Encode ();
	use JSON ();
	use JSON::XS ();

	use Carp ();
	use JavaScript::Minifier::XS ();
	use CSS::Minifier ();
	use	Digest::MD5 ();
	use File::Slurp ();

	use CGI ();
	use sql ();
	use misc ();
	use ssi ();
	use configuration ();
	use pagination ();

	use openprint::www ();
	use handlers::upload ();
	use handlers::assets ();

	use Date::Calc ();
	use Date::Format ();
	use Date::Parse ();
	use Math::Round ();
	use Number::Format ();
	use DateTime::Format::Pg ();
	use POSIX ();

	use openprint::Object ();
	use openprint::Company ();
	use openprint::User ();
	use openprint::UserGroup ();
	use openprint::User_in_UserGroup ();
	use openprint::User_Type ();
	use openprint::User_Notification ();
	use openprint::Service ();
	use openprint::Paper ();
	use openprint::Material ();
	use openprint::Product ();
	use openprint::ProductPrice ();
	use openprint::Pricelist ();
	use openprint::ProjectType ();
	use openprint::ProjectTypeCategory ();
	use openprint::Order ();
	use openprint::Quote ();
	#use openprint::JDF ();
	use	openprint::Timetrack ();
	use	openprint::Currency ();
	use	openprint::Ledger ();
	use openprint::Project_Service ();
	use openprint::Article ();
	use openprint::Article_Category ();
	use openprint::Host ();
	use openprint::Log ();
	use openprint::Opinion ();
	use openprint::Opinion_Availability ();
	use openprint::Opinion_Type ();
	use openprint::Page_Setting ();
	use openprint::Survey ();
	use openprint::Event ();
	use MapImage;
	use Lingua::EN::Inflect ();
	use	openprint::Location ();
	use	openprint::Affiliate ();

	use countries;
	use provinces;
	use Text::Unidecode;

}

1;
__END__
