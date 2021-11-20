#! /usr/bin/perl -w -CSDA
# 

my $line = 0;
print "line|status|code|req or result|ip|time|elapsed\n";
while( <STDIN> )
{
	$line++;
	if( /^Started (.+) for (.+) at \d\d\d\d-\d\d-\d\d (\d\d:\d\d:\d\d) / )
	{
		print "$line|started||$1|$2|$3|\n";
	}
	if( /^Completed (\d{3}) (.+) in (\d+)ms/ )
	{
		print "$line|completed|$1|$2|||$3\n";
	}
}
