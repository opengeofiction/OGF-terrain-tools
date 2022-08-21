#! /usr/bin/perl -w
# Checks OGF territory ownership against user activity

use LWP;
use URI::Escape;
use JSON::PP;
use LWP::Simple;
use Encode;
use feature 'unicode_strings' ;
use utf8;
use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use OGF::Util::File;
use OGF::Util::Usage qw( usageInit usageError );

$OVERPASS = 'https://overpass.ogf.rent-a-planet.com/api/interpreter?data=';
$URL_TERRITORIES = 'https://wiki.opengeofiction.net/wiki/index.php/OGF:Territory_administration?action=raw';
$BASE = 'https://opengeofiction.net';
$CHANGESETS = "$BASE/api/0.6/changesets?display_name=";
$APIUSER = "$BASE/api/0.6/user/";

binmode(STDOUT, ":utf8");

# check command line

my %opt;
usageInit( \%opt, qq/ h cont=s json=s /, << "*" );
[-cont <id> -json <file.json>]

-cont  continent code used in the ogf:id properties, e.g. AR for Archanta
-json  output to JSON file
*
usageError() if $opt{'h'};
usageError() if !$opt{'cont'};
$CONTINENT = $opt{'cont'};
$JSON_FILE = $opt{'json'};

$QUERY = qq(rel["type"="boundary"]["admin_level"]["ogf:id"~"^$CONTINENT"];out;);
$URL = $OVERPASS . uri_escape($QUERY);

# load map relations
$userAgent = LWP::UserAgent->new(keep_alive => 20);
$resp = $userAgent->get($URL);
print STDERR "URL: $URL\n";
foreach ( split "\n", decode('utf-8', $resp->content) )
{
	if( /<relation id=\"(\d+)\"/ )
	{
		$rel = $1;
		$map_territory{$rel}    = $rel;
		$map{$rel}{id}          = '';
		$map{$rel}{is_in}       = '';
		$map{$rel}{admin_level} = '';
	}
	$map{$rel}{id}           = $1 if( defined $rel and /k=\"ogf:id\" v=\"(.+)\"/ );
	$map{$rel}{is_in}        = $1 if( defined $rel and /k=\"is_in:continent\" v=\"(.+)\"/ );
	$map{$rel}{admin_level}  = $1 if( defined $rel and /k=\"admin_level\" v=\"(.+)\"/ );
}

# load JSON territories
$resp = $userAgent->get($URL_TERRITORIES);
$resp = decode('utf-8', $resp->content());
$json = JSON::PP->new();
$aTerr = $json->decode($resp);

# print JSON territories, matched against map ones
print "relation,ogf:id,owner,status,const,ogf:id map,is in,validity,edits,last edit,deadline,comment\n";
foreach $hTerr ( @$aTerr )
{
	next unless( $hTerr->{ogfId} =~ /$CONTINENT/ );
	my $rel = $hTerr->{rel};
	my $last = '';
	my $edits = '';
	if( exists $map{$rel} )
	{
		# get last edit by the user
		if( 1 )
		{
			if( $hTerr->{owner} ne 'admin' and $hTerr->{owner} ne '' )
			{
				# get the numeric user id
				my $user = '';
				my $url = $CHANGESETS . $hTerr->{owner};
				my $content = get($url);
				if( defined $content )
				{
					foreach $line ( split "\n", $content )
					{
						# uid="468" 
						$user = $1 if( $line =~ /uid\=\"(\d+)\"/ );
						# 2019-01-22T10:32:36Z
						$last = $1 if( $line =~ /created_at\=\"([0-9\-T\:Z]+)\"/ );
						last if( $last ne '' and $user ne '' );
					}
				
					# get user edits
					if( $user ne '' )
					{
						my $url = $APIUSER . $user;
						my $content = get($url);
						foreach $line ( split "\n", $content )
						{
							# <changesets count="2073"/>
							$edits = $1 if( $line =~ /changesets\s+count\=\"(\d+)\"/ );
							last if( $edits ne '' );
						}
					}
				}
				else
				{
					$last = 'ERROR username';
				}
			}
		}
		my $constraint_summary = '';
		my $constraints = $hTerr->{constraints};
		foreach my $constraint ( @$constraints )
		{
			$constraint_summary .= substr $constraint, 0, 1;
		}
		print STDERR "$hTerr->{ogfId} --> $rel\n";
		print "$rel,$hTerr->{ogfId},$hTerr->{owner},$hTerr->{status},$constraint_summary,$map{$rel}{id},$map{$rel}{is_in},in JSON & OGF map,$edits,$last,$hTerr->{deadline},\"$hTerr->{comment}\"\n";
		
		my $details = {
			relation     => $rel,
			ogf_id       => $hTerr->{ogfId},
			ogf_id_issue => ($hTerr->{ogfId} eq $map{$rel}{id}) ? 'F' : 'T',
			owner        => $hTerr->{owner},
			profile      => "$BASE/user/" . uri_escape_utf8($hTerr->{owner}),
			status       => $hTerr->{status},
			constraints  => $hTerr->{constraints},
			is_in        => $map{$rel}{is_in},
			validity     => 'in JSON & OGF map',
			valid_flag   => 'valid',
			edits        => $edits,
			last_edit    => $last,
			deadline     => $hTerr->{deadline},
			comment      => $hTerr->{comment}
		};
		push @territory_details, $details;
		
		delete $map_territory{$rel};
	}
	else
	{
		print "$rel,$hTerr->{ogfId},$hTerr->{owner},$hTerr->{status},,,,in JSON\n";
		
		my $details = {
			relation     => $rel,
			ogf_id       => $hTerr->{ogfId},
			ogf_id_issue => 'F',
			owner        => $hTerr->{owner},
			profile      => "$BASE/user/" . uri_escape_utf8($hTerr->{owner}),
			status       => $hTerr->{status},
			constraints  => $hTerr->{constraints},
			validity     => 'in JSON only',
			valid_flag   => 'invalid',
			deadline     => $hTerr->{deadline},
			comment      => $hTerr->{comment}
		};
		push @territory_details, $details;
	}
	$relations .= "$rel,";
}

# print out territories which were in the map data, but not JSON
foreach $rel ( sort values %map_territory )
{
	next unless defined( $rel );
	my $validity = 'in OGF map only';
	$validity = 'continental relation' if ( $map{$rel}{admin_level} eq '0' );
	my $valid_flag = 'invalid';
	$valid_flag = 'valid' if ( $map{$rel}{admin_level} eq '0' );
	print "$rel,,,,,$map{$rel}{id},$map{$rel}{is_in},$validity\n";
	
	my $details = {
		relation     => $rel,
		ogf_id       => $map{$rel}{id},
		ogf_id_issue => 'F',
		owner        => 'admin',
		profile      => "$BASE/user/admin",
		is_in        => $map{$rel}{is_in},
		validity     => $validity,
		valid_flag   => $valid_flag
	};
	push @territory_details, $details;
	
	$relations .= "$rel,";
}

# output JSON file
if( $JSON_FILE )
{
	my $json = JSON::PP->new->indent(2)->space_after;
	my $text = $json->encode( \@territory_details );
	OGF::Util::File::writeToFile( $JSON_FILE, $text, '>:encoding(UTF-8)' );
}

# sometimes useful to print out ID of all the relations - e.g. to load into JOSM
if( 0 )
{
	print "\n$relations\n";
}
