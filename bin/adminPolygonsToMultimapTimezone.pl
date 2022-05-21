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

sub parseTimezone($);
sub parseTimezoneName($$);
sub parseTimezoneDst($);
sub parseTimezoneNote($);
sub parseTimezoneStyle($);

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
	$OUTFILE_NAME = 'admin_properties_timezone';
	$ADMIN_RELATION_QUERY = << '---EOF---';
[timeout:1800][maxsize:4294967296];
(relation["boundary"="administrative"]["ogf:id"]["timezone"];
 relation["boundary"="timezone"]["timezone"];);
out;
---EOF---
}
elsif( $opt{'ds'} eq 'test' )
{
	$OUTFILE_NAME = 'test_admin_properties_timezone';
	$ADMIN_RELATION_QUERY = << '---EOF---';
[timeout:1800][maxsize:4294967296];
(relation["boundary"="administrative"]["ogf:id"]["timezone"];
 relation["boundary"="timezone"]["timezone"];);
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
	
	$ter{'rel'}            = $rel->{'id'};
	$ter{'ogf:id'}         = $rel->{'tags'}{'ogf:id'} || '';
	$ter{'timezone'}       = parseTimezone $rel->{'tags'}{'timezone'};
	next if( !defined $ter{'timezone'} );
	
	$ter{'timezone:name'}  = parseTimezoneName  $rel->{'tags'}{'timezone:name'}, $rel->{'tags'}{'name'};
	$ter{'timezone:dst'}   = parseTimezoneDst   $rel->{'tags'}{'timezone:dst'};
	$ter{'timezone:note'}  = parseTimezoneNote  $rel->{'tags'}{'timezone:note'};
	$ter{'timezone:style'} = parseTimezoneStyle $ter{'timezone'};
	
	push @ters, \%ter;
}

my $publishFile = $PUBLISH_DIR . '/' . $OUTFILE_NAME . '.json';
my $json = JSON::PP->new->canonical->indent(2)->space_after;
my $text = $json->encode( \@ters );
OGF::Util::File::writeToFile($publishFile, $text, '>:encoding(UTF-8)' );

#-------------------------------------------------------------------------------

sub parseTimezone($)
{
	my($var) = @_;
	
	return undef if( !defined $var );
	return "$1:00" if( $var =~ /^([+\-]\d{2})$/ );
	return "$1:$2" if( $var =~ /^([+\-]\d{2}):(00|30)$/ );
	return undef;
}

sub parseTimezoneName($$)
{
	my($var1, $var2) = @_;
	return uc substr $var1, 0, 10 if( defined $var1 );
	return uc substr $var2, 0, 10 if( defined $var2 );
	return 'UNKNOWN';
}

sub parseTimezoneDst($)
{
	my($var) = @_;
	
	return 'yes' if( defined $var and lc $var eq 'yes' );
	return 'no'  if( defined $var and lc $var eq 'no' );
	return ''; 
}

sub parseTimezoneNote($)
{
	my($var) = @_;
	
	return substr $var, 0, 100 if( defined $var );
	return '';
}

sub parseTimezoneStyle($)
{
	my($tz) = @_; 
	my $hr = $1 if( $tz =~ /^([+\-]\d{2})/ );
	my @styles = ('A', 'B', 'C'); # 3 style bands
	my $style = $styles[$hr % @styles];
	my $mins  = $1 if( $tz =~ /^[+\-]\d{2}:(00|30)$/ );
	my $mod   = $mins == 30 ? 'x' : '';
	return 'TZ_' . $style . $mod;
}


#-------------------------------------------------------------------------------

sub fileExport_Overpass {
	require OGF::Util::Overpass;
	my( $outFile ) = @_;

	my $data = OGF::Util::Overpass::runQuery_remote( undef, $ADMIN_RELATION_QUERY );
	OGF::Util::File::writeToFile( $outFile, $data, '>:encoding(UTF-8)' );
}
