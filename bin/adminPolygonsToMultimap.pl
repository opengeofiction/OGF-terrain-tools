#! /usr/bin/perl -w

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use JSON::PP;
use URI::Escape;
use Date::Format;
use OGF::Geo::Topology;
use OGF::Util::File;
use OGF::Util::Line;
use OGF::Data::Context;
use OGF::View::TileLayer;
use OGF::Util::Usage qw( usageInit usageError );

sub parseDrivingSide($);
sub parseEconomy($);
sub parseEconomyHdi($);
sub parseEconomyHdiRange($);
sub parseEconomyNote($);
sub parseRailGauge($);
sub parseGovernance($);
sub parseGovernanceStructure($);
sub parseContinent($$);
sub parseRegion($);

my %opt;
usageInit( \%opt, qq/ h ogf ds=s od=s copyto=s /, << "*" );
[-ds <dataset>] [-od <output_directory>] [-copyto <publish_directory>]

-ds     "test" or empty
-od     Location to output JSON files
-copyto Location to publish JSON files for wiki use
*

my( $osmFile ) = @ARGV;
usageError() if $opt{'h'};

my $OUTPUT_DIR  = $opt{'od'}     || '/tmp';
my $PUBLISH_DIR = $opt{'copyto'} || '/tmp';
my($OUTFILE_NAME, $ADMIN_RELATION_QUERY);

if( ! $opt{'ds'} )
{
	$OUTFILE_NAME = 'admin_properties';
	$ADMIN_RELATION_QUERY = << '---EOF---';
[timeout:1800][maxsize:4294967296];
(relation["boundary"="administrative"]["admin_level"="2"];
 relation["boundary"="protected_area"]["ogf:id"];
 relation["boundary"="administrative"]["ogf:id"~"^((UL|TA|AN|AR|ER|KA|OR|PE)[0-9]{3}[a-z]?|(AR060|AR120|UL106|AR001b)-[0-9]{2}|AR045-[0-9]{2}|AR045-(01|03|10)[a-z]|UL[0-9]{2}[a-z]+)$"];);
out;
---EOF---

}
elsif( $opt{'ds'} eq 'test' )
{
	$OUTFILE_NAME = 'test_admin_properties';
	$ADMIN_RELATION_QUERY = << '---EOF---';
[timeout:1800][maxsize:4294967296];
(relation["boundary"="administrative"]["ogf:id"="UL05a"];);
out;
---EOF---
}
else
{
	die qq/Unknown dataset: "$opt{ds}"/;
}

# an .osm file can be specified as the last commandline argument, otherwise get from Overpass
if( ! $osmFile )
{
	$osmFile = $OUTPUT_DIR . '/' . $OUTFILE_NAME . '_'. time2str('%Y%m%d%H%M%S', time) .'.osm';
	fileExport_Overpass( $osmFile ) if ! -f $osmFile;
}

my $ctx = OGF::Data::Context->new();
$ctx->loadFromFile( $osmFile );
$ctx->setReverseInfo();

# for each territory
my @ters;
foreach my $rel ( values %{$ctx->{_Relation}} )
{
	my %ter = ();
	next if( !defined $rel->{'id'} );
	next if( !defined $rel->{'tags'}{'ogf:id'} );
	next if( $rel->{'tags'}{'ogf:id'} !~ /^(AN|AR|BG|ER|KA|OR|PE|TA|UL)\d\d/ );
	
	$ter{'rel'}                  = $rel->{'id'};
	$ter{'ogf:id'}               = $rel->{'tags'}{'ogf:id'};
	$ter{'name'}                 = $rel->{'tags'}{'name'}            || $rel->{'tags'}{'ogf:id'};
	
	$ter{'driving_side'}         = parseDrivingSide $rel->{'tags'}{'driving_side'};
	$ter{'economy'}              = parseEconomy $rel->{'tags'}{'economy'};
	$ter{'economy:hdi'}          = parseEconomyHdi $rel->{'tags'}{'economy:hdi'};
	$ter{'economy:hdi:range'}    = parseEconomyHdiRange $ter{'economy:hdi'};
	$ter{'economy:note'}         = parseEconomyNote $rel->{'tags'}{'economy:note'};
	$ter{'gauge'}                = parseRailGauge $rel->{'tags'}{'gauge'};
	$ter{'governance'}           = parseGovernance $rel->{'tags'}{'governance'};
	$ter{'governance:structure'} = parseGovernanceStructure $rel->{'tags'}{'governance:structure'};
	$ter{'is_in:continent'}      = parseContinent $rel->{'tags'}{'is_in:continent'}, $rel->{'tags'}{'ogf:id'};
	$ter{'is_in:region'}         = parseRegion $rel->{'tags'}{'is_in:region'};
	
	push @ters, \%ter;
}

