package openprint::upload_handler;

use Apache2::Request;    # instead of CGI, it's MUCH faster, and does nice things.
use Apache2::RequestRec ();
use APR::URI;
use APR::Request;
use Apache2::Const -compile => qw(HTTP_INTERNAL_SERVER_ERROR OK DECLINED HTTP_NOT_FOUND HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
use Apache2::Log;
use Apache2::ServerUtil ();
use Apache2::RequestIO ();
use Apache2::Cookie;
use Apache::Session::Postgres;

use Date::Calc qw(Add_Delta_Days);

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

my $uploaded = 0;

sub handler {
	my $request = shift;
	$log	= $request->log;

	$request->no_cache(1);

	my $starttime = time;
	#$log->debug( "Beginning of UPLOAD Request: Time (seconds) : $starttime" );

	$dbh = sql::open_sql( $log, 
			'database'	=> $request->dir_config('db_name'),
			'driver'	=> $request->dir_config('db_driver'),
			'host'		=> $request->dir_config('db_host'),
			'login'		=> $request->dir_config('db_user'),
			'password'	=> $request->dir_config('db_password'),
			);

	if ( $request->method eq 'POST' ) {
		$uploaded = 0;
		my ($serial) = $request->args() =~ /serial=(\d*)/;
		my ($company) = $request->args() =~ /txtCompanyName=([.^&]*)/;
		my $rsize=$request->headers_in->{'Content-Length'};
		sql::execute( undef, undef, q{DELETE FROM Uploads WHERE id=?}, $serial );
		sql::insert( $log, $dbh, 'Uploads', ['start', 'NOW()', 'size', 0, 'total', $rsize, 'id', $serial, 'company_id', $session{'company_id'}, 'company', $company, 'type', 'Web' ] );

		my $upload_hook = sub {
			my ( $upload, $data, $data_len, $hook_data ) = @_;
$log->debug("Upload: $rsize = $data_len, $uploaded, " . length $data );
			$data_len = length $data if ( ! $data_len );

			#my ( $size, $total ) = sql::execute( undef, undef, q{SELECT size, total FROM Uploads WHERE id=?}, $serial );
			$uploaded += $data_len;	
			sql::update( undef, undef, 'Uploads', ['id=?', $serial], ['size', $uploaded] ) if $data_len;
		};
		$r = Apache2::Request->new( $request, UPLOAD_HOOK=>$upload_hook );
	} else {
		$r = Apache2::Request->new( $request );
	} # end if

	if ( $r->param('action') eq 'get_progress_and_size' ) {
		my $data = $dbh->selectrow_hashref(q{SELECT size, total, extract( epoch from date_trunc('seconds', NOW()) - date_trunc('seconds', start ) ) as elapsed FROM Uploads WHERE id=?} , {}, $r->param('serial') );
		if ( ! $data ) {
			$log->debug("No uploadin progress for " . $r->param('serial') );
			$data = {};
		#} else {
		#$log->debug("$data");	
#foreach my $k ( keys %$data ) {
#$log->debug("($k) -> $$data{$k}");
#}
		} # end if

#<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
		my $output = qq`<response>
<completedsize>$$data{'size'}</completedsize>
<totalsize>$$data{'total'}</totalsize>
<elapsedtime>$$data{'elapsed'}</elapsedtime>
<serial>`.$r->param('serial').q{</serial></response>};
		#$log->debug($output);
		$request->content_type('text/xml');
		$r->print( $output );
	} else {
		foreach my $key ( sort $r->param() ) {
			$log->debug("Parameter $key is (" . $r->param($key) . ")" );
			$param{$key} = $r->param($key);
		} # end foreach
		configuration::init_cache( $log, $dbh, $r->dir_config() );
		openprint::session_init();
		my $serial = $r->param('serial');
		if ( $serial ) {
			my $rsize=$request->headers_in->{'Content-Length'};
			sql::update( undef, undef, 'uploads', ['id=?', $serial], [ 'finished', 'NOW()', 'user_id', $session{'user_id'}, 'size', $rsize ] );
		} else {
			$log->error("No serial in upload, dumping session");
			foreach my $k ( keys %session ) {
				$log->error( "$k -> $session{$k}" );
			} # end foreach
		} # end if
		upload_files( $r, $log, $dbh, \%variable );
		my $page = '/upload/_upload_complete.html';
		my @page_path = split('/', $page );
		my $content;
		if (-e $r->dir_config('SkinPath') . $page) {
			$page = $r->dir_config('SkinPath') . $page;
		} else {
			$page = $ENV{'DOCUMENT_ROOT'} . $page;
		} # end if
		my $content = misc::load_file( $log, $page );
        $variable{'PageContent'} = ssi::variable_substitution( \$content, \%variable );
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
			$_ = ssi::variable_substitution( \$template, \%variable );
            $r->print( $_ );
        } else {
            $r->print( $variable{'PageContent'} );
        } # end if
	} # end if

	untie %session;
	undef %session;
	#$dbh->disconnect();# if $dbh->{'thread_id'};
	#$log->debug( "Elapsed seconds: " . ( time - $starttime ) );
	return Apache2::Const::OK;
} # end sub handler

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
		$destdir .= $param{'docket'} . '/';
		return '' if ! create_dir( $config{'ProjectFilesPath'}.$destdir );
	} elsif ( $param{'project_id'} ) {
		my $Project = new openprint::Project( $param{'project_id'} );
		if ( my $docket = $Project->docket() ) {
			$destdir .= $docket . '/';
			return '' if ! create_dir( $config{'ProjectFilesPath'}.$destdir );
		} # end if
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
$log->error("No destdir");
		return;
	} # end if
	
	if ( $param{'btnFunction'} eq 'Upload Files' ) {

		my $files = 0;
		foreach my $index ( 1 .. 5 ) {
			if ( $param{'fileUpload'.$index} ) {
				$files += 1;
				my $filename = $param{'fileUpload'.$index};
				$filename =~ s/.*[\/\\](.*)/$1/;
				$filename =~ s/ /_/g;

				my $upload = $r->upload( 'fileUpload'.$index );
				if ( ! $upload->link( "$config{'ProjectFilesPath'}$destdir$filename" ) ) {
$log->error("There was an error saving file $param{'fileUpload'.$index}: to $config{'ProjectFilesPath'}$destdir$filename : $!");
					$$variable{'error'} .= "There was an error saving file $param{'fileUpload'.$index}: $!<br/>";
					next;
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
		} # end foreach file
		if ( $files ) {
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
			misc::send_email_with_attachment( $log, \%mail, ( '', MIME::QuotedPrint::encode_qp( Encode::encode('utf-8',$body)), 'text/html', 'quoted-printable' ) );

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
					#BCC		=>	'iconnor@penultima.org',
					SUBJECT => $param{'docket'} ? "Files uploaded for docket: $param{'docket'}" : 'Files Uploaded',
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', MIME::QuotedPrint::encode_qp(Encode::encode('utf-8',$body)), 'text/html', 'quoted-printable' ) );
		} else {
			$variable{'error'} .= 'No files were uploaded.';
		} # end if files

	} # end if btnfunction eq Upload Files
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
