package openprint::upload_handler;

use Apache2::Request;    # instead of CGI, it's MUCH faster, and does nice things.
use Apache2::RequestRec ();
use APR::URI;
use APR::Request;
use Apache2::Const -compile => qw(HTTP_INTERNAL_SERVER_ERROR OK DECLINED HTTP_NOT_FOUND HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
use Apache2::Log;
use Apache2::ServerUtil ();
use Apache2::RequestIO ();
use Apache::Session::Postgres;

use Date::Calc qw(Add_Delta_Days);
use MIME::QuotedPrint;
use MIME::Base64;

use strict;

require jsrs;
require sql;
require ssi;
require misc;
require configuration;
require openprint::login;

use openprint;
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*r = \$openprint::r;

sub handler {
	my $request = shift;
	$log	= $request->log;

	$request->no_cache(1);
	#$request->headers_out('Cache-Control', 'no-store, no-cache');

	#my $starttime = time;
	#$log->debug( "Beginning of UPLOAD Request: Time (seconds) : $starttime" );
	#$r->parse;

	$dbh = sql::open_sql( $log, 
			'database'	=> $request->dir_config('db_name'),
			'driver'	=> $request->dir_config('db_driver'),
			'host'		=> $request->dir_config('db_host'),
			'login'		=> $request->dir_config('db_user'),
			'password'	=> $request->dir_config('db_password'),
			);

    my $cookies = Apache2::Cookie->fetch( $r );
    my $cookie = $$cookies{'_session_id'};
    $cookie = $cookie->value if $cookie;

	tie %session, 'Apache::Session::Postgres', $cookie, {
		Handle      => $dbh,
					Commit      => 0,
					IDLength    => 8,
	};

	if ( $request->method eq 'POST' ) {
		my $uploaded = 0;
		my ($serial) = $request->args() =~ /serial=(\d*)/;
		my ($company) = $request->args() =~ /txtCompanyName=([.^&]*)/;
		my $rsize=$request->headers_in->{'Content-Length'};
		sql::execute( undef, undef, q{DELETE FROM Uploads WHERE id=?}, $serial );
		sql::insert( $log, $dbh, 'Uploads', ['start', 'NOW()', 'size', 0, 'total', $rsize, 'id', $serial, 'company_id', $session{'company_id'}, 'company', $company, 'user_id', $session{'user_id'} ] );

		my $upload_hook = sub {
			my ( $upload, $data, $data_len, $hook_data ) = @_;
			$data_len = length $data if ( ! $data_len );

			#my ( $size, $total ) = sql::execute( undef, undef, q{SELECT size, total FROM Uploads WHERE id=?}, $serial );
			$uploaded += $data_len;	

			sql::update( undef, undef, 'Uploads', ['id=?', $serial], ['size', $uploaded] );
		};
		$r = Apache2::Request->new( $request, UPLOAD_HOOK=>$upload_hook );
	} else {
		$r = Apache2::Request->new( $request );
	} # end if

    foreach my $key ( sort $r->param() ) {
        $log->debug("Parameter $key is (" . $r->param($key) . ")" );
        $param{$key} = $r->param($key);
    } # end foreach

	if ( $r->param('action') eq 'get_progress_and_size' ) {
		my $data = $dbh->selectrow_hashref(q{SELECT size, total, extract( epoch from date_trunc('seconds', NOW()) - date_trunc('seconds', start ) ) as elapsed FROM Uploads WHERE id=?} , {}, $r->param('serial') );
		if ( ! $data ) {
			$log->debug("No uploadin progress for " . $r->param('serial') );
			$data = {};
		} else {
		$log->debug("$data");	
foreach my $k ( keys %$data ) {
$log->debug("($k) -> $$data{$k}");
}
		}

#<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
		my $output =qq` 
<response>
<completedsize>$$data{'size'}</completedsize>
<totalsize>$$data{'total'}</totalsize>
<elapsedtime>$$data{'elapsed'}</elapsedtime>
<serial>`.$r->param('serial').q{</serial></response>};
		$log->debug($output);
		$request->content_type('text/xml');
		$r->print( $output );
	} else {
		configuration::init_cache( $log, $dbh, $r->dir_config() );
		my $serial = $r->param('serial');
		if ( $serial ) {
			sql::execute( $log, $dbh, q{UPDATE Uploads SET size=total,finished=NOW() WHERE id=?}, $serial );
		} else {
			$log->error("No serial in upload, dumping session");
			foreach my $k ( keys %session ) {
				$log->error( "$k -> $session{$k}" );
			} # end foreach
		} # end if
		upload_files( $r, $log, $dbh, \%variable );
		my $page = '/upload/_upload_complete.html';
		my $content;
		if (-e $r->dir_config('SkinPath') . $page) {
			$page = $r->dir_config('SkinPath') . $page;
		} else {
			$page = $ENV{'DOCUMENT_ROOT'} . $page;
		} # end if
		my $content = misc::load_file( $log, $page );
        $variable{'PageContent'} = ssi::variable_substitution( \$content, \%variable );
		my @page_path = split('/', $page );
        my $filename = pop @page_path;
        my $template;

		while ( @page_path ) {
			my $file = join( '/', $r->dir_config('SkinPath'), 'layouts', @page_path, $filename );
			if ( -e $file ) {
				$template = misc::load_file( $log, $file );
				last;
			} # end if
			$file = join( '/', $r->dir_config('SkinPath'), 'layouts', @page_path, 'default.html' );
			if ( -e $file ) {
				$template = misc::load_file( $log, $file );
				last;
			} # end if
			$file = join( '/', $ENV{'DOCUMENT_ROOT'}, 'layouts', @page_path, $filename );
			if ( -e $file ) {
				$template = misc::load_file( $log, $file );
				last;
			} # end if

			$file = join( '/', $ENV{'DOCUMENT_ROOT'}, 'layouts', @page_path, 'default.html' );
			if ( -e $file ) {
				$template = misc::load_file( $log, $file );
				last;
			} # end if
			pop @page_path;
		} # end while

        if ( $template ) {
            $r->print( ssi::variable_substitution( \$template, \%variable ) );
        } else {
            $r->print( $variable{'PageContent'} );
        } # end if
	} # end if

	untie %session;
	#$dbh->disconnect();# if $dbh->{'thread_id'};
	#$log->debug( "Elapsed seconds: " . ( time - $starttime ) );
	return Apache2::Const::OK;
}

sub create_dir {
	my $dir = shift;
	if ( ! -e $dir ) {
		if ( ! mkdir $dir ) {
			$openprint::log->error("Cannot create dir $dir : Reason: $!" );
			return 0;
# This should email somebody
		} # end if	
	} elsif ( ! -d $dir ) {
		$openprint::log->error("$dir exists but is not a directory.");
		return 0;
	} # end if
	return 1;
} # end sub create_dir

# Returns path component from ProjectFilesPath onward, basically company and docket components
sub get_destdir {
	my $destdir = '/';
	# First off, determine if we are logged in.
	if ( $session{'company_id'} ) {
		( $destdir ) = new openprint::Company( $session{company_id} )->name();
		$destdir = '/'.$destdir.'/';
		return '' if ! create_dir( $config{'ProjectFilesPath'}.$destdir );
	} else {
# This ends up prefixing the file with the company's name
		$destdir .= $param{'txtCompanyName'} . '_';
	} # end if

	if ( $param{'docket'} ) {
		$destdir .= '/' . $param{'docket'} . '/';
		return '' if ! create_dir( $config{'ProjectFilesPath'}.$destdir );
	} elsif ( $param{'project_id'} ) {
		my $Project = new openprint::Project( $param{'project_id'} );
		my $docket = $Project->docket();
		$destdir .= '/' . $docket . '/';
		return '' if ! create_dir( $config{'ProjectFilesPath'}.$destdir );
	} # end if
	return $destdir;
} # end sub get_Destdir

sub upload_files {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $param{'project_id'} ) {
		$param{'project_id'} =~ s/\D//g;
		$param{'docket'} = new openprint::Project( $param{'project_id'} )->docket();
	} elsif ( $param{'docket'} and ! $param{'project_id'} ) {
		$param{'docket'} =~ s/\D//g;
		my @Projects = openprint::Project::find('docket'=>$param{'docket'}) if $param{'docket'};
		$param{'project_id'} = $Projects[0]->id() if @Projects;
	} # end if

	my $destdir = get_destdir();
	if ( ! $destdir ) {
		$$variable{'error'} .= 'There was an error saving your upload!<br/>';
		return;
	} # end if
	
	if ( $r->param('btnFunction') eq 'Upload Files' ) {

		foreach my $index ( 1 .. 5 ) {
			if ( $param{'fileUpload'.$index} ) {
				my $filename = $param{'fileUpload'.$index};
				$filename =~ s/.*[\/\\](.*)/$1/;
				$filename =~ s/ /_/g;

				my $upload = $r->upload( 'fileUpload'.$index );
				if ( ! $upload->link(  "$config{'ProjectFilesPath'}$destdir$filename" ) ) {
					$$variable{'error'} .= "There was an error saving file $param{'fileUpload'.$index}: $!<br/>";
					return;
				} else {
					$$variable{'information'} .= "File $param{'fileUpload'.$index} was uploaded successfully.<br/>";
				} # end if

				if ( $param{'project_id'} ) {
					  sql::execute( $log, $dbh, q{DELETE FROM project_files WHERE project_id=? AND filename=?}, 
					  $param{'project_id'} ? $param{'project_id'} : undef, $destdir.$filename );
				} else {
				   sql::execute( $log, $dbh, q{DELETE FROM project_files WHERE filename=?}, $destdir.$filename );
				} # end if
				sql::insert( $log, $dbh, 'project_files', [
						'project_id',	$param{'project_id'} ? $param{'project_id'} : undef,
						'filename',		$destdir.$filename,
						'description',	$param{'txtDescription'.$index},
						'upload_id',	$param{'serial'},
						] );
			} # end if
		} # end foreach
# Notify CSR, and Customer of upload
		$$variable{'SiteTitle'} = $r->dir_config('SiteTitle');
		if (-e $r->dir_config('SkinPath') . '/email_content/uploadfiles_csr_notification.html') {
			$$variable{'ReplacementText'} = misc::load_file( $log, $r->dir_config('SkinPath') . '/email_content/uploadfiles_csr_notification.html' );
		} else {
			$$variable{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/uploadfiles_csr_notification.html' );
		} # end if
		$$variable{'ReplacementText'} = ssi::variable_substitution( \$$variable{'ReplacementText'}, $variable );
		my $csr_id;
		my $to;
		my $from;
		if ( $session{'user_id'} ) {
			my $User = new openprint::User( $session{'user_id'} );
			$from = sprintf('"%s %s" <%s>', $User->get('firstname','lastname','email') ),
		} else {
			$from = $param{'txtEmailAddress'};
			if ( ! Email::Valid->address( $param{'txtEmailAddress'} ) ) {
				$from = $config{'OrderingEmail'};
			} # end if
		} # end if
		if ( $session{'company_id'} ) {
			$csr_id = new openprint::Company( $session{'company_id'} )->salesrep_id();
		} # end nif
		if ( $csr_id ) {
			my $CSR = new openprint::User( $csr_id );
			$to = sprintf('"%s %s" <%s>', $CSR->get('firstname','lastname','email') ),
		} else {
			$to = $config{'OrderingEmail'};
		} # end if
		my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
		my $body = ssi::variable_substitution( \$email_template, $variable );
		my %mail = (
						SMTP    => $config{'Mail Server'},
						FROM    => $from,
						TO		=> $to,
						#BCC		=>	'iconnor@penultima.org',
						SUBJECT => $param{'docket'} ? "Files uploaded for docket: $param{'docket'}" : 'Files Uploaded',
				   );
		misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($body), 'text/html', 'quoted-printable' ) );

		# Send transcript to uploader
		if (-e $r->dir_config('SkinPath') . '/email_content/uploadfiles_client_notification.html') {
			$$variable{'ReplacementText'} = misc::load_file( $log, $r->dir_config('SkinPath') . '/email_content/uploadfiles_client_notification.html' );
		} else {
			$$variable{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/uploadfiles_client_notification.html' );
		} # end if
		$$variable{'ReplacementText'} = ssi::variable_substitution( \$$variable{'ReplacementText'}, $variable );
		$from = $to;
		if ( $session{'user_id'} ) {
			my $User = new openprint::User( $session{'user_id'} );
			$to = sprintf('"%s %s" <%s>', $User->get('firstname','lastname','email') ),
		} else {
			$to = $param{'txtEmailAddress'};
		} # end if
        $body = ssi::variable_substitution( \$email_template, $variable );
        %mail = (
                        SMTP    => $config{'Mail Server'},
                        FROM    => $from,
                        TO      => $to,
                        SUBJECT => $param{'docket'} ? "Files uploaded for docket: $param{'docket'}" : 'Files Uploaded',
                   );
        misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($body), 'text/html', 'quoted-printable' ) );

	} # end if
} # end sub upload_files

sub get_files {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $destdir = $openprint::config{'ProjectFilesPath'} . get_destdir();
	my $company_name;
	my $company_dir;
	my $docket;
	
	my @filenames;
	if ( opendir DIRHANDLE, $destdir ) {
		@filenames = readdir DIRHANDLE;
		closedir DIRHANDLE;
	} # end if
	@{$$variable{'PROJECT_FILES'}} = ();
	foreach my $file ( @filenames ) {
		next if substr($file,0,1) eq '.';
		my $description;
		if ( $r->param('project_id') ) {
			$_ = q{SELECT description FROM project_files WHERE project_id=? AND filename =?};
			( $description ) = sql::execute( $log, $dbh, $_, $r->param('project_id'), $file );
		} # end if project_id
		push @{$$variable{'PROJECT_FILES'}}, "$company_name/$docket", $file, $description;
	} # end foreach
	return @{$$variable{'PROJECT_FILES'}};
} # end sub get_Files

1;
__END__
