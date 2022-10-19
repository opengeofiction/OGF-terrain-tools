#! /usr/bin/perl -w

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use feature 'unicode_strings' ;
use Date::Format;
use Encode;
use JSON::PP;
use OGF::Data::Context;
use OGF::Geo::Topology;
use OGF::Util::File;
use OGF::Util::Line;
use OGF::Util::Usage qw( usageInit usageError );
use OGF::View::TileLayer;
use URI::Escape;

sub parseDrivingSide($);
sub parseEconomy($);
sub parseEconomyHdi($);
sub parseEconomyHdiRange($);
sub parseEconomyNote($);
sub parseRailGauge($);
sub parseGovernance($);
sub parseGovernanceStructure($);
sub parseHistoryEstablished($);
sub parseHistoryEstablishedRange($);
sub parseHistoryIndependenceFrom($);
sub parseHistoryRevolution($);
sub parseContinent($$);
sub parseRegion($);
sub parseOrganization($$$);
sub parsePowerSupply($);
sub parsePowerSupplyVoltage($);
sub parsePowerSupplyFrequency($);
sub parsePowerSupplyRange($$);
sub housekeeping($$);

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

housekeeping $OUTPUT_DIR, time;

if( ! $opt{'ds'} )
{
	$OUTFILE_NAME = 'admin_properties';
	# query takes ~ 10s, returning ~ 1.6 MB; allow up to 60s, 5 MB
	$ADMIN_RELATION_QUERY = << '---EOF---';
[timeout:60][maxsize:5000000];
(relation["boundary"="administrative"]["admin_level"="2"];
 relation["boundary"="protected_area"]["ogf:id"];);
out;
---EOF---

}
elsif( $opt{'ds'} eq 'test' )
{
	$OUTFILE_NAME = 'test_admin_properties';
	$ADMIN_RELATION_QUERY = << '---EOF---';
[timeout:60][maxsize:5000000];
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
exit if( ! -f $osmFile );

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
	$ter{'name'}                 = $rel->{'tags'}{'int_name'} || $rel->{'tags'}{'name'} || $rel->{'tags'}{'ogf:id'};
	$ter{'name'}                 = $ter{'ogf:id'} if( $ter{'name'} =~ /UNDER CONSTRUCTION/ );
	$ter{'is_in:continent'}      = parseContinent $rel->{'tags'}{'is_in:continent'}, $rel->{'tags'}{'ogf:id'};
	
	if( $ter{'ogf:id'} =~ /^(BG|ER|KA|OR|PE)/ and $ter{'ogf:id'} !~ /^KA(073|076|077|078)/ )
	{
		push @ters, \%ter;
		next;
	}
	
	$ter{'ogf:wiki'}             = $rel->{'tags'}{'ogf:wiki'} || $rel->{'tags'}{'ogfwiki'} || $ter{'name'};
	
	$ter{'driving_side'}         = parseDrivingSide $rel->{'tags'}{'driving_side'};
	
	$ter{'economy'}              = parseEconomy $rel->{'tags'}{'economy'};
	$ter{'economy:hdi'}          = parseEconomyHdi $rel->{'tags'}{'economy:hdi'};
	$ter{'economy:hdi:range'}    = parseEconomyHdiRange $ter{'economy:hdi'};
	$ter{'economy:note'}         = parseEconomyNote $rel->{'tags'}{'economy:note'};
	
	$ter{'gauge'}                = parseRailGauge $rel->{'tags'}{'gauge'};
	
	$ter{'governance'}           = parseGovernance $rel->{'tags'}{'governance'};
	$ter{'governance:structure'} = parseGovernanceStructure $rel->{'tags'}{'governance:structure'};
	
	$ter{'history:established'}       = parseHistoryEstablished $rel->{'tags'}{'history:established'};
	$ter{'history:established:range'} = parseHistoryEstablishedRange $ter{'history:established'};
	$ter{'history:independence_from'} = parseHistoryIndependenceFrom $rel->{'tags'}{'history:independence_from'};
	$ter{'history:revolution'}        = parseHistoryRevolution $rel->{'tags'}{'history:revolution'};
	
	$ter{'is_in:region'}         = parseRegion $rel->{'tags'}{'is_in:region'};
	
	my @orgs;
	$ter{'organization:AN'}      = parseOrganization $rel->{'tags'}{'organization:AN'},     'member', ['member', 'no'];
	push @orgs, 'AN' if( $ter{'organization:AN'} ne '' );
	$ter{'organization:AC'}      = parseOrganization $rel->{'tags'}{'organization:AC'},     '',       ['member', 'observer'];
	push @orgs, 'AC' if( $ter{'organization:AC'} ne '' );
	$ter{'organization:ASUN'}    = parseOrganization $rel->{'tags'}{'organization:ASUN'},   '',       ['member', 'observer', 'partner'];
	push @orgs, 'ASUN' if( $ter{'organization:ASUN'} ne '' );
	$ter{'organization:Egalia'}  = parseOrganization $rel->{'tags'}{'organization:Egalia'}, '',       ['member', 'observer'];
	push @orgs, 'Egalia' if( $ter{'organization:Egalia'} ne '' );
	$ter{'organization:IC'}      = parseOrganization $rel->{'tags'}{'organization:IC'},     '',       ['member', 'observer'];
	push @orgs, 'IC' if( $ter{'organization:IC'} ne '' );
	$ter{'organization:TCC'}     = parseOrganization $rel->{'tags'}{'organization:TCC'},    '',       ['member', 'observer'];
	push @orgs, 'TCC' if( $ter{'organization:TCC'} ne '' );
	$ter{'organizations'} = \@orgs;
	
	$ter{'power_supply'}           = parsePowerSupply $rel->{'tags'}{'power_supply'};
	$ter{'power_supply:voltage'}   = parsePowerSupplyVoltage $rel->{'tags'}{'power_supply:voltage'};
	$ter{'power_supply:frequency'} = parsePowerSupplyFrequency $rel->{'tags'}{'power_supply:frequency'};
	$ter{'power_supply:range'}     = parsePowerSupplyRange $ter{'power_supply:voltage'}, $ter{'power_supply:frequency'};
	
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
	
	return 'right' if( !defined $var );
	return 'left'  if( lc $var eq 'left' );
	return 'right' if( lc $var eq 'right' );
	return 'mixed' if( lc $var eq 'mixed' );
	return 'unknown'; 
}

