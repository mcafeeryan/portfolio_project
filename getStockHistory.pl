my @sqlinput  = ();
my @sqloutput = ();

#
# The combination of -w and use strict enforces various
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);
use Time::Local;

# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;
use Finance::QuoteHist::Yahoo;
use Date::Manip;
use Time::CTime;

BEGIN {
	$ENV{PORTF_DBMS}   = "oracle";
	$ENV{PORTF_DB}     = "cs339";
	$ENV{PORTF_DBUSER} = "rpm267";
	$ENV{PORTF_DBPASS} = "Qea42wvW";

	unless ( $ENV{BEGIN_BLOCK} ) {
		use Cwd;
		$ENV{ORACLE_BASE}     = "/raid/oracle11g/app/oracle/product/11.2.0.1.0";
		$ENV{ORACLE_HOME}     = $ENV{ORACLE_BASE} . "/db_1";
		$ENV{ORACLE_SID}      = "CS339";
		$ENV{LD_LIBRARY_PATH} = $ENV{ORACLE_HOME} . "/lib";
		$ENV{BEGIN_BLOCK}     = 1;
		exec 'env', cwd() . '/' . $0, @ARGV;
	}
}

use stock_data_access;

#
# You need to override these for access to your database
#
my $dbuser   = "rpm267";
my $dbpasswd = "Qea42wvW";
GetHistoryAll();
sub GetHistoryAll{
	my @rows
	eval {
		@rows = ExecSQL(
			$dbuser,
			$dbpasswd,
			"select symbol from new_stocks_daily",
			"COL"
		);
	};
	foreach (@rows){GetHistory($_);}
	return 1;
}
sub GetHistory {
	my ($symb) = @_;
	my $qsymbol;
	my $qdate;
	my $qopen;
	my $qhigh;
	my $qlow;
	my $qclose;
	my $qvolume;
	my $q;
	my $row;
	my $symbol;
	my $latestTS;
	$symb = uc($symb);

	if ( !UpToDate($symb) && inSymbs($symb) ) {
		$latestTS=GetLatestTS($symb);
		if(!$latestTS)
		{$latestTS=1154390400;}
		$q = Finance::QuoteHist::Yahoo->new(
			symbols    => $symb,
			start_date => scalar localtime($latestTS),
			end_date   => 'today',
		  )
		  or die;
		foreach $row ( $q->quotes() ) {
			( $qsymbol, $qdate, $qopen, $qhigh, $qlow, $qclose, $qvolume ) =
			  @$row;
			$qdate = parsedate($qdate);
			eval {
				ExecSQL(
					$dbuser,
					$dbpasswd,
					"insert into new_stocks_daily (symbol, timestamp, open,close, high, low, volume) values (?,?,?,?,?,?,?)",
					"NA",
					$qsymbol,
					$qdate,
					$qopen,
					$qclose,
					$qhigh,
					$qlow,
					$qvolume
				);
			};
		}
	}
}
sub GetLatestTS{
	my ($symb)=@_;
	$symb=uc($symb);
	my @col;
	eval {
		@col =
		  ExecSQL( $dbuser, $dbpasswd,
			"select max(timestamp) from new_stocks_daily where symbol=rpad(?,16)",
			"COL", $symb );
	};
	if ($@) {
		return 0;
	}
	else {
		return $col[0];
	}
}
sub UpToDate {
	my ($symb) = @_;
	$symb = uc($symb);
	my @col;
	eval {
		@col =
		  ExecSQL( $dbuser, $dbpasswd,
			"select max(timestamp) from new_stocks_daily where symbol=rpad(?,16)",
			"COL", $symb );
	};
	if ($@) {
		return 0;
	}
	else {
		return ($col[0] >= (time()-86400));
	}
}

