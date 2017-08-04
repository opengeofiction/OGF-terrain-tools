package OGF::Terrain::ElevationTile;
use strict;
use warnings;
use POSIX;
use UTAN::Util qw( readFromFile writeToFile );
use OGF::TileUtil;
use Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( $NO_ELEV_VALUE $T_WIDTH $T_HEIGHT $BPP $TILE_ORDER_Y
	convertElevationTile makeTileFromArray makeArrayFromTile makeArrayFromFile getEmptyTile makeTileArray printTile makeElevationFile );


our %SUPPORTED_BPP = ( 2 => 's', 4 => 'f' );


our( $NO_ELEV_VALUE, $T_WIDTH, $T_HEIGHT, $BPP ) = ( -30001, 512, 512, 2 );
our $TILE_ORDER_Y = -1;
our %EMPTY_TILE;
our $EDITOR;


$SIG{__WARN__} = sub {
	print STDERR @_ unless $_[0] =~ /^(Deep recursion on subroutine|Subroutine ClassInit redefined)/;
};


sub setGlobalTileInfo {
	( $T_WIDTH, $T_HEIGHT, $BPP, my $tileOrderY ) = @_;
	$TILE_ORDER_Y = $tileOrderY if $tileOrderY;
}


sub makeEmptyTile {
	my( $dx, $dy, $bytesPerPixel, $val ) = @_;
	$val = 0 if ! defined $val;
	die qq/Supported values for bytesPerPixel: 4\n/ if ! $SUPPORTED_BPP{$bytesPerPixel};
	my $packTemplate = $SUPPORTED_BPP{$bytesPerPixel} . '*';
	my $tileData = '';
	for( my $y = 0; $y < $dy; ++$y ){
		$tileData .= pack( $packTemplate, ($val) x $dx );
	}
	return $tileData;
}

sub getEmptyTile {
	my( $val ) = @_;
	$val = 0 if ! defined $val;
	if( ! defined($EMPTY_TILE{$val}) ){
		$EMPTY_TILE{$val} = makeEmptyTile( $T_WIDTH, $T_HEIGHT, $BPP, $val );
	}
	return $EMPTY_TILE{$val};
}

sub makeTileFromArray {
	my( $aRows, $bytesPerPixel, $packTemplate ) = @_;
	die qq/Supported values for bytesPerPixel: 4\n/ if ! $SUPPORTED_BPP{$bytesPerPixel};
	$packTemplate = $SUPPORTED_BPP{$bytesPerPixel} . '*' if ! $packTemplate;
	$packTemplate .= '*' unless $packTemplate =~ /\*$/;

	my $dy = scalar( @$aRows );
	print STDERR "\$dy <", $dy, ">\n";  # _DEBUG_
	my $tileData = '';
	for( my $y = 0; $y < $dy; ++$y ){
		my $dx = scalar @{$aRows->[$y]};
		for( my $x = 0; $x < $dx; ++$x ){
#			$aRows->[$y][$x] = $NO_ELEV_VALUE if $aRows->[$y][$x] !~ /^\d+$/;
			$aRows->[$y][$x] = $NO_ELEV_VALUE if !defined $aRows->[$y][$x];
		}
#		print STDERR "\$packTemplate <", $packTemplate, ">\n";  # _DEBUG_
#		print STDERR "\@{\$aRows->[\$y]} <", join('|',@{$aRows->[$y]}), ">\n";  # _DEBUG_
		$tileData .= pack( $packTemplate, @{$aRows->[$y]} );
	}
	return $tileData;
}

sub makeArrayFromTile {
	my( $dataStr, $dx, $dy, $bytesPerPixel, $packTemplate ) = @_;
	( $dx, $dy, $bytesPerPixel ) = ( $T_WIDTH, $T_HEIGHT, $BPP ) if ! defined $dx;
	die qq/Supported values for bytesPerPixel: 4\n/ if ! $SUPPORTED_BPP{$bytesPerPixel};
	$packTemplate = $SUPPORTED_BPP{$bytesPerPixel} . '*' if ! $packTemplate;
	$packTemplate .= '*' unless $packTemplate =~ /\*$/;

	my @rows;
	my $rowSize = $dx * $bytesPerPixel;
	for( my $y = 0; $y < $dy; ++$y ){
		my $rowStr = substr( $dataStr, $y * $rowSize, $rowSize );
		my @val = unpack( $packTemplate, $rowStr );
		push @rows, \@val;
	}
	return \@rows;
}

sub makeArrayFromFile {
	my( $fileName, $dx, $dy, $bytesPerPixel, $val, $packTemplate ) = @_;
	( $dx, $dy, $bytesPerPixel ) = ( $T_WIDTH, $T_HEIGHT, $BPP ) if ! defined $dx;
	die qq/Supported values for bytesPerPixel: 4\n/ if ! $SUPPORTED_BPP{$bytesPerPixel};
	$packTemplate = $SUPPORTED_BPP{$bytesPerPixel} . '*' if ! $packTemplate;

	my $aRows;
	if( -e $fileName ){
		my $dataStr = readFromFile( $fileName, {-bin => 1} );
		$aRows = makeArrayFromTile( $dataStr, $dx, $dy, $bytesPerPixel, $packTemplate );
	}elsif( defined $val ){
		$aRows = makeTileArray( $val, $dx, $dy );
	}else{
		die qq/makeArrayFromFile: no such file "$fileName"/;
	}
	return $aRows;
}



sub makeTileArray {
	my( $cSub, $dx, $dy, @param ) = @_;
	my $aRows = [];
	if( ref($cSub) ){
		for( my $y = 0; $y < $dy; ++$y ){
			$aRows->[$y] = [];
			for( my $x = 0; $x < $dx; ++$x ){
				$aRows->[$y][$x] = $cSub->( $x, $y, $dx, $dy, @param );
			}
		}
	}else{
		for( my $y = 0; $y < $dy; ++$y ){
			$aRows->[$y] = [];
			for( my $x = 0; $x < $dx; ++$x ){
				$aRows->[$y][$x] = $cSub;
			}
		}
	}
	return $aRows;
}

sub getYrow {
	my( $aM, $y ) = @_;
	return $aM->[$y];
}

sub getTsYrow {
	my( $aTS, $y ) = @_;
	return [ @{getYrow($aTS->[1][0],$y)}, @{getYrow($aTS->[1][1],$y)}, @{getYrow($aTS->[1][2],$y)} ];
}

