package OGF::Terrain::PhysicalMap;
use strict;
use warnings;
use POSIX;
use OGF::Const;
use OGF::LayerInfo;
use OGF::Terrain::ElevationTile qw( $NO_ELEV_VALUE $T_WIDTH $T_HEIGHT $BPP );
use OGF::Util::Shape;
use OGF::Util::File qw( readFromFile );
use Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( makeElevColorFile makeColorMap getElevColor getLandOrSeaColor setInlandWaterBorders );

#our $COLOR_MAP_FILE = 'C:/usr/MapView/archiv/colors01.txt';
#our $COLOR_MAP_FILE = 'C:/usr/MapView/archiv/colors02_maperitive.txt';
#our $COLOR_MAP_FILE = 'C:/usr/MapView/archiv/colors05.txt';
our $COLOR_MAP_FILE = $OGF::TERRAIN_COLOR_MAP;
our $TEMP_PPM_FILE  = 'C:/usr/tmp/tmp01.ppm';
our( $ELEV_SHIFT, $SHAPE_CACHE, $CONTOUR_FILE, $CONTOUR_TILE ) = ( 20000, {}, '' );
our %COLORS = (
#	'InlandWater' => [ 160, 240, 255 ],
	'InlandWater' => [ 153, 204, 255 ],
);


sub makeElevColorFile {
	my( $aElev, $aColorMap, $fileOut, $hOpt ) = @_;
	my $aWater = $hOpt->{_water}  || undef;
	my $wwInfo = $hOpt->{_wwInfo} || undef;

	my( $wd, $hg ) = $hOpt->{_size} ? @{$hOpt->{_size}} : ($T_WIDTH,$T_HEIGHT);
	my $ppm = OGF::Util::PPM->new({ 'width' => $wd, 'height' => $hg });

	$OGF::Terrain::PhysicalMap::SHAPE_CACHE = {};
	for( my $y = 0; $y < $hg; ++$y ){
		for( my $x = 0; $x < $wd; ++$x ){
#			print STDERR "\$y <", $y, ">  \$x <", $x, ">\n";  # _DEBUG_
			my $aColor;
			if( $aWater && $aWater->[$y][$x] != $NO_ELEV_VALUE ){
				$aColor = $OGF::Terrain::Util::PhysicalMap::COLORS{'InlandWater'};
			}else{
				my $elev = $aElev->[$y][$x];
#				print STDERR "  \$elev <", $elev, ">\n";  # _DEBUG_
#				$elev = (($elev & 255) << 8) | (($elev & 65280) >> 8) if $hOpt->{_bigEndian};  # doesn't work correctly
				if( $wwInfo && $elev == 0 ){
					$aColor = getLandOrSeaColor( $x, $y, $aColorMap, $wwInfo );
				}else{
					$aColor = getElevColor( $elev, $aColorMap );
				}
#				print STDERR "  \$aColor <", ($aColor ? join('|',@$aColor) : 'undef'), ">\n";  # _DEBUG_
			}
			$ppm->setPixel( $x, $y, $aColor );
		}
	}
#	setInlandWaterBorders( $ppm, $aWater, $aColorMap, $wwInfo );

	$ppm->writeToFile( $TEMP_PPM_FILE );
	my $cmd = qq/pnmtopng "$TEMP_PPM_FILE" > "$fileOut"/;
	print STDERR $cmd, "\n";
	system $cmd;
}

