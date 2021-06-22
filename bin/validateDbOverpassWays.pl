#! /usr/bin/perl -w -CSDA
# Compare node membership of ways on OGF OSM API vs Overpass API

use strict;
use warnings;
use LWP::Simple;
use OGF::Util::Usage qw( usageInit usageError );

my $BASE     = 'https://opengeofiction.net';
my $API      = "$BASE/api/0.6";
my $OVERPASS = "https://osm3s.opengeofiction.net/api/interpreter?";

#https://opengeofiction.net/api/0.6/way/84239
#https://osm3s.opengeofiction.net/api/interpreter?data=way(84239);out;


my %opt;
usageInit( \%opt, qq/ h start=i end=i full /, << "*" );
[-start <wayid> -end <wayid> -full -fullfull]

-start    start list at this way id (default  1)
-end      end list at this way id   (default 10)
-full     include ways which do not have issues
*
usageError() if $opt{'h'};
my $START_ID = $opt{'start'} ||  1;
my $END_ID   = $opt{'end'}   || 10;
my $FULL     = $opt{'full'} ? 1 : 0;
print STDERR "Ways: $START_ID > $END_ID\n";

print "way id,status,api,overpass,missing nodes,api url,overpass url\n";
for( my $wayid = $START_ID; $wayid <= $END_ID; $wayid++ )
{
	my $url_api = "$API/way/$wayid";
	my $url_op  = $OVERPASS . "data=way($wayid);out;";
	
	my $content_api   = get($url_api);
	my $content_op    = get($url_op);
	my $status        = 'ok';
	my $missing_nodes = '';
	my $api           = defined $content_api ? 'Y' : 'N';
	my $op            = defined $content_op  ? 'Y' : 'N';
	my $op_nodes      = 0;
	if( defined $content_api and defined $content_op )
	{
		my %nodes = ();
		
		# build up hash of nodes present in the inputs, poor man's XML parsing, too many Perl years 
		foreach my $line ( split "\n", $content_api )
		{
			if( $line =~ /<nd ref=\"(\d+)\"\/>/ )
			{
				$nodes{$1} = 0 if( !exists $nodes{$1} );
				$nodes{$1}++;
			}
		}
		foreach my $line ( split "\n", $content_op )
		{
			if( $line =~ /<nd ref=\"(\d+)\"\/>/ )
			{
				$nodes{$1} = 0 if( !exists $nodes{$1} );
				$nodes{$1}++;
				$op_nodes++;
			}
		}
		
		# any nodes with < 2 occurances is a problem...
		foreach my $node ( sort keys %nodes )
		{
			if( $nodes{$node} < 2 )
			{
				$missing_nodes .= ';' if( $missing_nodes ne '' );
				$missing_nodes .= $node;
				$status         = 'mismatch';
			}
		}
	}
	elsif( !defined $content_api or !defined $content_op )
	{
		$status = 'invalid' if( (defined $content_op and $op_nodes > 0) and !defined $content_api );
	}
		
	$op = 'N' if( $op_nodes == 0 );
	my $output = 0;
	$output = 1 if( $status eq 'invalid' );
	$output = 1 if( $status eq 'mismatch' );
	$output = 1 if( $status eq 'ok' and $FULL == 1 );
	if( $output == 1 )
	{
		print STDERR "Way: $wayid\n" if( $wayid % 100 == 0 );
		print STDERR "ERROR: $wayid - unexpected overpass without api entry\n" if( $status eq 'invalid' );
		print STDERR "ERROR: $wayid - $missing_nodes\n" if( $status eq 'mismatch' );
		print "$wayid,$status,$api,$op,$missing_nodes";
		print ",$url_api,$url_op" if( $status ne 'ok' );
		print "\n";
	}
}