sub setYrow {
	my( $aM, $y, $aRow, $offset, $len ) = @_;
	$offset = 0 if !defined $offset;
	$len = scalar(@$aRow) if !defined $len;
	for( my $x = 0; $x < $len; ++$x ){
		$aM->[$y][$x] = $aRow->[$x+$offset];
	}
}

sub getXcol {
	my( $aM, $x ) = @_;
	my @row = map {$aM->[$_][$x]} (0..$#{$aM});
	return \@row;
}

sub getTsXcol {
	my( $aTS, $x ) = @_;
	return [ @{getXcol($aTS->[0][1],$x)}, @{getXcol($aTS->[1][1],$x)}, @{getXcol($aTS->[2][1],$x)} ];
}

sub setXcol {
	my( $aM, $x, $aRow, $offset, $len ) = @_;
	$offset = 0 if !defined $offset;
	$len = scalar(@$aRow) if !defined $len;
	for( my $y = 0; $y < $len; ++$y ){
		$aM->[$y][$x] = $aRow->[$y+$offset];
	}
}



sub modifyNoAltValue {
	my( $file, $valOld, $valNew ) = @_;
	print STDERR "modifyNoAltValue( $file, $valOld, $valNew )\n";  # _DEBUG_
	my $dataIn = readFromFile($file,{-bin => 1});
	my $aRows = makeArrayFromTile( $dataIn );

	for( my $y = 0; $y < $T_HEIGHT; ++$y ){
		for( my $x = 0; $x < $T_WIDTH; ++$x ){
			$aRows->[$y][$x] = $valNew if $aRows->[$y][$x] == $valOld;
		}
	}

	my $dataOut = makeTileFromArray( $aRows, $BPP );
	writeToFile( $file, $dataOut, undef, {-bin => 1} );
}


sub printArray {
	my( $text, $aRows ) = @_;
	print "--- $text ---\n";
	my $dy = scalar(@$aRows);
	print "rows: $dy\n";
	for( my $y = 0; $y < $dy; ++$y ){
		my $dx = scalar( @{$aRows->[$y]} );
		print "  [$y] columns: $dx";
		my $ndf = 0;
		for( my $x = 0; $x < $dx; ++$x ){
			++$ndf if ! defined $aRows->[$y][$x];
		}
		print "  -- $ndf undefined" if $ndf > 0;
		print "\n";
	}
}

sub printTile {
	my( $text, $aRows, $y0, $x0, $dy, $dx ) = @_;
	( $y0, $x0 ) = ( 0, 0 ) if !defined $y0;
	my $num = scalar( @$aRows );
	( $dy, $dx ) = ( $num-$y0, $num-$x0 ) if !defined $dy;
	print STDERR "--- $text ---\n";
	for( my $y = $y0; $y < $y0+$dy; ++$y ){
		for( my $x = $x0; $x < $x0+$dx; ++$x ){
			print STDERR "[", ($y-$y0), ",", ($x-$x0), "] ", $aRows->[$y][$x], "\n";
		}
	}
}


#--- contour conversion -----------------------------------------------------------------------

sub loadTileSet {
	my( $wwInfo, $xA, $yA, $xB, $yB ) = @_;
	my $aTileSet = [];
	for( my $y = $yA; $y <= $yB; ++$y ){
		for( my $x = $xA; $x <= $xB; ++$x ){
			my $dataIn = $wwInfo->copy( 'y' => $wwInfo->{'y'}-$y, 'x' => $wwInfo->{'x'}+$x )->tileData();
			$aTileSet->[$y-$yA][$x-$xA] = $dataIn;
#			print STDERR "\$aTileSet->[", ($y-$yA), "][", ($x-$xA), "] <dataIn>\n";  # _DEBUG_
		}
	}
	return $aTileSet;
}

sub tileSetList {
	my( $t ) = @_;
	my @list = ($TILE_ORDER_Y > 0)
		? ( $t->[2][0], $t->[2][1], $t->[2][2], $t->[1][0], $t->[1][1], $t->[1][2], $t->[0][0], $t->[0][1], $t->[0][2] )
		: ( $t->[0][0], $t->[0][1], $t->[0][2], $t->[1][0], $t->[1][1], $t->[1][2], $t->[2][0], $t->[2][1], $t->[2][2] );
	return @list;
}


sub getSurroundTile {
	my( $wwInfo, $margin ) = @_;
	my $wwContour = $wwInfo->copy( 'type' => 'contour' );
	if( ! -f $wwContour->tileName() ){
		print "No contour file: ", $wwContour->tileName(), "\n";
		return undef;
	}

#	my $aRowsOut = makeElevationFromContour( $aTileSet, $T_WIDTH, $T_HEIGHT );
#	my $dataOut = makeTileFromArray( $aRowsOut, $BPP );

	my $aTileSet_Contour = loadTileSet( $wwContour, -1, -1, 1, 1 );

	my( $dx, $dy )   = ( $T_WIDTH, $T_HEIGHT );
	my( $dxL, $dyL ) = ( $dx + 2*$margin, $dy + 2*$margin );
	my $dataSrnd_Contour = OGF::TileUtil::surroundTile( $dx, $dy, $margin, tileSetList($aTileSet_Contour) );

	my $wwStream = $wwInfo->copy( 'type' => 'stream' );
	if( -f $wwStream->tileName() ){
		my $aTileSet_Stream = loadTileSet( $wwStream, -1, -1, 1, 1 );
		my $dataSrnd_Stream = OGF::TileUtil::surroundTile( $dx, $dy, $margin, tileSetList($aTileSet_Stream)  );
		$dataSrnd_Contour = mergeStreamDataIntoContourLayer( $dataSrnd_Contour, $dataSrnd_Stream, $dxL,$dyL );
	}

	return ( $dataSrnd_Contour, $dx, $dy, $dxL, $dyL );
}


sub makeElevationFile {
	my( $wwInfo ) = @_;
	print STDERR "\n", $wwInfo->toString(), "\n";

	my $margin = 128; #256;  #  128  511
	my( $dataSrnd_Contour, $dx, $dy, $dxL, $dyL ) = getSurroundTile( $wwInfo, $margin );
	return if ! $dataSrnd_Contour;

#	my $dataOut = convertElevationTile( 'weighted', $aTileSet, $T_WIDTH, $T_HEIGHT );
#	my $dataOut = convertElevationTile( 'linear',   $aTileSet, $T_WIDTH, $T_HEIGHT );
#	my $dataOut = convertElevationTile( 'gradient', $aTileSet, $T_WIDTH, $T_HEIGHT );
#	my $dataConv = convertTile_MultiDir( $dxL, $dyL, $dataSrnd_Contour );
#	my $dataConv = convertTile_weighted_count( $dxL, $dyL, $dataSrnd_Contour );

#	my $dataConv = convertTile_Radius( $dxL, $dyL, $dataSrnd_Contour );
#	$dataConv = convertTile_Radius( $dxL, $dyL, $dataConv );

#	my $dataConv = OGF::TileUtil::convertTile( 'weighted', $dxL, $dyL, $dataSrnd_Contour );

	my $startTime = time();
	my $dataConv = OGF::TileUtil::convertTile( 'radius', $dxL, $dyL, $dataSrnd_Contour );
#	print STDERR "radius elev duration = ", (time() - $startTime), "\n";
	$dataConv = OGF::TileUtil::convertTile( 'weighted', $dxL, $dyL, $dataConv );
#	$dataConv = convertTile_Border( $dxL, $dyL, $dataConv );


#	$dataConv = convertTile_GaussianBlur( $dxL, $dyL, $dataConv );


	my $dataOut  = OGF::TileUtil::extractSubtile( $margin,$margin, $dx,$dy, ,$dxL,$dyL, $dataConv );  # ???:  $dy, ,$dxL

#	my $fileOut = sprintf 'C:/Programme/Geography/World Wind 1.4/Cache/Earth/SRTM/%sElev/%d/%04d/%04d_%04d.bil', $layer, $level, $ty, $ty, $tx;
	my $fileOut = $wwInfo->copy( 'type' => 'elev' )->tileName();
#	print STDERR "\$fileOut <", $fileOut, ">\n";  # _DEBUG_
	writeToFile( $fileOut, $dataOut, undef, {-bin => 1, -mdir => 1} );
}

sub mergeStreamDataIntoContourLayer {
	require OGF::Terrain::ContourEditor;
	my( $dataContour, $dataStream, $dx, $dy ) = @_;
	print STDERR "--- mergeStreamDataIntoContourLayer ---\n";  # _DEBUG_

	my $aContour = makeArrayFromTile( $dataContour, $dx, $dy, $BPP );
	my $aStream  = makeArrayFromTile( $dataStream,  $dx, $dy, $BPP );
	mergeStreamArrayIntoContourLayer( $aContour, $aStream, [$dx,$dy] );
	my $dataOut = makeTileFromArray( $aContour, $BPP );
	return $dataOut;
}

sub mergeStreamArrayIntoContourLayer {
	require OGF::Util::StreamShape;
	my( $aContour, $aStream, $aTileSize ) = @_;
	$aTileSize = [ $T_WIDTH, $T_HEIGHT ] if ! defined $aTileSize;
	die qq/mergeStreamArrayIntoContourLayer: no contour layer/ if !defined $aContour;
	die qq/mergeStreamArrayIntoContourLayer: no stream layer/  if !defined $aStream;

	OGF::Util::Shape::sharpenContourLines( $aContour, $NO_ELEV_VALUE, $aStream );
	my $aShapes = OGF::Util::StreamShape::connectedShapes( $aStream, $aTileSize, 1 );
	foreach my $shape ( @$aShapes ){
		$shape->makeStreamElevation_R( $aContour );
	}
}



sub setEditor {
	my( $editor, $delay ) = @_;
	$EDITOR = $editor;
	$EDITOR->setPixelPaintDelay( $delay ) if defined $delay;
}





#-------------------------------------------------------------------------------

sub convertTile_Border {
	require OGF::Util::StreamShape;
	my( $dxL, $dyL, $dataIn, $radius ) = @_;

	my $aData = makeArrayFromTile( $dataIn, $dxL, $dyL, $BPP );
#	printTile( "aData", $aData, 128,128, 512,512 ); exit;

	my $aDataOut = makeArrayFromTile( makeEmptyTile($dxL,$dyL,$BPP,0), $dxL, $dyL, $BPP );

	my $aBorderShapes = OGF::Util::StreamShape::borderShapes( $aData, [$T_WIDTH,$T_HEIGHT], 0 );
	foreach my $shape ( @$aBorderShapes ){
		print "--- shape ($shape->{_elevType}) ---\n";
		if( $shape->{_elevType} eq 'DEPRESSION' ){
			setShapeElev_Depression( $shape, $aDataOut );
		}elsif( $shape->{_elevType} eq 'PEAK' ){
			setShapeElev_Peak( $shape, $aDataOut );
		}elsif( $shape->{_elevType} eq 'VARYING' ){
			setShapeElev_Varying( $shape, $aDataOut );
		}else{
			warn qq/Unexpected error: Unknown shape elevation type "$shape->{_elevType}"/;
		}
	}

	return makeTileFromArray( $aDataOut, $BPP );
}


sub setShapeElev_Depression {
	my( $shape, $aData ) = @_;
	my $elev = $shape->{_borderMax};
	foreach my $pt ( values %{$shape->{_shape}} ){
		my( $y, $x ) = @$pt;
		$aData->[$y][$x] = $elev;
		$EDITOR->updatePhotoPixel( $x, $y, '#33FF33' ) if $EDITOR;      # _DEBUG_
	}
}

sub setShapeElev_Peak {
	my( $shape, $aData ) = @_;
	foreach my $pt ( values %{$shape->{_shape}} ){
		my( $y, $x ) = @$pt;
		$aData->[$y][$x] = 0;
		$EDITOR->updatePhotoPixel( $x, $y, '#FF00FF' ) if $EDITOR;      # _DEBUG_
	}
}

sub setShapeElev_Varying {
	my( $shape, $aData ) = @_;
	my $num = scalar( values %{$shape->{_shape}} );
	if( $num > 2500 ){
		warn qq/setShapeElev_Varying: num > 2500  ($num)\n/;
		return;
	}
	foreach my $pt ( values %{$shape->{_shape}} ){
		my( $y, $x ) = @$pt;
		$aData->[$y][$x] = borderShapeElev( $shape, $aData, $y, $x );
		$EDITOR->updatePhotoPixel( $x, $y, '#FFDD00' ) if $EDITOR;      # _DEBUG_
	}
}

sub borderShapeElev {
	my( $shape, $aData, $y0, $x0 ) = @_;

#	my( $elev, $invDist ) = ( 0, 0 );
	my( $elevMin, $elevMax, $distMin, $distMax, $gradMax, $grad, $ptMin, $ptMax ) = ( 9999, -9999, 1000, 1000, -9999, 0 );

	my @vd;
	foreach my $pt ( values %{$shape->{_border}} ){
		my( $y, $x ) = @$pt;
		my $val = $aData->[$y][$x];
		next if $val <= $NO_ELEV_VALUE + 1;
		next if ! reachable_C( [$y0,$x0], [$y,$x], $aData );
		my $dist = dist( $x0, $y0, $x, $y );
		push @vd, [$val,$dist,[$y,$x]];
	}

	foreach my $aMin ( @vd ){
		foreach my $aMax ( @vd ){
			$grad = ($aMax->[0] - $aMin->[0]) / ($aMax->[1] + $aMin->[1]);
			( $gradMax, $elevMin, $distMin, $ptMin, $elevMax, $distMax, $ptMax ) = ( $grad, @$aMin, @$aMax ) if $grad > $gradMax;
		}
	}

#	if( $EDITOR && $ptMin && $ptMax ){
#		print STDERR "min = ($ptMin->[0],$ptMin->[1]) $elevMin    max = ($ptMax->[0],$ptMax->[1]) $elevMax\n";
#		paintMatrixLine( [$y0,$x0], $ptMin, $aLineMatrix );
#		paintMatrixLine( [$y0,$x0], $ptMax, $aLineMatrix );
#	}

#	return $NO_ELEV_VALUE if $gradMax <= 0;
	return ($elevMin * $distMax + $elevMax * $distMin) / ($distMin + $distMax);
}


#-------------------------------------------------------------------------------

sub convertTile_Radius {
	my( $dxL, $dyL, $dataIn, $radius ) = @_;
	$radius = 20 if !defined $radius;

	my $aData    = makeArrayFromTile( $dataIn, $dxL, $dyL, $BPP );
#	printTile( "aData", $aData, 128,128, 512,512 ); exit;
	my $aDataOut = makeArrayFromTile( makeEmptyTile($dxL,$dyL,$BPP,0), $dxL, $dyL, $BPP );
	my $aLineMatrix = makeLineMatrix( $radius );

#	print STDERR "scalar(\@\$aDataOut) <", scalar(@$aDataOut), ">\n";  # _DEBUG_
	my( $yMin, $yMax, $xMin, $xMax ) = ( $radius, $dyL-$radius, $radius, $dxL-$radius );

	for( my $y = $yMin; $y < $yMax; ++$y ){
		print STDERR "\$y <", $y, ">\n"; #  if $y % 100 == 0;  # _DEBUG_
		for( my $x = $xMin; $x < $xMax; ++$x ){
			$aDataOut->[$y][$x] = windowValue( $aData, $radius, $y, $x, $aLineMatrix );
		}
	}

	return makeTileFromArray( $aDataOut, $BPP );
}

sub windowValue {
	my( $aData, $radius, $y0, $x0, $aLineMatrix ) = @_;
	my( $yMin, $yMax, $xMin, $xMax ) = ( $y0-$radius, $y0+$radius, $x0-$radius, $x0+$radius );
#	print STDERR "\$yMin <", $yMin, ">  \$yMax <", $yMax, ">  \$xMin <", $xMin, ">  \$xMax <", $xMax, ">\n";  # _DEBUG_
#	return 0;

	return $aData->[$y0][$x0] if $aData->[$y0][$x0] != $NO_ELEV_VALUE;
	$EDITOR->updatePhotoPixel( $x0, $y0, '#000000' ) if $EDITOR;      # _DEBUG_

	my( $elev, $invDist ) = ( 0, 0 );
	my( $elevMin, $elevMax, $distMin, $distMax, $gradMax, $grad, $ptMin, $ptMax ) = ( 9999, -9999, 1000, 1000, -9999, 0 );

	my @vd;

	for( my $y = $yMin; $y <= $yMax; ++$y ){
		for( my $x = $xMin; $x <= $xMax; ++$x ){
			my $val = $aData->[$y][$x];
			next if $val == $NO_ELEV_VALUE;
			my $dist = dist( $x0, $y0, $x, $y );
			next if $dist > $radius;
			next if ! reachable( [$y0,$x0], [$y,$x], $aData, $aLineMatrix );

			$EDITOR->updatePhotoPixel( $x, $y, '#FF0000' ) if $EDITOR;      # _DEBUG_

			# --- avg ---
#			$elev += $val / $dist;
#			$invDist += 1 / $dist;

			# --- min/max ---
#			($elevMin,$distMin) = ($val,$dist) if $val < $elevMin;
#			($elevMax,$distMax) = ($val,$dist) if $val > $elevMax;
#			$distMin = $dist if $val == $elevMin && $dist < $distMin;
#			$distMax = $dist if $val == $elevMax && $dist < $distMax;

			# --- max. gradient 1 ---
#			if( $val <= $elevMin ){
#				$grad = ($elevMax - $val) / ($dist + $distMax);
#				if( $grad > $gradMax || $dist < $distMin ){
#					($elevMin,$distMin,$gradMax,$ptMin) = ($val,$dist,$grad,[$y,$x]);
#					print STDERR "\$elevMin <", $elevMin, ">  \$distMin <", $distMin, ">  \$gradMax <", $gradMax, ">  \$ptMin <", join('|',@$ptMin), ">\n";  # _DEBUG_
#				}
#			}
#			if( $val >= $elevMax ){
#				$grad = ($val - $elevMin) / ($distMin + $dist);
#				if( $grad > $gradMax || $dist < $distMax ){
#					($elevMax,$distMax,$gradMax,$ptMax) = ($val,$dist,$grad,[$y,$x]);
#					print STDERR "\$elevMax <", $elevMax, ">  \$distMax <", $distMax, ">  \$gradMax <", $gradMax, ">  \$ptMax <", join('|',@$ptMax), ">\n";  # _DEBUG_
#				}
#			}

			push @vd, [$val,$dist,[$y,$x]];
		}
	}
	# --- avg ---
#	if( $invDist == 0 ){
#		print "---- invDist = 0  [",($y0-128),",",($x0-128),"]\n" if $y0 >= 128 && $x0 >= 128 && $y0 < 640 && $x0 < 640;
#		return 0;
#	}
#	return int($elev / $invDist + .5);

	# --- min/max ---
#	print STDERR "\$elevMin <", $elevMin, ">  \$distMin <", $distMin, ">\n";  # _DEBUG_
#	print STDERR "\$elevMax <", $elevMax, ">  \$distMax <", $distMax, ">\n";  # _DEBUG_
#	return $NO_ELEV_VALUE if $distMin == 0 || $distMax == 0;

	foreach my $aMin ( @vd ){
		foreach my $aMax ( @vd ){
			$grad = ($aMax->[0] - $aMin->[0]) / ($aMax->[1] + $aMin->[1]);
			( $gradMax, $elevMin, $distMin, $ptMin, $elevMax, $distMax, $ptMax ) = ( $grad, @$aMin, @$aMax ) if $grad > $gradMax;
		}
	}


	if( $EDITOR && $ptMin && $ptMax ){
		print STDERR "min = ($ptMin->[0],$ptMin->[1]) $elevMin    max = ($ptMax->[0],$ptMax->[1]) $elevMax\n";
		paintMatrixLine( [$y0,$x0], $ptMin, $aLineMatrix );
		paintMatrixLine( [$y0,$x0], $ptMax, $aLineMatrix );
	}

	return $NO_ELEV_VALUE if $gradMax <= 0;
	return ($elevMin * $distMax + $elevMax * $distMin) / ($distMin + $distMax);
}

sub paintMatrixLine {
	my( $ptA, $ptB, $aLineMatrix ) = @_;
	my @linePts = getLinePoints( $ptA, $ptB, $aLineMatrix );
	foreach my $pt ( @linePts ){
		my( $yy, $xx ) = @$pt;
		$EDITOR->updatePhotoPixel( $xx, $yy, '#FFBB00' ) if $EDITOR;      # _DEBUG_
	}
}



sub reachable {
	my( $pt0, $pt1, $aData, $aLineMatrix ) = @_;
	my @linePts = getLinePoints( $pt0, $pt1, $aLineMatrix );
	my $ret = 1;
	foreach my $pt ( @linePts ){
		my( $yy, $xx ) = @$pt;
		if( $aData->[$yy][$xx] != $NO_ELEV_VALUE ){
			$ret = 0;
			last;
#		}else{
#			$EDITOR->updatePhotoPixel( $xx, $yy, '#FFBB00' ) if $EDITOR;      # _DEBUG_
		}
	}
	return $ret;
}

sub reachable_C {
	my( $pt0, $pt1, $aData, $aLineMatrix ) = @_;
	my $aLinePts = makeLinePoints( $pt1->[0] - $pt0->[0], $pt1->[1] - $pt0->[1] );
	my @linePts = map {[$pt0->[0] + $_->[0], $pt0->[1] + $_->[1]]} @$aLinePts;
	my $ret = 1;
	foreach my $pt ( @linePts ){
		my( $yy, $xx ) = @$pt;
		if( $aData->[$yy][$xx] != $NO_ELEV_VALUE ){
			$ret = 0;
			last;
#		}else{
#			$EDITOR->updatePhotoPixel( $xx, $yy, '#FFBB00' ) if $EDITOR;      # _DEBUG_
		}
	}
	return $ret;
}



sub getLinePoints {
	my( $ptA, $ptB, $aLineMatrix ) = @_;
	my $size2 = ( scalar(@$aLineMatrix) - 1 ) / 2;
	my $aLinePts = $aLineMatrix->[$ptB->[0] - $ptA->[0]+$size2][$ptB->[1] - $ptA->[1]+$size2];
	my @linePts = map {[$_->[0]+$ptA->[0],$_->[1]+$ptA->[1]]} @$aLinePts;
	return @linePts;
}

sub makeLineMatrix {
	my( $size2 ) = @_;

	my $aLineMatrix = [];
	foreach( my $y = -$size2; $y <= $size2; ++$y ){
		foreach( my $x = -$size2; $x <= $size2; ++$x ){
#			print STDERR "+++ \$y <", $y, ">  \$x <", $x, ">\n";  # _DEBUG_
			$aLineMatrix->[$y+$size2][$x+$size2] = makeLinePoints( $y, $x );
		}
	}

#	foreach( my $y = 0; $y <= 2 * $size2; ++$y ){
#		foreach( my $x = 0; $x <= 2 * $size2; ++$x ){
##			print STDERR "-------------------\n\$yI <", $y, ">  \$xI <", $x, ">  \$yS <", $y-$size2, ">  \$xS <", $x-$size2, ">\n";  # _DEBUG_
#			print STDERR "-------------------\n\[", $y-$size2, ",", $x-$size2, "]\n";  # _DEBUG_
#			my $ct = 0;
#			print STDERR join(" ", map {"(".($ct++).":$_->[0],$_->[1])"} @{$aLineMatrix->[$y][$x]} ), "\n";
#		}
#	}
#	exit;

	return $aLineMatrix;
}

sub makeLinePoints {
	my( $y0, $x0 ) = @_;
#	print STDERR "makeLinePoints ----- [$y0,$x0] -----\n";  # _DEBUG_
	my $aPoints = [];
	if( $y0 == 0 && $x0 == 0 ){
		# do nothing
	}elsif( abs($x0) > abs($y0) ){
		$aPoints = makeLinePoints( $x0, $y0 );
		$aPoints = [ map {[$_->[1],$_->[0]]} @$aPoints ];
	}elsif( $y0 < 0 ){
		$aPoints = makeLinePoints( -$y0, $x0 );
		$aPoints = [ map {[-$_->[0],$_->[1]]} @$aPoints ];
	}else{
		my $dd = $x0 / $y0;
		my %reached;
		for( my $y = 0; $y < $y0; ++$y ){
			my $x = POSIX::floor( $dd * ($y + 0.5) + 0.5 );
#			print STDERR "($dd * ($y + 0.5)) = ", ($dd * ($y + 0.5)), "\n";  # _DEBUG_
			my( $tag1, $tag2 ) = ( "$y,$x", "".($y+1).",$x" ); 
#			print STDERR "\$tag1 <", $tag1, ">  \$tag2 <", $tag2, ">\n";  # _DEBUG_
			push @$aPoints, [$y,$x]   if ! ($reached{$tag1} || ($y == 0 && $x == 0));
			$reached{$tag1} = 1;
			push @$aPoints, [$y+1,$x] if ! ($reached{$tag2} || ($y+1 == $y0 && $x == $x0));
			$reached{$tag2} = 1;
		}
	}
	return $aPoints;
}



sub dist {
	my( $xA, $yA, $xB, $yB ) = @_;
	return sqrt( ($xA - $xB) * ($xA - $xB) + ($yA - $yB) * ($yA - $yB) );
}


#-------------------------------------------------------------------------------

sub convertTile_GaussianBlur {
	my( $dxL, $dyL, $dataIn ) = @_;
	my $aData = makeArrayFromTile( $dataIn, $dxL, $dyL, 2 );

	my $aDataOut;
	$aDataOut = convertTile_GaussianBlur_S( $dxL, $dyL, $aData, 30 );
	resetContourPoints( $dxL, $dyL, $aDataOut, $aData, 30 );

	$aDataOut = convertTile_GaussianBlur_S( $dxL, $dyL, $aDataOut, 25 );
	resetContourPoints( $dxL, $dyL, $aDataOut, $aData, 25 );

	$aDataOut = convertTile_GaussianBlur_S( $dxL, $dyL, $aDataOut, 20 );
	resetContourPoints( $dxL, $dyL, $aDataOut, $aData, 20 );

	$aDataOut = convertTile_GaussianBlur_S( $dxL, $dyL, $aDataOut, 15 );
	resetContourPoints( $dxL, $dyL, $aDataOut, $aData, 15 );

	$aDataOut = convertTile_GaussianBlur_S( $dxL, $dyL, $aDataOut, 10 );
	resetContourPoints( $dxL, $dyL, $aDataOut, $aData, 10 );

	$aDataOut = convertTile_GaussianBlur_S( $dxL, $dyL, $aDataOut, 5 );
	resetContourPoints( $dxL, $dyL, $aDataOut, $aData, 5 );

	$aDataOut = convertTile_GaussianBlur_S( $dxL, $dyL, $aDataOut, 3 );
	resetContourPoints( $dxL, $dyL, $aDataOut, $aData, 3 );

	$aDataOut = convertTile_GaussianBlur_S( $dxL, $dyL, $aDataOut, 2 );
	resetContourPoints( $dxL, $dyL, $aDataOut, $aData, 2 );

	$aDataOut = convertTile_GaussianBlur_S( $dxL, $dyL, $aDataOut, 1 );

	return makeTileFromArray( $aDataOut, $BPP );
}


sub convertTile_GaussianBlur_S {
	my( $dxL, $dyL, $aData, $sigma ) = @_;
	print STDERR "---- sigma = $sigma -----\n";
	my $aDataOut = [];

	my $pi = atan2( 0, -1 );
	my( $p2, $s2, $s3 ) = ( sqrt(2 * $pi) * $sigma, 2 * $sigma * $sigma, 3 * $sigma );
	my( $sum, @func ) = 0;
	for( my $i = -$s3; $i <= $s3; ++$i ){ 
		$func[$i+$s3] = exp( -($i * $i) / $s2 ) / $p2;
		$sum += $func[$i+$s3];
	}
	@func = map {$_/$sum} @func;
	print STDERR "\@func <", join('|',@func), ">\n";  # _DEBUG_

	my( $nMin, $nMax ) = ( $s3 + 1, $dxL - 2 - $s3 );

	for( my $y = 0; $y < $dyL; ++$y ){
		print STDERR "\$y <", $y, ">\n" if $y % 100 == 0;  # _DEBUG_
		for( my $x = 0; $x < $dxL; ++$x ){
			if( $x >= $nMin && $x < $nMax ){
				$aDataOut->[$y][$x] = 0;
				for( my $i = 0; $i <= $#func; ++$i ){
					$aDataOut->[$y][$x] += $func[$i] * $aData->[$y][$x-$s3-1+$i];
				}
			}else{
				$aDataOut->[$y][$x] = $aData->[$y][$x];
			}
		}
	}	

	for( my $x = 0; $x < $dxL; ++$x ){
		print STDERR "\$x <", $x, ">\n" if $x % 100 == 0;  # _DEBUG_
		for( my $y = 0; $y < $dyL; ++$y ){
			if( $y >= $nMin && $y < $nMax ){
				$aDataOut->[$y][$x] = 0;
				for( my $i = 0; $i <= $#func; ++$i ){
					$aDataOut->[$y][$x] += $func[$i] * $aData->[$y-$s3-1+$i][$x];
				}
			}else{
				$aDataOut->[$y][$x] = $aData->[$y][$x];
			}
		}
	}	

	return $aDataOut;
}

sub resetContourPoints {
	my( $dxL, $dyL, $aDataOut, $aData, $sigma ) = @_;
	my $s3 = 3 * $sigma;
	my( $nMin, $nMax ) = ( $s3 + 1, $dxL - 2 - $s3 );
	my( $diff, $count ) = ( 0, 0 );

	for( my $y = $nMin; $y < $nMax; ++$y ){
#		print STDERR "C \$y <", $y, ">\n" if $y % 100 == 0;  # _DEBUG_
		for( my $x = $nMin; $x < $nMax; ++$x ){
			if( $aData->[$y][$x] != $NO_ELEV_VALUE ){
				++$count;
				$diff += abs( $aDataOut->[$y][$x] - $aData->[$y][$x] );
				$aDataOut->[$y][$x] = $aData->[$y][$x];
			}
		}
	}
	print "Avg. diff: ", ($diff/$count), "\n";
}



#-------------------------------------------------------------------------------


sub convertTile_MultiDir {
	my( $dxL, $dyL, $dataIn ) = @_;
	my $aData = makeArrayFromTile( $dataIn, $dxL, $dyL, 2 );
	my $aDataOut = [];

	for( my $y = 0; $y < $dyL; ++$y ){
		print STDERR "\$y <", $y, ">\n";  # _DEBUG_
		for( my $x = 0; $x < $dxL; ++$x ){
			if( $aData->[$y][$x] == $NO_ELEV_VALUE ){
#				$aDataOut->[$y][$x] = multiDirectionValue_sum( $aData, $y, $x, [$dxL,$dyL] );
				$aDataOut->[$y][$x] = multiDirectionValue_weighted( $aData, $y, $x, [$dxL,$dyL] );
			}else{
				$aDataOut->[$y][$x] = $aData->[$y][$x];
			}
		}
	}

	return makeTileFromArray( $aDataOut, $BPP );
}

sub multiDirectionValue_sum {
	my( $aData, $y, $x, $aSize ) = @_;
	my( $sumVal, $sumInvDist );
	foreach my $aDir ( [-1,-1], [-1,0], [-1,1], [0,1], [1,1], [1,0], [1,-1], [0,-1] ){
		my( $val, $dist ) = findDirectionValue( $aData, $y, $x, $aDir, $aSize );
		if( defined $val ){
			$sumVal += ($val / $dist);
			$sumInvDist += (1 / $dist);
		}
	}
	return ($sumVal / $sumInvDist);
}

sub multiDirectionValue_weighted {
	my( $aData, $y, $x, $aSize ) = @_;
	my( $valA, $distA, $valB, $distB );
	my( $sumVal, $sumWeight, $weight, $dist ) = ( 0, 0 );

	( $valA, $distA ) = findDirectionValue( $aData, $y, $x, [-1, 1], $aSize );
	( $valB, $distB ) = findDirectionValue( $aData, $y, $x, [ 1,-1], $aSize );
	if( defined($valA) && defined($valB) ){
		$weight = abs($valA - $valB) + .001;
		$dist = $distA + $distB;
		$sumVal += $weight * ($valA * $distB/$dist + $valB * $distA/$dist);
		$sumWeight += $weight;
	}

	( $valA, $distA ) = findDirectionValue( $aData, $y, $x, [-1, 0], $aSize );
	( $valB, $distB ) = findDirectionValue( $aData, $y, $x, [ 1, 0], $aSize );
	if( defined($valA) && defined($valB) ){
		$weight = abs($valA - $valB) + .001;
		$dist = $distA + $distB;
		$sumVal += $weight * ($valA * $distB/$dist + $valB * $distA/$dist);
		$sumWeight += $weight;
	}

	( $valA, $distA ) = findDirectionValue( $aData, $y, $x, [-1,-1], $aSize );
	( $valB, $distB ) = findDirectionValue( $aData, $y, $x, [ 1, 1], $aSize );
	if( defined($valA) && defined($valB) ){
		$weight = abs($valA - $valB) + .001;
		$dist = $distA + $distB;
		$sumVal += $weight * ($valA * $distB/$dist + $valB * $distA/$dist);
		$sumWeight += $weight;
	}

	( $valA, $distA ) = findDirectionValue( $aData, $y, $x, [ 0, 1], $aSize );
	( $valB, $distB ) = findDirectionValue( $aData, $y, $x, [ 0,-1], $aSize );
	if( defined($valA) && defined($valB) ){
		$weight = abs($valA - $valB) + .001;
		$dist = $distA + $distB;
		$sumVal += $weight * ($valA * $distB/$dist + $valB * $distA/$dist);
		$sumWeight += $weight;
	}

	return ($sumWeight != 0)? ($sumVal / $sumWeight) : 0;
}

#-------------------------------------------------------------------------------


sub convertTile_weighted_count {
	my( $dxL, $dyL, $dataIn ) = @_;
	my $aData = makeArrayFromTile( $dataIn, $dxL, $dyL, 2 );
	my $aDataOut = [];

	my( $count1, $count2 ) = ( 999999998, 999999999 );
	while( $count1 < $count2 ){
		$count2 = $count1;
		print STDERR "\$count2 <", $count2, ">\n"; sleep 1; # _DEBUG_
		$count1 = 0;
		for( my $y = 0; $y < $dyL; ++$y ){
			print STDERR "\$y <", $y, ">\n";  # _DEBUG_
			for( my $x = 0; $x < $dxL; ++$x ){
				if( $aData->[$y][$x] == $NO_ELEV_VALUE ){
					$aDataOut->[$y][$x] = directionValue_weighted_default( $aData, $y, $x, [$dxL,$dyL] );
				}else{
					$aDataOut->[$y][$x] = $aData->[$y][$x];
				}
				++$count1 if $aDataOut->[$y][$x] == $NO_ELEV_VALUE;
			}
		}
		$aData = $aDataOut;
	}


	 for( my $y = 0; $y < $dyL; ++$y ){
		 print STDERR "\$y <", $y, ">\n";  # _DEBUG_
		 for( my $x = 0; $x < $dxL; ++$x ){
			 if( $aData->[$y][$x] == $NO_ELEV_VALUE ){
				 $aDataOut->[$y][$x] = multiDirectionValue_weighted( $aData, $y, $x, [$dxL,$dyL] );
			 }
		 }
	 }


	return makeTileFromArray( $aDataOut, $BPP );
}

sub directionValue_weighted_default {
	my( $aData, $y, $x, $aSize ) = @_;
	my( $valA, $distA, $valB, $distB );
	my( $sumVal, $sumWeight, $weight, $dist ) = ( 0, 0 );

	( $valA, $distA ) = findDirectionValue( $aData, $y, $x, [-1, 1], $aSize );
	( $valB, $distB ) = findDirectionValue( $aData, $y, $x, [ 1,-1], $aSize );
	if( defined($valA) && defined($valB) ){
		$weight = abs($valA - $valB);
		$dist = $distA + $distB;
		$sumVal += $weight * ($valA * $distB/$dist + $valB * $distA/$dist);
		$sumWeight += $weight;
	}

	( $valA, $distA ) = findDirectionValue( $aData, $y, $x, [-1, 0], $aSize );
	( $valB, $distB ) = findDirectionValue( $aData, $y, $x, [ 1, 0], $aSize );
	if( defined($valA) && defined($valB) ){
		$weight = abs($valA - $valB);
		$dist = $distA + $distB;
		$sumVal += $weight * ($valA * $distB/$dist + $valB * $distA/$dist);
		$sumWeight += $weight;
	}

	( $valA, $distA ) = findDirectionValue( $aData, $y, $x, [-1,-1], $aSize );
	( $valB, $distB ) = findDirectionValue( $aData, $y, $x, [ 1, 1], $aSize );
	if( defined($valA) && defined($valB) ){
		$weight = abs($valA - $valB);
		$dist = $distA + $distB;
		$sumVal += $weight * ($valA * $distB/$dist + $valB * $distA/$dist);
		$sumWeight += $weight;
	}

	( $valA, $distA ) = findDirectionValue( $aData, $y, $x, [ 0, 1], $aSize );
	( $valB, $distB ) = findDirectionValue( $aData, $y, $x, [ 0,-1], $aSize );
	if( defined($valA) && defined($valB) ){
		$weight = abs($valA - $valB);
		$dist = $distA + $distB;
		$sumVal += $weight * ($valA * $distB/$dist + $valB * $distA/$dist);
		$sumWeight += $weight;
	}

	my $elev = $NO_ELEV_VALUE;
	if( $sumWeight > 0 ){
		$elev = $sumVal / $sumWeight;
	}

	return $elev;
}




sub multiDirectionValue_minMax {
	my( $aData, $y, $x, $aSize ) = @_;
	my( $minVal, $maxVal, $minValDist, $maxValDist ) = ( 99999, -99999 );
	foreach my $aDir ( [-1,-1], [-1,0], [-1,1], [0,1], [1,1], [1,0], [1,-1], [0,-1] ){
		my( $val, $dist ) = findDirectionValue( $aData, $y, $x, $aDir, $aSize );
		if( defined $val ){
			($minVal,$minValDist) = ($val,$dist) if $val < $minVal;
			($maxVal,$maxValDist) = ($val,$dist) if $val > $maxVal;
		}
	}
	return ($minVal * $maxValDist + $maxVal * $minValDist) / ($maxValDist + $minValDist);
}

sub findDirectionValue {
	my( $aData, $y0, $x0, $aDir, $aSize ) = @_;
	my( $x,$y, $dx,$dy, $wd,$hg, $val, $dist ) = ( $x0,$y0, @$aDir, @$aSize );
	while( 1 ){
		$y += $dy;
		$x += $dx;
		if( $y < 0 || $x < 0 || $y >= $hg || $x >= $wd ){
			return ( undef, undef );
		}
		if( $aData->[$y][$x] != $NO_ELEV_VALUE ){
			$val = $aData->[$y][$x];
			$dist = sqrt(($x - $x0) * ($x - $x0) + ($y - $y0) * ($y - $y0));
			last;
		}
		if( abs($dx) + abs($dy) == 2 ){
			if( $y < 1 || $x < 1 || $y >= $hg-1 || $x >= $wd-1 ){
				next;
			}
			( $val, my $ct ) = ( 0, 0 );
			if( $aData->[$y][$x+$dx] != $NO_ELEV_VALUE ){
				$val += $aData->[$y][$x+$dx];
				++$ct;
			}
			if( $aData->[$y+$dy][$x] != $NO_ELEV_VALUE ){
				$val += $aData->[$y+$dy][$x];
				++$ct
			}
			if( $ct > 0 ){
				$val = $val / $ct;
				$dist = sqrt(($x - $x0) * ($x - $x0) + ($y - $y0) * ($y - $y0));
				last;
			}
		}
	}
	return ( $val, $dist );
}




#--- obsolete ---------------------------------------------------------------------------------

sub makeElevationFile__OLD {
	my( $layer, $tx, $ty ) = @_;
	printf "%04d %04d\n", $tx, $ty;
	my $aTileSet = [];

	for( my $y = -1; $y <= 1; ++$y ){
		for( my $x = -1; $x <= 1; ++$x ){
			next if ($x * $y) != 0;  # load only needed tiles
			my $fileIn  = sprintf 'C:/Map/%s/WW_elev/4/%04d/%04d_%04d.cnr', $layer, $ty+$y, $ty+$y, $tx+$x;

			my $dataIn = (-f $fileIn)? readFromFile($fileIn,{-bin => 1}) : getEmptyTile();
			my $aRowsIn = makeArrayFromTile( $dataIn, $T_WIDTH, $T_HEIGHT, $BPP );
#			printTile( 't11', $aRowsIn ) if $x == 0 && $y == 0;

			$aTileSet->[1-$y][$x+1] = $aRowsIn;
		}
	}

	my $aRowsOut = makeElevationFromContour( $aTileSet, $T_WIDTH, $T_HEIGHT );
	my $dataOut = makeTileFromArray( $aRowsOut, $BPP );

	my $fileOut = sprintf 'C:/Programme/Geography/World Wind 1.4/Cache/Earth/SRTM/%sElev/0/%04d/%04d_%04d.bil', $layer, $ty, $ty, $tx;
	writeToFile( $fileOut, $dataOut, undef, {-bin => 1} );
}

sub makeElevationFromContour_PERL {
	my( $aTileSet, $dx, $dy ) = @_;
	my( $aHoriz, $aVert, $aAverage ) = ( [], [], [] );
#	printArray( 'aRows', $aRows );

	for( my $y = 0; $y < $dy; ++$y ){
		my $aRow = getTsYrow( $aTileSet, $y );
		my $aLinear = interpolateLinear( $aRow );
		setYrow( $aHoriz, $y, $aLinear, $dx, $dx );
	}
#	printArray( 'aHoriz', $aHoriz );

	for( my $x = 0; $x < $dx; ++$x ){
		my $aRow = getTsXcol( $aTileSet, $x );
		my $aLinear = interpolateLinear( $aRow );
		setXcol( $aVert, $x, $aLinear, $dy, $dy );
	}
#	printArray( 'aVert', $aVert );

	for( my $y = 0; $y < $dy; ++$y ){
		for( my $x = 0; $x < $dx; ++$x ){
#			print STDERR "\$aHoriz->[$x][$y] <", $aHoriz->[$x][$y], ">\n";  # _DEBUG_
#			print STDERR "\$aVert->[$x][$y]  <", $aVert->[$x][$y], ">\n";  # _DEBUG_
			$aAverage->[$x][$y] = ($aHoriz->[$x][$y] + $aVert->[$x][$y]) / 2;
		}
	}
	return $aAverage;
}

sub interpolateLinear_PERL {
	my( $aRow ) = @_;
	my( $idxP, $valP, @ret ) = ( -1, 0 );
	my $n = scalar( @$aRow );

	for( my $i = 0; $i <= $n; ++$i ){
		my $val;
		if( $i < $n ){
			$val = $aRow->[$i];
			next if $val == $NO_ELEV_VALUE;
			$ret[$i] = $val;
		}else{
			$val = 0;
		}

		my $dd = ($val-$valP) / ($i-$idxP);
		for( my $j = $idxP+1; $j < $i; ++$j ){
			$ret[$j] = $valP + ($j - $idxP) * $dd;
		}
		( $idxP, $valP ) = ( $i, $val );
	}
	return \@ret;
}



1;