my $publishFile = $PUBLISH_DIR . '/' . $OUTFILE_NAME . '.json';
my $json = JSON::PP->new->canonical->indent(2)->space_after;
my $text = $json->encode( \@ters );
OGF::Util::File::writeToFile($publishFile, $text, '>:encoding(UTF-8)' );

#-------------------------------------------------------------------------------

sub parseDrivingSide($)
{
	my($var) = @_;
	
	return 'assumed_right' if( !defined $var );
	return 'left'          if( lc $var eq 'left' );
	return 'right'         if( lc $var eq 'right' );
	return 'mixed'         if( lc $var eq 'mixed' );
	return 'unknown'; 
}

sub parseEconomy($)
{
	my($var) = @_;
	
	return $var + 0 if( defined $var and $var =~ /^\d\d$/ );
	return '90';
}

sub parseEconomyHdi($)
{
	my($var) = @_;
	
	return $var + 0.0 if( defined $var and $var =~ /^[\d\.]+$/ and $var >= 0.0 and $var <= 1.0 );
	return '';
}

sub parseEconomyHdiRange($)
{
	my($var) = @_;
	
	return 'unknown' if( !defined $var or $var eq '' );
	
	return 'low'      if( $var >= 0.00 and $var <  0.55 );
	return 'medium'   if( $var >= 0.55 and $var <  0.70 );
	return 'high'     if( $var >= 0.70 and $var <  0.80 );
	return 'veryhigh' if( $var >= 0.80 and $var <= 1.00 );
	
	return 'unknown';
}

sub parseEconomyNote($)
{
	my($var) = @_;
	
	return substr $var, 0, 100 if( defined $var );
	return '';
}

sub parseRailGauge($)
{
	my($var) = @_;
	
	return '0' if( !defined $var );
	return $var + 0 if( $var =~ /^[\d]{1,4}$/ );
	return 'error';
}

sub parseGovernance($)
{
	my($var) = @_;
	
	return $var + 0 if( defined $var and $var =~ /^\d\d$/ );
	return '90';
}

sub parseGovernanceStructure($)
{
	my($var) = @_;
	
	return lc $var if( defined $var and $var =~ /^(decentralized|federation|unitary)$/i );
	return 'unknown';
}

sub parseContinent($$)
{
	my($cont, $ogfId) = @_;
	
	return 'Unknown' if( !defined $cont and !defined $ogfId );
	return $cont if( defined $cont and $cont =~ /^(Antarephia|Beginner|East Uletha|Ereva|Kartumia|North Archanta|Orano|Pelanesia|South Archanta|Tarephia|West Uletha)$/ );
	return 'Antarephia' if( defined $ogfId and $ogfId =~ /^AN/ );
	#return 'Archanta' if( defined $ogfId and $ogfId =~ /^AR/ );
	return 'Beginner' if( defined $ogfId and $ogfId =~ /^BG/ );
	return 'Ereva' if( defined $ogfId and $ogfId =~ /^ER/ );
	return 'Kartumia' if( defined $ogfId and $ogfId =~ /^KA/ );
	return 'Orano' if( defined $ogfId and $ogfId =~ /^OR/ );
	return 'Pelanesia' if( defined $ogfId and $ogfId =~ /^PE/ );
	return 'Tarephia' if( defined $ogfId and $ogfId =~ /^TA/ );
	return 'West Uletha' if( defined $ogfId and $ogfId =~ /^UL(\d\d)/ and $1 <= 17 );
	return 'East Uletha' if( defined $ogfId and $ogfId =~ /^UL(\d\d)/ and $1 >= 18 );
	return 'Unknown';
}

sub parseRegion($)
{
	my($var) = @_;
	
	return $var if( defined $var and $var =~ /^[a-zA-Z ]+/ );
	return 'Unknown';
}

#-------------------------------------------------------------------------------

sub fileExport_Overpass {
	require OGF::Util::Overpass;
	my( $outFile ) = @_;

	my $data = OGF::Util::Overpass::runQuery_remote( undef, $ADMIN_RELATION_QUERY );
	OGF::Util::File::writeToFile( $outFile, $data, '>:encoding(UTF-8)' );
}
