use LWP;
use URI::Escape;
use JSON::PP;
use LWP::Simple;
use Encode;
use feature 'unicode_strings' ;
use utf8;

$OVERPASS = 'https://osm3s.opengeofiction.net/api/interpreter?data=';
$URL_TERRITORIES = 'https://wiki.opengeofiction.net/wiki/index.php/OGF:Territory_administration?action=raw';
$CHANGESETS = 'https://opengeofiction.net/api/0.6/changesets?display_name=';
$APIUSER = 'https://opengeofiction.net/api/0.6/user/';

binmode(STDOUT, ":utf8");

# check command line
if( @ARGV != 1 )
{
	print <<USAGE;
Checks OGF territory ownership against user activity

USAGE:
 $0 XX > output.csv
 Where XX is the appropriate continent code used in the ogf:id properties, e.g. AR for Archanta
USAGE
	exit 1;
}
$CONTINENT = $ARGV[0];
$QUERY = qq(rel["type"="boundary"]["admin_level"]["ogf:id"~"^$CONTINENT"];out;);
$URL = $OVERPASS . uri_escape($QUERY);

# load map relations
$userAgent = LWP::UserAgent->new(keep_alive => 20);
$resp = $userAgent->get($URL);
print STDERR "URL: $URL\n";
foreach ( split "\n", decode('utf-8', $resp->content) )
{
	$rel = $1 if( /<relation id=\"(\d+)\"/ );
	$map{$rel}{id}     = $1 if( /k=\"ogf:id\" v=\"(.+)\"/ );
	$map{$rel}{owner}  = $1 if( /k=\"ogf:owner\" v=\"(.+)\"/ );
	$map{$rel}{is_in}  = $1 if( /k=\"is_in:continent\" v=\"(.+)\"/ );
	$map{$rel}{status}  = 'dogshit';
	$map_territory{$rel} = $rel;
}

# load JSON territories
$resp = $userAgent->get($URL_TERRITORIES);
$resp = decode('utf-8', $resp->content());
$json = JSON::PP->new();
$aTerr = $json->decode($resp);

# print JSON territories, matched against map ones
print "relation,ogf:id,owner,status,const,ogf:id map,is in,comment,edits,last edit,deadline,comment\n";
foreach $hTerr ( @$aTerr )
{
	next unless( $hTerr->{ogfId} =~ /$CONTINENT/ );
	$rel = $hTerr->{rel};
	if( exists $map{$rel} )
	{
		# get last edit by the user
		$last = '';
		$edits = '';
		if( 1 )
		{
			if( $hTerr->{owner} ne 'admin' and $hTerr->{owner} ne '' )
			{
				$user = '';
				$url = $CHANGESETS . $hTerr->{owner};
				$content = get($url);
				foreach $line ( split "\n", $content )
				{
					# uid="468" 
					$user = $1 if( $line =~ /uid\=\"(\d+)\"/ );
					# 2019-01-22T10:32:36Z
					$last = $1 if( $line =~ /created_at\=\"([0-9\-T\:Z]+)\"/ );
					last if( $last ne '' and $user ne '' );
				}
				
				if( $user ne '' )
				{
					$url = $APIUSER . $user;
					$content = get($url);
					foreach $line ( split "\n", $content )
					{
						# <changesets count="2073"/>
						$edits = $1 if( $line =~ /changesets\s+count\=\"(\d+)\"/ );
						last if( $edits ne '' );
					}
				}
			}
		}
		my $constraint_summary = '';
		my $constraints = $hTerr->{constraints};
		foreach my $constraint ( @$constraints )
		{
			$constraint_summary .= substr $constraint, 0, 1;
		}
		print "$rel,$hTerr->{ogfId},$hTerr->{owner},$hTerr->{status},$constraint_summary,$map{$rel}{id},$map{$rel}{is_in},in JSON & OGF map,$edits,$last,$hTerr->{deadline},\"$hTerr->{comment}\"\n";
		$map_territory{$rel} = undef;
	}
	else
	{
		print "$rel,$hTerr->{ogfId},$hTerr->{owner},$hTerr->{status},,,,in JSON\n";
	}
	$relations .= "$rel,";
}

# print out territories which were in the map data, but not JSON
foreach $rel ( sort values %map_territory )
{
	next unless defined( $rel );
	print "$rel,,,,,$map{$rel}{id},$map{$rel}{is_in},in OGF map\n";
	$relations .= "$rel,";
}

# sometime useful to print out ID of all the relations - e.g. to load into JOSM
if( 0 )
{
	print "\n$relations\n";
}
