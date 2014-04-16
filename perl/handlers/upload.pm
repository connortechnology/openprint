use strict;
package handlers::upload;

require Apache2::Request;    # instead of CGI, it's MUCH faster, and does nice things.
require Apache2::RequestRec;
use Apache2::Const -compile => qw(HTTP_INTERNAL_SERVER_ERROR OK DECLINED HTTP_NOT_FOUND HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
require Apache2::Log;
require Apache2::ServerUtil;
require Apache2::RequestIO;
require Apache2::Upload;

require sql;
require ssi;
require misc;
require configuration;
require openprint::Upload;
require openprint::File;
require openprint::Company;
require openprint::User;
require openprint::User_Notification;
require openprint::Email;

require MIME::QuotedPrint;
require Encode;
require Email::Valid;

use openprint ();
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
			database	=> $request->dir_config('db_name'),
			driver		=> $request->dir_config('db_driver'),
			host		=> $request->dir_config('db_host'),
			login		=> $request->dir_config('db_user'),
			password	=> $request->dir_config('db_password'),
			);

	my $serial;
	my $rsize;

	if ( $request->method eq 'POST' ) {
	my $table = $request->headers_in;

foreach my $key (keys %{$table}) {
      $log->debug( "$key = $table->{$key}" );
  }
		$uploaded = 0;
		($serial) = $request->args() =~ /serial=(\d*)/;
		my ($company) = $request->args() =~ /txtCompanyName=([.^&]*)/;
		( $rsize ) = $request->args() =~ /qqtotalfilesize=(\d+)/;
		$rsize=$request->headers_in->{'Content-Length'} if ! $rsize;
		if ( $serial ) {
			sql::execute( undef, undef, q{DELETE FROM Uploads WHERE id=?}, $serial );
		} else {
			($serial) = sql::execute( undef, undef, q`SELECT nextval('uploads_id_seq')` );
		} # end if
		sql::insert( $log, $dbh, 'Uploads', ['start', 'NOW()', 'size', 0, 'total', $rsize, 'id', $serial, 'company', $company, 'type', 'Web' ] );

		my $upload_hook = sub {
			my ( $upload, $data, $data_len, $hook_data ) = @_;
#$log->debug("Upload: $rsize = $data_len, $uploaded, " . length $data );
			$data_len = length $data if ! $data_len;
			if ( $data_len ) {
				$uploaded += $data_len;	
				sql::update( undef, undef, 'Uploads', ['id=?', $serial], ['size', $uploaded] );
			} # end if
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
		configuration::init( $r->dir_config() );
		openprint::session_init();
		if ( $serial ) {
			sql::update( undef, undef, 'uploads', ['id=?', $serial], [ 'finished', 'NOW()', 'user_id', $session{'user_id'}, 'company_id', $session{'company_id'}, 'size', $uploaded ] );
		#} else {
			#$log->error("No serial in upload, dumping session");
			#foreach my $k ( keys %session ) {
				#$log->error( "$k -> $session{$k}" );
			#} # end foreach
		} # end if
		if ( $param{'UploadType'} ) {
			my $error;
			require "openprint/$param{'UploadType'}.pm";
			my $uploads = $r->upload;
			if ( $uploads and %$uploads ) {
				my $Object = ('openprint::'.$param{'UploadType'})->new( $param{'id'} );
				while ( my ( $field, $upload ) = each %$uploads ) {
					$error .= $Object->upload( $field );
				} # end while
			} else {
				$log->error('no uploads'.$r->body());
			}

			$r->content_type('application/json');
			if ( $error and ref $error ne 'openprint::'.$param{'UploadType'} ) {
				$log->debug("Printing success:false $error");
				$r->print( qq|{ "success": false, "error": "$error" }| );
			} else {
				$log->debug("Printing success:true");
				$r->print( q`{ "success": true }` );
			} # end if
		} else {
$log->debug("Doing standrad upload");

			upload_files();
			my $page = '/upload/_upload_complete.html';
			my @page_path = split('/', $page );
			$variable{'PageContent'} = ssi::include( $page );
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
$log->debug("content: $_");
				$r->print( $_ );
			} else {
				$r->print( $variable{'PageContent'} );
			} # end if
		} # end if
	} # end if

	untie %session;
	undef %session;

	# This is neccessary because these are shared with other handlrrs
	%variable = ();
	%param = ();
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
		$param{'txtCompanyName'} = openprint::Company->transform('name', $param{'txtCompanyName'});
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
} # end sub get_destdir

