#! /usr/bin/perl -w

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use Date::Format;
use File::Copy;
use OGF::Data::Context;
use OGF::Util::File;
use OGF::Util::Overpass;
use OGF::Util::Usage qw( usageInit usageError );

sub fileExport_Overpass($$);

# parse options
my %opt;
usageInit( \%opt, qq/ h cont=s od=s copyto=s /, << "*" );
[-cont <continent>] [-od <output_directory>] [-copyto <publish_directory>]

-cont   two character continent ID, or unset for all
-od     Location to output JSON files
-copyto Location to publish JSON files for wiki use
*
my( $osmFile ) = @ARGV;
usageError() if $opt{'h'};

my $OUTPUT_DIR  = ($opt{'od'} and -d $opt{'od'}) ? $opt{'od'} : '/tmp';
my $PUBLISH_DIR = ($opt{'copyto'} and -d $opt{'copyto'}) ? $opt{'copyto'} : undef;

# build up Overpass query to get the top level admin_level=0 continent relations
my $idFilter = '["ogf:id"~"^[A-Z]{2}$"]';
$idFilter = '["ogf:id"="' . $opt{'cont'} . '"]' if( $opt{'cont'} );
my $ADMIN_CONTINENT_QUERY = << "---EOF---";
[timeout:1800][maxsize:4294967296];
(
  (relation["type"="boundary"]["boundary"="administrative"]["admin_level"="0"]$idFilter;);
  >;
);
out;
---EOF---

# an .osm file can be specified as the last commandline argument, otherwise get from Overpass
if( ! $osmFile ){
	$osmFile = $OUTPUT_DIR . '/continent_polygons_'. time2str('%y%m%d_%H%M%S',time) .'.osm';
	print "QUERY: $ADMIN_CONTINENT_QUERY\n" if ! -f $osmFile;
    fileExport_Overpass $osmFile, $ADMIN_CONTINENT_QUERY  if ! -f $osmFile;
}

# load in continent relations
my $ctx = OGF::Data::Context->new();
$ctx->loadFromFile( $osmFile );
$ctx->setReverseInfo();

# for each continent
foreach my $rel ( values %{$ctx->{_Relation}} )
{
	my $continent = $rel->{'tags'}{'ogf:id'};
	print "********************************************** $continent\n";
	print "* rel:", $rel->{'id'}, ", continent:", $continent, ", members:", scalar(@{$rel->{'members'}}) ,"\n";
	
	my $overpass = "[out:xml][timeout:1800][maxsize:4294967296];\n(\n";
	
	# for each closed outer ring in the relation
	my $aRelOuter = $rel->closedWayComponents('outer');
	my $closedOuterNum = 0;
	foreach my $way ( @$aRelOuter )
	{
		my $latlons = '';
		$closedOuterNum++;
		print "  * outer:", $closedOuterNum, " firstway:", $way->{'id'}, "\n";
		foreach my $nodeId ( @{$way->{'nodes'}} )
		{
			my $node = $ctx->{_Node}{$nodeId};
			if( ! $node ){
				print STDERR "  invalid node $nodeId (possible Overpass problem)\n";
				next;
			}
			print "   * node:", $nodeId, " (", $node->{'lat'}, ", ", $node->{'lon'}, ")\n";
			$latlons .= ' ' if( $latlons ne '' );
			$latlons .= $node->{'lat'} . ' ' . $node->{'lon'};
		}
		$overpass .= "way[\"natural\"=\"coastline\"](poly:\"$latlons\");\n";
	}
	
	# query all coastlines within the continent using the extracted latlons
	# to limit - normally you'd use the built in overpass support for area
	# filters, but that does not work with the OGF setup
	$overpass .= ");\n(._;>;);\nout meta;\n";
	print "query: $overpass\n";
	my $osmFile = 'coastline-' . $continent . '.osm';
	my $workingFile = $OUTPUT_DIR . '/' . $osmFile;
	print "query Overpass and save to: $workingFile\n";
	fileExport_Overpass $workingFile, $overpass;
	
	# and copy for web
	if( $PUBLISH_DIR )
	{
		my $publishFile = $PUBLISH_DIR . '/' . $osmFile;
		print "publish to: $publishFile\n";
		copy $workingFile, $publishFile;
		print "compress to: $publishFile.gz\n";
		system "gzip -f $publishFile";
	}
}


sub fileExport_Overpass($$)
{
	my( $outFile, $query ) = @_;

    my $data = OGF::Util::Overpass::runQuery_remote( undef, $query );
	OGF::Util::File::writeToFile( $outFile, $data, '>:encoding(UTF-8)' );
}


