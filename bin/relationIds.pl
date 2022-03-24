#! /usr/bin/perl -w
# Print out relation IDs

use LWP;
use URI::Escape;
use Encode;
use utf8;

$OVERPASS = 'https://osm3s.opengeofiction.net/api/interpreter?data=';
$QUERY = qq(rel["type"="boundary"]["admin_level"]["ogf:id"~"^Guai"];out;);
$URL = $OVERPASS . uri_escape($QUERY);

# load map relations
$userAgent = LWP::UserAgent->new(keep_alive => 20);
$resp = $userAgent->get($URL);
print STDERR "URL: $URL\n";
my $i = 0;
foreach ( split "\n", decode('utf-8', $resp->content) )
{
	if( /<relation id=\"(\d+)\"/ )
	{
		$rel = $1;
		print "$rel,";
		if( ++$i >= 10 )
		{
			$i = 0;
			print "\n";
		}
	}
}
print "\n";

