#! /usr/bin/perl -w
# 

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';

while( <STDIN> )
{
	#0            1                     2           3       4         5                      6                7              8                  
	#Changeset ID|Changeset create date|Num changes|User ID|User name|User create IP address|User create date|User languages|User email address|
	#9                    10                    11
	#User changeset count|Changesest IP address|Changeset client
	my @fields = split /\|/;
	if( @fields == 12 )
	{
		my $username = $fields[4];
		my $ip       = $fields[10];
		my $key      = "$username,$ip";
		if( !exists $editsperip{$key} )
		{
			$editsperip{$key} = 0;
			$usersperip{$ip} = 0 if( !exists $usersperip{$ip} );
			$usersperip{$ip}++;
			$editsperuser{$username} = 0 if( !exists $editsperuser{$username} );
			$editsperuser{$username}++;
		}
		$editsperip{$key}++;
	}
	else
	{
		print STDERR;
	}
}

binmode(STDOUT, ":utf8");

print "username,ip,count,users on ip,total edits\n";
foreach my $key ( sort keys %editsperip )
{
	my($username,$ip) = split /,/, $key;
	print "$username,$ip,$editsperip{$key},$usersperip{$ip},$editsperuser{$username}\n";
}