sub inSymbs {
	my ($symb) = @_;
	$symb = uc($symb);
	my @col;
	eval {
		@col = ExecSQL(
			$dbuser,
			$dbpasswd,
			"select count(*) from cs339.stockssymbols where symbol=rpad(?,16)",
			"COL",
			$symb
		);
	};
	if ($@) {
		return 0;
	}
	else {
		return $col[0] > 0;
	}
}
sub MakeTable {
	my ( $id, $type, $headerlistref, @list ) = @_;
	my $out;

	#
	# Check to see if there is anything to output
	#
	if ( ( defined $headerlistref ) || ( $#list >= 0 ) ) {

		# if there is, begin a table
		#
		$out = "<table id=\"$id\" border>";

		#
		# if there is a header list, then output it in bold
		#
		if ( defined $headerlistref ) {
			$out .= "<tr>"
			  . join( "", ( map { "<td><b>$_</b></td>" } @{$headerlistref} ) )
			  . "</tr>";
		}

		#
		# If it's a single row, just output it in an obvious way
		#
		if ( $type eq "ROW" ) {

		   #
		   # map {code} @list means "apply this code to every member of the list
		   # and return the modified list.  $_ is the current list member
		   #
			$out .= "<tr>"
			  . ( map { defined($_) ? "<td>$_</td>" : "<td>(null)</td>" }
				  @list )
			  . "</tr>";
		}
		elsif ( $type eq "COL" ) {

			#
			# ditto for a single column
			#
			$out .= join(
				"",
				map {
					defined($_)
					  ? "<tr><td>$_</td></tr>"
					  : "<tr><td>(null)</td></tr>"
				  } @list
			);
		}
		else {

			#
			# For a 2D table, it's a bit more complicated...
			#
			$out .= join(
				"",
				map { "<tr>$_</tr>" } (
					map {
						join(
							"",
							map {
								defined($_)
								  ? "<td>$_</td>"
								  : "<td>(null)</td>"
							  } @{$_}
						  )
					  } @list
				)
			);
		}
		$out .= "</table>";
	}
	else {

		# if no header row or list, then just say none.
		$out .= "(none)";
	}
	return $out;
}

#
# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
#
sub MakeRaw {
	my ( $id, $type, @list ) = @_;
	my $out;

	#
	# Check to see if there is anything to output
	#
	$out = "<pre id=\"$id\">\n";

	#
	# If it's a single row, just output it in an obvious way
	#
	if ( $type eq "ROW" ) {

		#
		# map {code} @list means "apply this code to every member of the list
		# and return the modified list.  $_ is the current list member
		#
		$out .= join( "\t", map { defined($_) ? $_ : "(null)" } @list );
		$out .= "\n";
	}
	elsif ( $type eq "COL" ) {

		#
		# ditto for a single column
		#
		$out .= join( "\n", map { defined($_) ? $_ : "(null)" } @list );
		$out .= "\n";
	}
	else {

		#
		# For a 2D table
		#
		foreach my $r (@list) {
			$out .= join( "\t", map { defined($_) ? $_ : "(null)" } @{$r} );
			$out .= "\n";
		}
	}
	$out .= "</pre>\n";
	return $out;
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
	my ( $user, $passwd, $querystring, $type, @fill ) = @_;
	if ($debug) {

 # if we are recording inputs, just push the query string and fill list onto the
 # global sqlinput list
		push @sqlinput,
		  "$querystring (" . join( ",", map { "'$_'" } @fill ) . ")";
	}
	my $dbh = DBI->connect( "DBI:Oracle:", $user, $passwd );
	if ( not $dbh ) {

	   # if the connect failed, record the reason to the sqloutput list (if set)
	   # and then die.
		if ($debug) {
			push @sqloutput,
			  "<b>ERROR: Can't connect to the database because of "
			  . $DBI::errstr . "</b>";
		}
		die "Can't connect to database because of " . $DBI::errstr;
	}
	my $sth = $dbh->prepare($querystring);
	if ( not $sth ) {

		#
		# If prepare failed, then record reason to sqloutput and then die
		#
		if ($debug) {
			push @sqloutput,
			  "<b>ERROR: Can't prepare '$querystring' because of "
			  . $DBI::errstr . "</b>";
		}
		my $errstr = "Can't prepare $querystring because of " . $DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}
	if ( not $sth->execute(@fill) ) {

		#
		# if exec failed, record to sqlout and die.
		if ($debug) {
			push @sqloutput,
			  "<b>ERROR: Can't execute '$querystring' with fill ("
			  . join( ",", map { "'$_'" } @fill )
			  . ") because of "
			  . $DBI::errstr . "</b>";
		}
		my $errstr =
		    "Can't execute $querystring with fill ("
		  . join( ",", map { "'$_'" } @fill )
		  . ") because of "
		  . $DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}

	#
	# The rest assumes that the data will be forthcoming.
	#
	#
	my @data;
	if ( defined $type and $type eq "ROW" ) {
		@data = $sth->fetchrow_array();
		$sth->finish();
		if ($debug) {
			push @sqloutput,
			  MakeTable( "debug_sqloutput", "ROW", undef, @data );
		}
		$dbh->disconnect();
		return @data;
	}
	my @ret;
	if ( !( $type eq "NA" ) ) {
		while ( @data = $sth->fetchrow_array() ) {
			push @ret, [@data];
		}
	}
	if ( defined $type and $type eq "COL" ) {
		@data = map { $_->[0] } @ret;
		$sth->finish();
		if ($debug) {
			push @sqloutput,
			  MakeTable( "debug_sqloutput", "COL", undef, @data );
		}
		$dbh->disconnect();
		return @data;
	}
	$sth->finish();
	if ($debug) {
		push @sqloutput, MakeTable( "debug_sql_output", "2D", undef, @ret );
	}
	$dbh->disconnect();
	return @ret;
}

######################################################################
#
# Nothing important after this
#
######################################################################

# The following is necessary so that DBD::Oracle can
# find its butt
#
BEGIN {
	unless ( $ENV{BEGIN_BLOCK} ) {
		use Cwd;
		$ENV{ORACLE_BASE}     = "/raid/oracle11g/app/oracle/product/11.2.0.1.0";
		$ENV{ORACLE_HOME}     = $ENV{ORACLE_BASE} . "/db_1";
		$ENV{ORACLE_SID}      = "CS339";
		$ENV{LD_LIBRARY_PATH} = $ENV{ORACLE_HOME} . "/lib";
		$ENV{BEGIN_BLOCK}     = 1;
		exec 'env', cwd() . '/' . $0, @ARGV;
	}
}