#!/usr/bin/perl 

BEGIN {
	#use Apache2 ();
	use Apache2::Request ();
	use Apache2::RequestRec ();
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
#
	use MIME::QuotedPrint;
	use Mail::Sendmail;
	use Text::CSV_XS;
	use	Authen::Captcha;
	use GD::Barcode;

	#use Carp ();

	use sql;
	use misc;
	use ssi;
	use configuration;

	use openprint::www;
	use openprint::upload_handler;
	use openprint::jsrs_handler;

	use Date::Calc;
	use Date::Format;
	use Date::Parse;

	use openprint::Object;
	use openprint::Company;
	use openprint::User;
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
	use openprint::paper;
	use openprint::JDF;

#use MapImage;

}

1;

__END__
