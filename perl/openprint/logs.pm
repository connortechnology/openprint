package openprint::logs;

use strict;

require sql;

use Date::Handler;

use openprint::logRecord;
use openprint::pagination;

use openprint;
use vars qw( %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

sub get_log_actions {
	my $user_id = $openprint::session{'user_id'};
	my $sql;
	my $counter;
	my $retVal;

	my @sql_results;
	my @results;

	$sql = qq~
		SELECT 
		   id,
		   name,
		   description 
      FROM 
			log_actions 
      ORDER BY name
	~;

	@sql_results = sql::execute( $openprint::log, $openprint::dbh, $sql, );

	while ( @sql_results ) {
	   my ($id, $name, $description) = splice(@sql_results, 0, 3,);
		$retVal .= "<span class=\"logAction\"><input type=\"checkbox\" name=\"log_actions\" id=\"log_action-$id\" value=\"$id\" onclick =\"clickLogAction(this);\" /><label class=\"radio\" for=\"log_action-$id\">$name</label></span>";
	} # end while

	return $retVal;
}

sub insertLogRecord {
	my ( $action_type_id, $note, $user_id ) = @_;

	$user_id = $openprint::session{user_id} if ! $user_id;
	return if ! $user_id;

	if(!defined($action_type_id) || !($action_type_id > 0)) {
	   $action_type_id = 1;
	}
	
	sql::insert( $openprint::log, $openprint::dbh, 'log', [
		'action_type', $action_type_id, 
		'user_id', $user_id, 
		'date_time', 'NOW()', 
		'ip_address', $ENV{REMOTE_ADDR}, 
		'hostname', reverse_dns( $ENV{REMOTE_ADDR} ), 
		'url', $ENV{SERVER_NAME} . $ENV{REQUEST_URI}, 
		'note', $note,
	] );
	
	return 1;
}

sub reverse_dns {
	my $ip = shift;
	return $ip unless $ip=~/\d+\.\d+\.\d+\.\d+/;
	my @h = gethostbyaddr(pack('C4',split('\.',$ip)),2);
	return $h[0];
}

sub getLog {  
   my $sql;
   my $where;
   my $orderBy;
   my $limit;
   my $offset;
   my $log_actions_qry;
   my $order_type;
   my $limit_qry;
   my $offset_qry;
   my $totalResults;
   my $startDate;
   my $endDate;
   my $dateRange_qry;
   my $whereMarker;
   
   my @sql_results;
   my @bind_params;
   my @log_records;
   my @log_actions;
   my @limit_params;
   my @date_params;
   
   $limit = $openprint::param{'resultsLimit'};
   $offset = $openprint::param{'offset'};
   
   my @action_types = ref $openprint::param{'log_actions'} eq 'ARRAY' ? @{$openprint::param{'log_actions'}} : ($openprint::param{'log_actions'} );
   
   if(scalar(@action_types)) {
      for(my $i = 0; $i < scalar(@action_types); $i++) {
         push(@log_actions, 'log.action_type = ?',);
      }
      $log_actions_qry = join(' OR ', @log_actions,);
      $log_actions_qry = "( $log_actions_qry ) ";
   }
   
   if($openprint::param{'orderBy_Type'} eq 'descend') {
      $order_type = 'DESC';
   }

   if($openprint::param{'order_by'} eq 'Action') {
      $orderBy = " log_actions.name $order_type, log.date_time DESC ";
   } elsif($openprint::param{'order_by'} eq 'IPAddress') {
      $orderBy = " log.ip_address $order_type, log.date_time DESC ";
   } elsif( sets::isin( $openprint::param{'order_by'}, ['URL','Note','Email'] ) ) {
      $orderBy = " log.$openprint::param{'order_by'} $order_type, log.date_time DESC ";
   } elsif($openprint::param{'order_by'} eq 'Name') {
      $orderBy = " Users.strlastname $order_type, Users.strfirstname $order_type, log.date_time DESC ";
   } elsif($openprint::param{'order_by'} eq 'When') {
      $orderBy = " log.date_time $order_type";
   } else {
      $orderBy = " log.date_time DESC ";
   }

   if($limit > 0) {
      $limit_qry .= ' LIMIT ? ';
      push(@limit_params, $limit,);
   }

   if($offset > 0) {
      $offset_qry = ' OFFSET ? ';
      push(@limit_params, $offset,);
   }
   
   # Set date range query if any.
   #if($openprint::param{'dateRange'} eq 'on') {
      $startDate = sprintf('%.4d-%.2d-%.2d 00:00:00', @openprint::param{'StartYear','StartMonth','StartDay'} );
      $endDate = sprintf('%.2d-%.2d-%.2d 23:59:59', @openprint::param{'EndYear','EndMonth','EndDay'} );
      $dateRange_qry  = ' AND ' if(scalar(@action_types));
      $dateRange_qry .= ' log.date_time BETWEEN ? AND ?';
      push(@date_params,$startDate);
      push(@date_params,$endDate);
   #}
   
   $whereMarker = " WHERE " if($log_actions_qry || $dateRange_qry);

   $sql = qq~   
      SELECT 
         log.id AS logId
      FROM
         log 
      $whereMarker
         $log_actions_qry 
         $dateRange_qry 
      ORDER BY $orderBy 
      $limit_qry 
      $offset_qry 
   ~;
   
   @sql_results = sql::execute( $openprint::log, $openprint::dbh, $sql, @action_types, @date_params, @limit_params,);
   
   while(@sql_results) {
      push @log_records, new openprint::logRecord( shift @sql_results );
   }
      
   return \@log_records;
}

sub getTotalResults {
   my $sql;
   my $log_actions_qry;
   my $totalResults;
   my $startDate;
   my $endDate;
   my $dateRange_qry;
   my $whereMarker;
   
   my @action_types;
   my @log_actions;
   my @date_params;
   
   foreach my $log_action (ref $openprint::param{'log_actions'} eq 'ARRAY' ? @{$openprint::param{'log_actions'}} : $openprint::param{'log_actions'} ) {
      push(@action_types, $log_action,);
   }
   
   if(scalar(@action_types)) {
      for(my $i = 0; $i < scalar(@action_types); $i++) {
         push(@log_actions, 'log.action_type = ?',);
      }
      $log_actions_qry = join(' OR ', @log_actions,);
      $log_actions_qry = "( $log_actions_qry ) ";
   }

   # Set date range query if any.
   if($openprint::param{'dateRange'} eq 'on') {
      $startDate = $openprint::param{'StartYear'} . '-' . $openprint::param{'StartMonth'} . '-' . $openprint::param{'StartDay'};
      $endDate = $openprint::param{'EndYear'} . '-' . $openprint::param{'EndMonth'} . '-' . $openprint::param{'EndDay'};
      $dateRange_qry  = " AND " if(scalar(@action_types));
      $dateRange_qry .= " log.date_time BETWEEN to_date(?,'YYYY-MM-DD') AND to_date(?,'YYYY-MM-DD'); ";
      push(@date_params,$startDate);
      push(@date_params,$endDate);
   }
   
   $whereMarker = " WHERE " if($log_actions_qry || $dateRange_qry);
   
   # Get total results.
   $sql = qq~ SELECT COUNT(id) FROM log $whereMarker $log_actions_qry $dateRange_qry ~;
   
   ( $totalResults ) = sql::execute( $openprint::log, $openprint::dbh, $sql, @action_types, @date_params,);

   return $totalResults;
}

sub getPages {
   my $totalResults;       # Total search results.
   my $paginationResults;  # Referense to pagination results hash.
   
   my $limit;  # Number of search results per page.
   my $offset; # Start position of search.
   my $radius; # Number of pages to link to.
   
   my $pagesHTML;
   
   $limit = ($openprint::param{'resultsLimit'} > 0) ? $openprint::param{'resultsLimit'} : 25;
   $offset = $openprint::param{'offset'};
   $radius = 4;
   
   $totalResults = getTotalResults();

   $paginationResults = openprint::pagination::calculateOutput($totalResults,$radius,$offset+1,$limit,);
   
   $pagesHTML  = '<div id="resultsSummary">Results ' . $paginationResults->{offset} . '-' . $paginationResults->{resultsEnd} . ' of ' . $totalResults . "</div>\n";
   $pagesHTML .= '<div id="pages">' . "\n";
   if($paginationResults->{previousOffset} != -1) {
      $pagesHTML .= '<a href="javascript:void(0);" class="nextprev" title="Go to Previous Page" onclick="setCurrentDateRangeParams();setResultsLimit(\'' . $limit . '\');newOffset(\'' . ($paginationResults->{previousOffset} - 1) . '\');">&#171; Previous</a>';
   } else {
      $pagesHTML .= '<span class="nextprev">&#171; Previous</span>';
   }
   foreach my $page ( @{$paginationResults->{pages}} ) {
      if($page->{currentPage}) {
         $pagesHTML .= '<span id="currentPage">' . $page->{pageNumber} . '</span>' . "\n";
      } else {
         $pagesHTML .= '<a href="javascript:void(0);" title="Goto page ' . $page->{pageNumber} . '" onclick="setCurrentDateRangeParams();setResultsLimit(\'' . $limit . '\');newOffset(\'' . ($page->{newCursor} - 1) . '\');">' . $page->{pageNumber} . '</a>' . "\n";
      }
   }
   if($paginationResults->{nextOffset} != -1) {
      $pagesHTML .= '<a href="javascript:void(0);" class="nextprev" title="Go to Next Page" onclick="setCurrentDateRangeParams();setResultsLimit(\'' . $limit . '\');newOffset(\'' . ($paginationResults->{nextOffset} - 1) . '\');">Next &#187;</a>';
   } else {
      $pagesHTML .= '<span class="nextprev">Next &#187;</span>';
   }
   $pagesHTML .= '</div>';
   
   return $pagesHTML;
}

1;
__END__