sub makeColorMap {
	my( $colorMapFile ) = @_;
	$colorMapFile = $COLOR_MAP_FILE if ! $colorMapFile;
	my( $hElevColor, $color, @colorMap ) = ( {} );
	local *FILE;
	open( FILE, $colorMapFile ) or die qq/Cannot open "$colorMapFile": $!\n/;
	while( <FILE> ){
	
		next if /^(#|\s*$)/;
		if( /^\s*(-?[.\d]+|nv|[NFB])\s+(\d+)\s+(\d+)\s+(\d+)/ ){
			( my $elev, $color ) = ( $1, [$2, $3, $4] ); 
#			$elev = 0 if $elev eq 'nv';
			$elev = .0000001 if $elev eq '0';
			$elev = 0 if $elev !~ /[.\d]/;
			$hElevColor->{$elev + $ELEV_SHIFT} = $color;
		}else{
			die qq/Invalid line [$.]: $_/;
		}
	}
	my @elevList = sort {$a <=> $b} keys %$hElevColor;
	$hElevColor->{0}             = $hElevColor->{$elevList[0]};
	$hElevColor->{2*$ELEV_SHIFT} = $hElevColor->{$elevList[-1]};
	@elevList = ( 0, @elevList, 2*$ELEV_SHIFT );
	for( my $j = 0; $j < $#elevList; ++$j ){
		my( $i0, $i1 ) = ( $elevList[$j], $elevList[$j+1] );
		my( $r0, $g0, $b0, $r1, $g1, $b1 ) = ( @{$hElevColor->{$i0}}, @{$hElevColor->{$i1}} );
		my $dist = $i1 - $i0;
		for( my $i = POSIX::ceil($i0); $i < $i1; ++$i ){ 
			my( $c0, $c1 ) = ( $i1 - $i, $i - $i0 );
			my( $r, $g, $b ) = ( 
				POSIX::floor( ($c0*$r0 + $c1*$r1)/$dist + .5 ),
				POSIX::floor( ($c0*$g0 + $c1*$g1)/$dist + .5 ),
				POSIX::floor( ($c0*$b0 + $c1*$b1)/$dist + .5 ),
			);
			$colorMap[$i] = [ $r, $g, $b ];
		}
	}
	$colorMap[2*$ELEV_SHIFT] = $hElevColor->{2*$ELEV_SHIFT};
	close FILE;
	return \@colorMap, [ map {$_ - $ELEV_SHIFT} @elevList ];
}

sub getElevColor {
	my( $elev, $aColorMap ) = @_;
#	print STDERR "\$elev <", $elev, ">  \$aColorMap <", $aColorMap, ">\n";  # _DEBUG_
	$elev = 0 if !defined $elev;
	my $color = $aColorMap->[int($elev)+$ELEV_SHIFT];
#	die qq/ERROR !!!/ if ! defined $color;
	return $color;
}

sub getLandOrSeaColor {
	my( $x, $y, $aColorMap, $wwInfo ) = @_;
	my $elev;
	my $ptag = OGF::Util::Shape::ptag([$x,$y]);
	if( !exists $SHAPE_CACHE->{$ptag} ){
#		my $aTile = getContourArray( $fileIn );
		my $aTile = $wwInfo->copy( 'type' => 'contour' )->tileArray();
		my $elev_X = $aTile->[$y][$x];
		return $aColorMap->[$elev_X+$ELEV_SHIFT] if $elev_X != $NO_ELEV_VALUE;

		my $cSub = sub{
			my($x,$y) = @_;
			my $val = $aTile->[$y][$x];
			return ($val < 0);
		};
		my $shape = OGF::Util::Shape::connectedShape( $aTile, [$x,$y], 'E4', $cSub );
		my $border = $shape->getBorder( 'outer', 'E4' );
		my( $min, $max ) = $border->minMaxInfo( $aTile );
		my $shapeElev = (!defined($max) || $max <= 0)? 0 : 1;
		foreach my $key ( keys %{$shape->{_shape}} ){
			$SHAPE_CACHE->{$key} = $shapeElev;
		}
	}
	$elev = $SHAPE_CACHE->{$ptag};
	die qq/getLandOrSeaColor: cannot determine land status at [$x,$y]/ if !defined $elev;
	return $aColorMap->[$elev+$ELEV_SHIFT];
}

my( $LSC_FILE, $LSC_ARRAY ) = ( '' );

sub getLandOrSeaColor_01 {
	my( $x, $y, $aColorMap, $wwInfo ) = @_;
	my $file = $wwInfo->copy('type' => 'phys')->tileName();
	$file =~ s/WW_phys/WW_phys_01/;

	if( $file ne $LSC_FILE ){
		require OGF::Util::TileLevel;
		my( $tmpFile ) = OGF::Util::TileLevel::getTempFileNames( 1 );
		OGF::Util::TileLevel::convertToPnm( $file, $tmpFile, $T_WIDTH, $T_HEIGHT );
		$LSC_ARRAY = OGF::Util::PPM->new( $tmpFile, {-loadData => 1} )->{'data'};
		$LSC_FILE = $file;
	}
	my( $r, $g, $b ) = @{$LSC_ARRAY->[$y][$x]};
	my $elev = ($r == 220 && $g == 255 && $b == 255)? 0 : 1;

	return $aColorMap->[$elev+$ELEV_SHIFT];
}


sub setInlandWaterBorders {
	my( $ppm, $aWater, $aColorMap, $wwInfo ) = @_;
	my $shape = OGF::Util::Shape::generalShape( $aWater, sub{
		my( $x, $y ) = @_;
		return $aWater->[$y][$x] == 0;
	} );
	my $aContour = $wwInfo->copy('type' => 'contour')->tileArray();
	my $hShapeCache = {};
	my $border = $shape->getBorder( 'outer', 'E4' );
	my( $wd, $hg ) = OGF::Util::Shape::getTileSize( $aWater );
	foreach my $pt ( $border->points() ){
		my( $x, $y ) = @$pt;
		if( $aContour->[$y][$x] == 0 ){
			my $ptag = OGF::Util::Shape::ptag([$x,$y]);
			if( ! $hShapeCache->{$ptag} ){
				my $shapeElev = OGF::Util::Shape::connectedShape( $aContour, [$x,$y], 'E8', sub{
					my( $x2, $y2 ) = @_;
					return ($aContour->[$y2][$x2] == 0);
				} );
				foreach my $pt2 ( $shapeElev->points() ){
					$ppm->setPixel( @$pt2, getElevColor(1,$aColorMap) );
					$hShapeCache->{OGF::Util::Shape::ptag($pt2)} = 1;
				}
			}
		}else{
			my $aEnvP = OGF::Util::Shape::getTypeEnvPoints( 'E8' );
			my $sw = 0;	
			for( my $i = 0; $i < 8; ++$i ){
				my $j = ($i + 1) % 8;
				my( $xd1, $yd1 ) = ( $x+$aEnvP->[$i][0], $y + $aEnvP->[$i][1] );
				my( $xd2, $yd2 ) = ( $x+$aEnvP->[$j][0], $y + $aEnvP->[$j][1] );
				if( OGF::Util::Shape::inArea([$wd,$hg],[$xd1,$yd1]) && OGF::Util::Shape::inArea([$wd,$hg],[$xd2,$yd2]) ){
					++$sw if $aWater->[$yd1][$xd1] != $aWater->[$yd2][$xd2];
				}
			}
			if( $sw > 2 || ($sw >=2 && !OGF::Util::Shape::inArea([$wd,$hg],[$x,$y]) ) ){
				$ppm->setPixel( $x, $y, $COLORS{'InlandWater'} );
			}
		}
	}
}

sub makePhotoFromElev {
	require Tk::Photo;
	my( $tkObj, $file, $wd, $hg, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my $optR = $hOpt->{'noRelief'} ? 0 : 1;
	my( $aColorMap ) = $hOpt->{'colorMap'} ? ($hOpt->{'colorMap'}) : makeColorMap( $COLOR_MAP_FILE );

#	my $aTile = OGF::Terrain::ElevationTile::makeArrayFromFile( $file, $wd, $hg, $BPP );
	my( $aTile, $data );
	if( ref($file) ){
		$aTile = $file;
	}else{
		$data = readFromFile( $file, {-bin => 1} );
		$aTile = OGF::Terrain::ElevationTile::makeArrayFromTile( $data, $wd, $hg, $BPP );
	}
	my $photo = $tkObj->Photo( -width => $wd, -height => $hg );

#	use Time::HiRes qw( time );
	my $cSub = sub {
		my( $cnv ) = @_;
		$cnv->{_OGF_blockRedraw} = 1;
        my $t0 = time;
        for( my $y = 0; $y < $hg; ++$y ){
	        my $colorStr = "{";
            for( my $x = 0; $x < $wd; ++$x ){
                my $elev = $aTile->[$y][$x];
                my $color = $aColorMap->[$elev+$ELEV_SHIFT];
#               print STDERR "\$elev <", $elev, ">  \@\$color <", ($color ? join('|',@$color) : ''), ">\n";  # _DEBUG_
                $color = reliefColor( $color, $x, $y, $aTile, $wd, $hg ) if $optR;
                $color = sprintf '#%02X%02X%02X', @$color;
#               $photo->put( $color, -to => $x,$y, $x+1,$y+1 );
                $colorStr .= $color . " ";
            }
            $colorStr .= "}";
            $photo->put( $colorStr, -to => 0,$y ); # , $wd,$y+1 );
            $cnv->update();
        }
        print STDERR "makePhotoFromElev: ", (time - $t0), " sec\n";
		$cnv->{_OGF_blockRedraw} = 0;
        $cnv->update();
	};
	return wantarray ? ($photo,$data,$cSub) : $photo;
}


# relief parameters
# VERT_EX = vertical exaggeration
# C_POS   = color multiplicator, positive diff
# C_POS   = color multiplicator, negative diff
# DX_M    = meters per pixel, x-axis
# DY_M    = meters per pixel, y-axis
my( $VERT_EX, $C_POS, $C_NEG, $MP_X, $MP_Y ) = ( 20, .4, .9, 500, 500 );
my $vL = [ -1, -1, .2 ];   # light from direction
my $dL = sqrt($vL->[0] * $vL->[0] + $vL->[1] * $vL->[1] + $vL->[2] * $vL->[2]);


sub reliefColor {
	my( $aColor, $x, $y, $aElev, $wd, $hg ) = @_;
	if( $x == 0 || $y == 0 || $x == $wd-1 || $y == $hg-1 ){
		return $aColor || [ 128, 128, 128 ];
	}

#	print STDERR "\$y <", $y, ">  \$x <", $x, ">\n";  # _DEBUG_
#	my $elev = $aElev->[$y+1][$x+1];
    my $gradX = ($aElev->[$y][$x+1] - $aElev->[$y][$x-1]) / 2;
    my $gradY = ($aElev->[$y+1][$x] - $aElev->[$y-1][$x]) / 2;

#	my( $vX, $vY ) = ( [1,0,$gradX], [0,1,$gradY] );
    my( $vX, $vY ) = ( [$MP_X,0,$VERT_EX*$gradX], [0,$MP_Y,$VERT_EX*$gradY] );
    my $vN = [ 
        $vX->[1] * $vY->[2] - $vX->[2] * $vY->[1],
        $vX->[2] * $vY->[0] - $vX->[0] * $vY->[2],
        $vX->[0] * $vY->[1] - $vX->[1] * $vY->[0],
    ];

    my $dd = $dL * sqrt($vN->[0] * $vN->[0] + $vN->[1] * $vN->[1] + $vN->[2] * $vN->[2]);
    my $prod = ($vN->[0] * $vL->[0] + $vN->[1] * $vL->[1] + $vN->[2] * $vL->[2]) / $dd;

    my $aColorNew;
    if( $aColor ){
        $aColorNew = [ @$aColor ];
        $aColorNew->[0] = ($prod > 0)? int($aColor->[0] + $C_POS * $prod * (255 - $aColor->[0])) : int($aColor->[0] + $C_NEG * $prod * $aColor->[0]); 
        $aColorNew->[1] = ($prod > 0)? int($aColor->[1] + $C_POS * $prod * (255 - $aColor->[1])) : int($aColor->[1] + $C_NEG * $prod * $aColor->[1]); 
        $aColorNew->[2] = ($prod > 0)? int($aColor->[2] + $C_POS * $prod * (255 - $aColor->[2])) : int($aColor->[2] + $C_NEG * $prod * $aColor->[2]); 
    }else{
        my $grey = int( 128 + 128 * $prod );
        $grey = 255 if $grey == 256;
        $aColorNew = [ $grey, $grey, $grey ];
    }
	return $aColorNew;
}




1;


