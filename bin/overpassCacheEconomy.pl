#! /usr/bin/perl -w

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use feature 'unicode_strings' ;
use Date::Format;
use Encode;
use JSON::XS;
use OGF::Util::File;
use OGF::Util::Overpass;
use OGF::Util::Usage qw( usageInit usageError );

sub parseLatLon($$);
sub parseSector($);
sub parseScope($);
sub parsePermission($);
sub fileExport_Overpass($);
sub housekeeping($$);

my %opt;
usageInit( \%opt, qq/ h ogf ds=s od=s copyto=s /, << "*" );
[-ds <dataset>] [-od <output_directory>] [-copyto <publish_directory>]

-ds     "test" or empty
-od     Location to output JSON files
-copyto Location to publish JSON files for wiki use
*

my( $jsonFile ) = @ARGV;
usageError() if $opt{'h'};

my $OUTPUT_DIR  = $opt{'od'}     || '/tmp';
my $PUBLISH_DIR = $opt{'copyto'} || '/tmp';
my($OUTFILE_NAME, $QUERY);

housekeeping $OUTPUT_DIR, time;

if( ! $opt{'ds'} )
{
	$OUTFILE_NAME = 'economy';
	# query takes ~ 2s, returning ~ 0.1 MB; allow up to 20s, 2 MB
	$QUERY = << '---EOF---';
[timeout:20][maxsize:2000000][out:json];
nwr["headquarters"="main"]["economy:sector"]["economy:iclass"];
out center;
---EOF---
}
elsif( $opt{'ds'} eq 'test' )
{
	die qq/Unknown dataset: "$opt{ds}"/;
}
else
{
	die qq/Unknown dataset: "$opt{ds}"/;
}

# an .json file can be specified as the last commandline argument, otherwise get from Overpass
if( ! $jsonFile )
{
	$jsonFile = $OUTPUT_DIR . '/' . $OUTFILE_NAME . '_'. time2str('%Y%m%d%H%M%S', time) . '.json';
	fileExport_Overpass $jsonFile if( ! -f $jsonFile );
}
exit if( ! -f $jsonFile );

# and now load it in
my $results = undef;
if( open( my $fh, '<', $jsonFile ) )
{
	my $json = JSON::XS->new->utf8();
	my $file_content = do { local $/; <$fh> };
	eval { $results = $json->decode($file_content); 1; }
}
die qq/Cannot load JSON from Overpass/ if( !defined $results );

# for each item in the Overpass results
my @out;
my $records = $results->{elements};
for my $record ( @$records )
{
	my %entry = ();
	
	# if we don't have a name, you're not getting in
	$entry{'id'} = substr($record->{type}, 0, 1) . $record->{id};
	$entry{'name'} = $record->{tags}->{'economy:name'} || $record->{tags}->{name};
	if( !defined $entry{name} )
	{
		print "$entry{'id'} - no name\n";
		next;
	}
	
	# for nodes lat,lon is simple; for ways and relations we're using the
	# "out center" in the Overpass query 
	$entry{'lat'} = parseLatLon $record->{lat}, $record->{center}->{lat};
	$entry{'lon'} = parseLatLon $record->{lon}, $record->{center}->{lon};
	
	# the main tags
	$entry{'economy:iclass'} = $record->{tags}->{'economy:iclass'} || '';
	$entry{'economy:note'} = $record->{tags}->{'economy:note'} || $record->{tags}->{note} || '';
	$entry{'economy:note'} = substr $entry{'economy:note'}, 0, 100; # force < 100 chars
	$entry{'economy:sector'} = parseSector $record->{tags}->{'economy:sector'};
	$entry{'economy:type'} = $record->{tags}->{'economy:type'} || '';
	$entry{'economy:scope'} = parseScope $record->{tags}->{'economy:scope'};
	$entry{'headquarters'} = $record->{tags}->{'headquarters'} || '';
	$entry{'ogf:logo'} = $record->{tags}->{'ogf:logo'} || 'Question mark in square brackets.svg';
	$entry{'ogf:permission'} = parsePermission $record->{tags}->{'ogf:permission'};
	$entry{'brand'} = $record->{tags}->{'brand'} || $entry{'name'};
	
	# use is_in tags to enable later filtering of the list into smaller subsets (on wiki)
	$entry{'is_in:continent'} = $record->{tags}->{'is_in:continent'} || '';
	$entry{'is_in:country'} = $record->{tags}->{'is_in:country'} || '';
	$entry{'is_in:state'} = $record->{tags}->{'is_in:state'} || '';
	$entry{'is_in:city'} = $record->{tags}->{'is_in:city'} || '';
	
	print "$entry{'id'},$entry{'lat'},$entry{'lon'},$entry{'name'}\n";
	push @out, \%entry;
}

# create output file
my $publishFile = $PUBLISH_DIR . '/' . $OUTFILE_NAME . '.json';
my $json = JSON::XS->new->canonical->indent(2)->space_after;
my $text = $json->encode( \@out );
OGF::Util::File::writeToFile($publishFile, $text, '>:encoding(UTF-8)' );

#-------------------------------------------------------------------------------
sub parseLatLon($$)
{
	my($var1, $var2) = @_;
	return $var1 || $var2 || 0.0;
}

#-------------------------------------------------------------------------------
sub parseSector($)
{
	my($var1) = @_;
	return $var1 if( $var1 eq 'primary' or $var1 eq 'secondary' or
	                 $var1 eq 'tertiary' or $var1 eq 'quaternary' );
	return '';
}

#-------------------------------------------------------------------------------
sub parseScope($)
{
	my($var1) = @_;
	return $var1 if( $var1 and ($var1 eq 'national' or $var1 eq 'international' or
	                            $var1 eq 'multinational' or $var1 eq 'global') );
	return 'national';
}

#-------------------------------------------------------------------------------
sub parsePermission($)
{
	my($var1) = @_;
	return $var1 if( $var1 and ($var1 eq 'yes' or $var1 eq 'no' or $var1 eq 'ask') );
	return 'yes';
}

#-------------------------------------------------------------------------------
sub fileExport_Overpass($)
{
	my($outFile) = @_;

	my $data = decode('utf-8', OGF::Util::Overpass::runQuery_remoteRetryOptions(undef, $QUERY, 32, 'json', 3, 3));
	OGF::Util::File::writeToFile( $outFile, $data, '>:encoding(UTF-8)' ) if( defined $data );
}

#-------------------------------------------------------------------------------
sub housekeeping($$)
{
	my($dir, $now) = @_;
	my $KEEP_FOR = 60 * 60 * 6 ; # 6 hours
	my $dh;
	
	opendir $dh, $dir;
	while( my $file = readdir $dh )
	{
		next unless( $file =~ /^economy_\d{14}\.json/ );
		if( $now - (stat "$dir/$file")[9] > $KEEP_FOR )
		{
			print "deleting: $dir/$file\n";
			unlink "$dir/$file";
		}
	}
	closedir $dh;
}