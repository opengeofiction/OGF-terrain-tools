#! /usr/bin/perl -w -CSDA
# 

print "time|ip|request|user agent\n";
while( <STDIN> )
{
	# chomp & condense one or more whitespace character to one single space
	chomp; s/\s+/ /go;

	#  break each apache access_log record into nine variables
	my($ip, undef, undef, $datetime, $http_request, undef, undef, undef, $user_agent) = /^(\S+) (\S+) (\S+) \[(.+)\] \"(.+)\" (\S+) (\S+) \"(.*)\" \"(.*)\"/o;
	$datetime = $1 if( $datetime =~ /:(\d{2}:\d{2}:\d{2})/ );
	print "$datetime|$ip|$http_request|$user_agent\n";
}
