#!/usr/bin/perl 
use 5.10.0;

BEGIN {
	use utf8;
	use threads;
	use threads::shared;
	#use Apache2 ();
	use Apache2::Request ();
	use Apache2::RequestRec ();
	use Apache2::Connection ();
	use APR::URI;
	use Apache2::Const;
	use Apache2::Log ();
	use Apache2::ServerUtil ();
	use Apache2::RequestIO ();
	use Apache::Session::Postgres;
	use Apache2::Cookie;
	use Apache2::Upload;
	#use Apache2::SizeLimit;
	use Apache::DBI ();
	use URI::Escape;
	use HTML::Entities;
	use Data::Dumper;
#
	use MIME::QuotedPrint;
	use MIME::Base64;
	use Mail::Sendmail;
	use Text::CSV_XS;
	use	Authen::Captcha;
	use GD::Barcode;
	use Encode;
	use JSON;
	use JSON::XS;

	use Carp qw(cluck);

	use CGI;
	use sql;
	use misc;
	use ssi;
	use configuration;
	use pagination;

	use openprint::www;
	use openprint::upload_handler;

	use Date::Calc;
	use Date::Format;
	use Date::Parse;
	use Math::Round;
	use Number::Format;
	use DateTime::Format::Pg;

	use openprint::Object;
	use openprint::Company;
	use openprint::User;
	use openprint::User_Type;
	use openprint::User_Notification;
	use openprint::Service;
	use openprint::Paper;
	use openprint::Material;
	use openprint::Product;
	use openprint::ProductPrice;
	use openprint::Pricelist;
	use openprint::ProjectType;
	use openprint::ProjectTypeCategory;
	use openprint::Order;
	use openprint::Quote;
	use openprint::JDF;
	use	openprint::Timetrack;
	use	openprint::Currency;
	use	openprint::Ledger;
	use openprint::Project_Service;
	use openprint::Article;
	use openprint::Article_Category;
	use openprint::Host;
	use openprint::Log;
	use openprint::Like;
	use openprint::Page_Setting;
	use openprint::Survey;
	use openprint::Event;

#use MapImage;

}

1;
__END__
