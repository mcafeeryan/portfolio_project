#!/usr/bin/perl -w

use Getopt::Long;
use CGI qw(:standard);
#$#ARGV>=2 or die "usage: time_series_symbol_project.pl symbol steps-ahead model \n";

BEGIN {
	$ENV{PORTF_DBMS}   = "oracle";
	$ENV{PORTF_DB}     = "cs339";
	$ENV{PORTF_DBUSER} = "rpm267";
	$ENV{PORTF_DBPASS} = "Qea42wvW";
	$ENV{PATH}=$ENV{PATH} . ":.";


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

# $symbol="AAPL";
# $steps="10";
# $model="AWAIT 100 AR 1";

$symbol=param('symbol');
$steps=param('steps');
$model="AWAIT 100 AR 1";

# my $symbol=param('stock');
# my $steps=param('steps-ahead');
# my $model=join(" ",param('model'));
print "Content-Type: text/plain\r\n\r\n";
system "get_data.pl --notime --close --plot $symbol > _data.in";
system "time_series_project _data.in $steps $model 2>/dev/null";

