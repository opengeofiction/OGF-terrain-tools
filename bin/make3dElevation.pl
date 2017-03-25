#! /usr/bin/perl -w

use strict;
use warnings;
use POSIX qw( floor ceil );
use OGF::Terrain::Transform;
use OGF::Util::Usage qw( usageInit usageError );

my %opt;
usageInit( \%opt, qq/ /, << "*" );
<level=...> <bbox=...>
*

#my( $BBOX ) = @ARGV;
#usageError() unless $BBOX;

# make3dElevation level=12 bbox=-23.83,43.33,-18.65,46.95
# make3dElevation level=12 bbox=-20.87,44.42,-18.81,45.97
# make3dElevation level=12 bbox=29.13,44.42,31.19,45.97

# make3dElevation level=10 bbox=98.0283,-64.0938,98.7135,-63.9410    # Tarrases
# make3dElevation level=10 bbox=89.10,18.31,90.93,18.85              # Khaiwoon
# make3dElevation level=10 size=256 bbox=108.35,-62.39,108.96,-62.07           # January
# make3dElevation level=2 size=1024 bbox=25.97,43.14,31.34,47.10               # Sathria (roantra area)
# make3dElevation level=2 size=1024 bbox=25.97,29.47,56.61,49.49               # Sathria



my( $level, $tileSize, @bbox );
foreach my $arg ( @ARGV ){
	if( $arg =~ s/^bbox=//i ){
		die qq/Ivalid bbox descriptor: $arg\n/ unless $arg =~ /^(-?[.\d]+),(-?[.\d]+),(-?[.\d]+),(-?[.\d]+)/;
		@bbox = ( $1, $2, $3, $4 );
	}elsif( $arg =~ s/^level=//i ){
		die qq/Ivalid level descriptor: $arg\n/ unless $arg =~ /^\d+$/;
		$level = $arg;
	}elsif( $arg =~ s/^size=//i ){
		die qq/Ivalid size descriptor: $arg\n/ unless $arg =~ /^\d+$/;
		$tileSize = $arg;
	}else{
		die qq/Unknown argument: $arg\n/;
	}
}
usageError() unless defined($level) && @bbox;
print STDERR "level = ", $level, "\nNW = [", $bbox[0], ",", $bbox[1], "]\nSE = [", $bbox[2], ",", $bbox[3], "]\n\n";  # _DEBUG_


#my( $tileWidth, $tileHeight ) = (defined $tileSize)? ( $tileSize, $tileSize ) : ( 256, 256 );
#my( $tileWidth, $tileHeight ) = ( 1024, 1024 );
my( $dscSrc, $dscTgt ) = ( "elev:OGF:13:all", "elev:WebWW:$level:all" );

my $hInfo = OGF::Terrain::Transform::layerTransform( $dscSrc, $dscTgt, \@bbox );

my( $tileWd, $tileHg ) = @{$hInfo->{_tileSize}};
my( $tx0, $tx1, $ty0, $ty1 ) = map {$hInfo->{_tileRange}{$_}} qw( _xMin _xMax _yMin _yMax );

$dscTgt =~ s/:all$//;
my $cmdMapLevel = qq|convertMapLevel.pl  -sz $tileWd,$tileHg -zip  $dscTgt:$ty0-$ty1:$tx0-$tx1 0|;
print STDERR "----- next cmd -----\n$cmdMapLevel\n";