sub upload_files {
	if ( $param{'project_id'} ) {
		$param{'project_id'} =~ s/\D//g;
		$param{'docket'} = new openprint::Project( $param{'project_id'} )->docket();
	} elsif ( $param{'docket'} and ! $param{'project_id'} ) {
		$param{'docket'} =~ s/\D//g;
		my @Projects = openprint::Project->find('docket'=>$param{'docket'}) if $param{'docket'};
		$param{'project_id'} = $Projects[0]->id() if @Projects;
	} # end if

	my $destdir = get_destdir();
	if ( ! $destdir ) {
		$variable{'error'} .= 'There was an error saving your upload!<br/>';
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
					$variable{'error'} .= "There was an error saving file $param{'fileUpload'.$index}: $!<br/>";
					next;
				} else {
					$variable{'information'} .= "File $param{'fileUpload'.$index} was uploaded successfully.<br/>";
				} # end if

                foreach my $File ( openprint::File->find('project_id'=>$param{'project_id'} ? $param{'project_id'} : undef, 'filename'=>$destdir.$filename) ) {
                    $File->delete();
                } # end foreach
                my $File = new openprint::File();
                $variable{'error'} .= $File->save({
                        'project_id'    =>  ( $param{'project_id'} ? $param{'project_id'} : undef ),
                        'filename'      =>  $destdir.$filename,
                        'description'   =>  $param{'txtDescription'.$index},
                        'upload_id'     =>  $param{'serial'},
                        'size'          =>  $upload->size(),
                        } );
			} # end if
		} # end foreach file
		if ( $files ) {
# Notify CSR, and Customer of upload
			my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
			$variable{'ReplacementText'} = ssi::include( '/email_content/uploadfiles_csr_notification.html', \%variable );
			my $body = ssi::variable_substitution( \$email_template, \%variable );
			my $Mail = new openprint::Email();
			my @to;
			my $from;
			if ( $session{'user_id'} ) {
				$from = new openprint::User( $session{'user_id'} );
			} else {
				$from = $param{'txtEmailAddress'};
				$from = Email::Valid->address( $param{'txtEmailAddress'} );
				if ( ! $from ) {
					$from = $config{'OrderingEmail'};
				} # end if
			} # end if
			my $Company;
			if ( $session{'company_id'} ) {
				my $Company = new openprint::Company( $session{'company_id'} );
				if ( $Company->salesrep_id() and ( $Company->CSR()->notification('CSR Client File Uploads') ne 'No' ) ) {
					push @to, $Company->CSR();
				} # end if
			} # end if
			push @to, map { $_->User() } openprint::User_Notification->find('type'=>'Client File Uploads','value'=>'Yes',company_id=>[ $config{Owner}, ( $Company?$Company->id():()) ]);
			if ( ! @to ) {
				push @to, $config{OrderingEmail};
			} # end if
			if ( @to ) {

				$_ = $Mail->send(
						FROM    => $from,
						TO		=> \@to,
#BCC		=>	'iconnor@penultima.org',
						SUBJECT => $param{docket} ? "Files uploaded for docket: $param{docket}" : 'Files Uploaded',
						ATTACHMENTS	=>	[ '', MIME::QuotedPrint::encode_qp(Encode::encode('utf-8',$body)), 'text/html', 'quoted-printable' ],
						);

				# Send transcript to uploader
				$variable{'ReplacementText'} = ssi::include( '/email_content/uploadfiles_client_notification.html', \%variable );
			} # end if

			if ( @to == 1 ) {
				$from = $to[0];
			} else {
				$from = $config{'OrderingEmail'};
			} # end if

			if ( $session{'user_id'} ) {
				my $User = new openprint::User( $session{'user_id'} );
				@to = ( $User );
			} else {
				@to = ( $param{'txtEmailAddress'} );
			} # end if
			my $body = ssi::variable_substitution( \$email_template, \%variable );
			$_ = $Mail->send(
					FROM    => $from,
					TO      => \@to,
					SUBJECT => $param{'docket'} ? "Files uploaded for docket: $param{'docket'}" : 'Files Uploaded',
					ATTACHMENTS => [ '', MIME::QuotedPrint::encode_qp(Encode::encode('utf-8',$body)), 'text/html', 'quoted-printable' ],
					);
		} else {
			$variable{'error'} .= 'No files were uploaded.';
		} # end if files
	} # end if btnfunction eq Upload Files
} # end sub upload_files

sub get_files {
	my $destdir = $config{'ProjectFilesPath'} . get_destdir();
	my $company_name;
	my $company_dir;
	my $docket;
	
	my @filenames;
	if ( opendir DIRHANDLE, $destdir ) {
		@filenames = readdir DIRHANDLE;
		closedir DIRHANDLE;
	} # end if
	@{$variable{'PROJECT_FILES'}} = ();
	foreach my $file ( @filenames ) {
		next if substr($file,0,1) eq '.';
		my $description;
		if ( $r->param('project_id') ) {
			$_ = q{SELECT description FROM project_files WHERE project_id=? AND filename =?};
			( $description ) = sql::execute( $log, $dbh, $_, $r->param('project_id'), $file );
		} # end if project_id
		push @{$variable{'PROJECT_FILES'}}, "$company_name/$docket", $file, $description;
	} # end foreach
	return @{$variable{'PROJECT_FILES'}};
} # end sub get_Files

1;
__END__
