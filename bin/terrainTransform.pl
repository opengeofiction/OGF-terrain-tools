#! /usr/bin/perl -w

use strict;
use warnings;
use POSIX qw( floor ceil );
use OGF::Terrain::Transform;
use OGF::Util::Usage qw( usageInit usageError );

my %opt;
usageInit( \%opt, qq/ noExist strictBbox /, << "*" );
<level=...> <bbox=...> <src=...> <tgt=...>
*

#my( $BBOX ) = @ARGV;
#usageError() unless $BBOX;

# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=25.97,29.47,56.61,49.49 src=elev:SathriaLCC:2:all tgt=elev:SathriaLCC:5:all -noExist    # Sathria
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=25.97,43.14,31.346,47.10 src=elev:Roantra:4:all tgt=elev:SathriaLCC:5:all -strictBbox   # Roantra
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=30.9,43.1,31.4,43.772 src=elev:SathriaLCC:2:all tgt=elev:SathriaLCC:5:all -strictBbox   # Sathria repair
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=42.62146,48.01932,44.47266,49.42884 src=elev:SathriaLCC:2:all tgt=elev:SathriaLCC:5:all -strictBbox   # Sathria repair
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=31.15,45.48,31.346,47.10 src=elev:Roantra:4:all tgt=elev:SathriaLCC:5:all -strictBbox   # Roantra repair


my( $tileSize, @bbox, $dscSrc, $dscTgt );

foreach my $arg ( @ARGV ){
	if( $arg =~ s/^bbox=//i ){
		die qq/Ivalid bbox descriptor: $arg\n/ unless $arg =~ /^(-?[.\d]+),(-?[.\d]+),(-?[.\d]+),(-?[.\d]+)/;
		@bbox = ( $1, $2, $3, $4 );
	}elsif( $arg =~ s/^size=//i ){
		die qq/Ivalid size descriptor: $arg\n/ unless $arg =~ /^\d+$/;
		$tileSize = $arg;
	}elsif( $arg =~ s/^src=//i ){
        $dscSrc = $arg;
	}elsif( $arg =~ s/^tgt=//i ){
        $dscTgt = $arg;
	}else{
		die qq/Unknown argument: $arg\n/;
	}
}
usageError() unless @bbox && $dscSrc && $dscTgt;
print STDERR "\nNW = [", $bbox[0], ",", $bbox[1], "]\nSE = [", $bbox[2], ",", $bbox[3], "]\n\n";  # _DEBUG_


my $hInfo = OGF::Terrain::Transform::layerTransform( $dscSrc, $dscTgt, \@bbox, \%opt );

my( $tileWd, $tileHg ) = @{$hInfo->{_tileSize}};
my( $tx0, $tx1, $ty0, $ty1 ) = map {$hInfo->{_tileRange}{$_}} qw( _xMin _xMax _yMin _yMax );

$dscTgt =~ s/:all$//;
my $cmdMapLevel = qq|convertMapLevel.pl  -sz $tileWd,$tileHg -zip  $dscTgt:$ty0-$ty1:$tx0-$tx1 0|;
print STDERR "----- next cmd -----\n$cmdMapLevel\n";