sub parseEconomy($)
{
	my($var) = @_;
	
	return $var + 0 if( defined $var and $var =~ /^\d\d$/ );
	return 90;
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
	return 90;
}

sub parseGovernanceStructure($)
{
	my($var) = @_;
	
	return lc $var if( defined $var and $var =~ /^(decentralized|federation|unitary)$/i );
	return 'unknown';
}

sub parseHistoryEstablished($)
{
	my($var) = @_;
	
	return $var + 0 if( defined $var and $var =~ /^\d{4}$/ );
}

sub parseHistoryEstablishedRange($)
{
	my($var) = @_;
	
	return 'unknown' if( !defined $var or $var eq '' );
	
	return 'pre-1000'  if( $var < 1000 );
	return '1000-1499' if( $var < 1500 );
	return '1500-1699' if( $var < 1700 );
	return '1700-1799' if( $var < 1800 );
	return '1800-1899' if( $var < 1900 );
	return '1900-1949' if( $var < 1950 );
	return '1950-1999' if( $var < 2000 );
	return 'post-2000' if( $var >= 2000 );
	
	return 'unknown';
}

sub parseHistoryIndependenceFrom($)
{
	my($var) = @_;
	
	return substr $var, 0, 100 if( defined $var );
}

sub parseHistoryRevolution($)
{
	my($var) = @_;
	
	return $var + 0 if( defined $var and $var =~ /^\d{4}$/ );
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

sub parseOrganization($$$)
{
	my($var, $default, $values) = @_;
	
	return $default if( !defined $var );
	foreach my $valid ( @$values )
	{
		return $valid if( lc $var eq $valid );
	}
	return $default;
}

sub parsePowerSupply($)
{
	my($var) = @_;
	
	return lc $var if( defined $var and $var =~ /^(europlug|as_3112|bs_1363|bs_546|nema_5_15|sev_1011|cei_23_16)$/i );
	return 'other';
}

sub parsePowerSupplyVoltage($)
{
	my($var) = @_;
	
	return $var + 0 if( defined $var and $var =~ /^\d{3}$/ );
}

sub parsePowerSupplyFrequency($)
{
	my($var) = @_;
	
	return $var + 0 if( defined $var and $var =~ /^\d{2}$/ );
}

sub parsePowerSupplyRange($$)
{
	my($v, $f) = @_;
	
	return 'other' if( !defined $v or !defined $f );
	
	my $v_range = undef;
	$v_range = 100 if( $v >=  90 and $v <  105 );
	$v_range = 110 if( $v >= 105 and $v <  115 );
	$v_range = 120 if( $v >= 115 and $v <= 130 );
	$v_range = 220 if( $v >= 210 and $v <  225 );
	$v_range = 230 if( $v >= 225 and $v <  235 );
	$v_range = 240 if( $v >= 235 and $v <= 245 );
	
	my $f_range = undef;
	$f_range = 50 if( $f >= 45 and $f < 55 );
	$f_range = 60 if( $f >= 55 and $f < 65 );
	
	return 'other' if( !defined $v_range or !defined $f_range );
	return "$v_range-$f_range";
}

#-------------------------------------------------------------------------------

sub fileExport_Overpass {
	require OGF::Util::Overpass;
	my( $outFile ) = @_;

	my $data = decode('utf-8', OGF::Util::Overpass::runQuery_remoteRetry(undef, $ADMIN_RELATION_QUERY, 10000));
	OGF::Util::File::writeToFile( $outFile, $data, '>:encoding(UTF-8)' ) if( defined $data );
}

sub housekeeping($$)
{
	my($dir, $now) = @_;
	my $KEEP_FOR = 60 * 60 * 6 ; # 6 hours
	my $dh;
	
	opendir $dh, $dir;
	while( my $file = readdir $dh )
	{
		next unless( $file =~ /^admin_properties_\d{14}\.osm/ );
		if( $now - (stat "$dir/$file")[9] > $KEEP_FOR )
		{
			print "deleting: $dir/$file\n";
			unlink "$dir/$file";
		}
	}
	closedir $dh;
}