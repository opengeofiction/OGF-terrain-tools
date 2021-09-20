#! /usr/bin/perl -w -CSDA

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use URI::Escape;
use JSON::PP;
use LWP::Simple;
use OGF::Util::File;
use OGF::Util::Usage qw( usageInit usageError );

my $BASE  = 'https://opengeofiction.net';
my $API   = "$BASE/api/0.6";

my %opt;
usageInit( \%opt, qq/ h output=s cache=s start=i end=i full /, << "*" );
[-output <file.json> -cache <userid.cache> -start <userid> -end <userid> -full]

-output  output to JSON file
-cache   read latest user ID from last run, run for latest - 100 .. latest + 50
-start   start list at this user id (default 24700)
-end     end list at this user id   (default 24800)
-full    include users with 0 changesets
*
usageError() if $opt{'h'};
my $OUTPUT   = $opt{'output'} || 'users.json';
my $START_ID;
my $END_ID;
if( $opt{'cache'} and -r $opt{'cache'} )
{
	my $cachepoint = `cat $opt{'cache'}`;
	$START_ID = $cachepoint - 100;
	$END_ID   = $cachepoint +  50;
	print "Cached user: $cachepoint\n";
}
$START_ID = $opt{'start'} || 24700 if( !defined $START_ID );
$END_ID   = $opt{'end'}   || 24800 if( !defined $END_ID );
my $FULL     = $opt{'full'} ? 1 : 0;
print "Users: $START_ID .. $END_ID\n";

my $last_id = undef;
my @matching_users;
for( my $userid = $START_ID; $userid <= $END_ID; $userid++ )
{
	# the OGF server API doesn't support the "users" request, so one at a time...
	my $url = "$API/user/$userid";
	
	my $content = get($url);
	if( defined $content )
	{
		my $id             = '';
		my $name           = '';
		my $profile        = '';
		my $created        = '';
		my $latest         = '';
		my $admin          = 'N';
		my $mod            = 'N';
		my $changesets     = 0;
		my $blocks         = 0;
		my $blocks_active  = 0;
		my $blocked        = 0;
		my $blocked_active = 0;
		foreach my $line ( split "\n", $content )
		{
			# poor man's XML parsing, too many Perl years 
			if( $line =~ /<user id=\"(\d+)\" display_name=\"(.+)\" account_created=\"([\d\-TZ\:]+)\">/ )
			{
				$id      = $1;
				$name    = $2;
				$profile = "$BASE/user/" . uri_escape $name;
				$created = $3;
			}
			$admin      = 'Y' if( $line =~ /<administrator\/>/ );
			$mod        = 'Y' if( $line =~ /<moderator\/>/ );
			$changesets = $1  if( $line =~ /<changesets count=\"(\d+)\"\/>/ );
			if( $line =~ /<received count=\"(\d+)\" active="(\d+)\"\/>/ )
			{
				$blocks = $1;
				$blocks_active = $2;
			}
			if( $line =~ /<issued count=\"(\d+)\" active="(\d+)\"\/>/ )
			{
				$blocked = $1;
				$blocked_active = $2;
			}
		}
		if( defined $id )
		{
			$last_id = $id;
			
			# get last edit by the user
			my $url = "$API/changesets?user=$id";
			my $content = get($url);
			if( defined $content )
			{
				foreach my $line ( split "\n", $content )
				{
					if( $line =~ /closed_at=\"([\d\-TZ\:]+)\"/ )
					{
						$latest = $1;
						last;
					}
				}
			}
			next if( $FULL == 0 and $changesets == 0 );
			my $block = '';
			$block = 'b' if( $blocks > 0 );
			$block = 'B' if( $blocks_active > 0 );
			my $userdetails = {
				id           => $id,
				name         => $name,
				profile      => $profile,
				created      => $created,
				latest       => $latest,
				admin        => $admin,
				mod          => $mod,
				changesets   => $changesets,
				block_status => $block
			};
			push @matching_users, $userdetails;
			
			printf "$id: %-55s %20s %3d %s\n", $profile, $latest, $changesets, $block;
		}
	}
}
print STDERR "$last_id\n" if( defined $last_id );

# output JSON
my $json = JSON::PP->new->indent(2)->space_after;
my @reverse = reverse @matching_users;
my $text = $json->encode( \@reverse );
OGF::Util::File::writeToFile( $OUTPUT, $text, '>:encoding(UTF-8)' );

if( $opt{'cache'} and defined $last_id )
{
	OGF::Util::File::writeToFile( $opt{'cache'}, $last_id, '>:encoding(UTF-8)' );
}
