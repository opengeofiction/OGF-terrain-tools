package OGF::Util::StreamShape;
use strict;
use warnings;
use OGF::Terrain::ElevationTile qw( $NO_ELEV_VALUE $T_WIDTH $T_HEIGHT $BPP );


my $SQRT_2 = sqrt( 2 );
my @DDXX = ( [-1,-1], [-1,0], [-1,1], [0,1], [1,1], [1,0], [1,-1], [0,-1] );
my $EDITOR;




sub new {
	my( $pkg, $hShape ) = @_;
	my $self = {
		_shape   => ($hShape ? $hShape : {}),
		_contour => {},
		_dist    => {},
	};
	bless $self, $pkg;
}


sub connectedShapes {
	my( $aStream, $aTileSize, $margin ) = @_;
	$margin = 0 if ! defined $margin;
	my @shapes;
	my( $wd, $hg ) = ( scalar(@{$aStream->[0]}), scalar(@$aStream) );
	for( my $y = $margin; $y < $hg-$margin; ++$y ){
		for( my $x = $margin; $x < $wd-$margin; ++$x ){
			if( $aStream->[$y][$x] != $NO_ELEV_VALUE ){
				my $shape = singleShape( $y,$x, $aStream, $aTileSize, $margin );
				push @shapes, $shape;
			}
		}
	}
	return \@shapes;
}

sub singleShape {
	my( $y,$x, $aStream, $aTileSize, $margin ) = @_;
	$aTileSize = [ $T_WIDTH, $T_HEIGHT ] if ! defined $aTileSize;
	my $hShape = {};
	singleShape_R( $y,$x, $aStream, $aTileSize, $hShape, $margin );
#	print STDERR "A shape <", join('|',keys %$hShape), ">\n";  # _DEBUG_
	return OGF::Util::StreamShape->new( $hShape );
}

sub singleShape_R {
	my( $y,$x, $aStream, $aTileSize, $hShape, $margin ) = @_;
	my $ptag = ptag([$y,$x]);
	$hShape->{$ptag} = [ $y, $x ];
	$aStream->[$y][$x] = $NO_ELEV_VALUE;
	$EDITOR->updatePhotoPixel( $x, $y, '#FF0000' ) if $EDITOR;      # _DEBUG_
#	print STDERR "remove [$y,$x]\n";
	foreach my $dd ( @DDXX ){
		my( $yd, $xd ) = ( $y + $dd->[0], $x + $dd->[1] );
		if( inArea($aTileSize,[$xd,$yd],$margin) && $aStream->[$yd][$xd] != $NO_ELEV_VALUE ){
#			print STDERR "\$aStream->[$yd][$xd] <", $aStream->[$yd][$xd], ">\n";  # _DEBUG_
			singleShape_R( $yd,$xd, $aStream, $aTileSize, $hShape, $margin );
		}
	}
}



sub borderShapes {
	my( $aTile, $aSize, $margin ) = @_;
	$margin = 0 if ! defined $margin;
	my @shapes;
	my( $wd, $hg ) = ( scalar(@{$aTile->[0]}), scalar(@$aTile) );
	for( my $y = $margin; $y < $hg-$margin; ++$y ){
		for( my $x = $margin; $x < $wd-$margin; ++$x ){
			if( $aTile->[$y][$x] == $NO_ELEV_VALUE ){
				my $shape = borderShape( $y,$x, $aTile, $aSize, $margin );
				push @shapes, $shape;
			}
		}
	}
	return \@shapes;
}

sub borderShape {
	my( $y,$x, $aTile, $aSize, $margin ) = @_;
	$aSize = [ $T_WIDTH, $T_HEIGHT ] if ! defined $aSize;
	my $hShape = {};
	borderShape_R( $y,$x, $aTile, $aSize, $hShape, $margin );
#	print STDERR "A shape <", join('|',keys %$hShape), ">\n";  # _DEBUG_
	my $shape = OGF::Util::StreamShape->new( $hShape );
	$shape->addBorder( $aTile, $aSize );
	return $shape;
}

sub borderShape_R {
	my( $y,$x, $aTile, $aSize, $hShape, $margin ) = @_;
	my $ptag = ptag([$y,$x]);
	$hShape->{$ptag} = [ $y, $x ];
	$aTile->[$y][$x] = $NO_ELEV_VALUE + 1;
	$EDITOR->updatePhotoPixel( $x, $y, '#FFFFCC' ) if $EDITOR;      # _DEBUG_
#	print STDERR "remove [$y,$x]\n";
	my @ddxx = grep {$_->[0] == 0 || $_->[1] == 0} @DDXX;
	foreach my $dd ( @ddxx ){
		my( $yd, $xd ) = ( $y + $dd->[0], $x + $dd->[1] );
		if( inArea($aSize,[$xd,$yd],$margin) && $aTile->[$yd][$xd] == $NO_ELEV_VALUE ){
#			print STDERR "\$aTile->[$yd][$xd] <", $aTile->[$yd][$xd], ">\n";  # _DEBUG_
			borderShape_R( $yd,$xd, $aTile, $aSize, $hShape, $margin );
		}
	}
}

sub addBorder {
	my( $self, $aTile, $aSize ) = @_;
	my( $ptStart ) = values %{$self->{_shape}};
	my $ptBorder;
	my( $y0, $x0 ) = @$ptStart;
	for( my $x = $x0; $x < $aSize->[1]; ++$x ){
		if( $aTile->[$y0][$x] > $NO_ELEV_VALUE + 1 ){
			$ptBorder = [ $y0, $x ];
			last;
		} 
	}
	if( ! $ptBorder ){
		warn qq/Unexpected error: Cannot find initial border point.\n/;
		return;
	}
	my $hBorder = { ptag($ptBorder) => $ptBorder };
	( $self->{_borderMin}, $self->{_borderMax} ) = ( 9999, -9999 );
	my $pt = [ @$ptBorder ];
	my $i0 = 0;
	do{
		foreach my $i ( 0..7 ){
			$i = ($i0 + $i) % 8;
#			print STDERR "  \$i <", $i, ">\n";  # _DEBUG_
			my $dd = $DDXX[$i];
			my( $yd, $xd ) = ( $pt->[0] + $dd->[0], $pt->[1] + $dd->[1] );
			if( ! inArea($aSize,[$xd,$yd]) ){
				warn qq/Unexpected error: border point outside of tile./;
				return;
			}
			my $elev = $aTile->[$yd][$xd];
			if( $elev > $NO_ELEV_VALUE + 1 ){
				$self->{_borderMin} = $elev if $elev < $self->{_borderMin};
				$self->{_borderMax} = $elev if $elev > $self->{_borderMax};
#				print STDERR "\$aTile->[$yd][$xd] <", $aTile->[$yd][$xd], ">\n";  # _DEBUG_
				$pt = [ $yd, $xd ];
				$hBorder->{ptag($pt)} = $pt;
				$i0 = ($i - 4 + 1) % 8;
#				print STDERR "\$i0 <", $i0, ">\n";  # _DEBUG_
				last;
			}
		}
	}while( !($pt->[0] == $ptBorder->[0] && $pt->[1] == $ptBorder->[1]) );

	$self->{_elevType} = 'VARYING';
	if( $EDITOR && $self->{_borderMin} == $self->{_borderMax} ){      # _DEBUG_
		my $elevOut;
		foreach my $dd ( @DDXX ){
			my( $yd, $xd ) = ( $ptBorder->[0] + $dd->[0], $ptBorder->[1] + $dd->[1] );
			print STDERR "\$yd <", $yd, ">  \$xd <", $xd, ">\n";  # _DEBUG_
			next if $hBorder->{"$yd,$xd"} || $self->{_shape}->{"$yd,$xd"};
			$elevOut = $aTile->[$yd][$xd];
			print STDERR "\$elevOut <", $elevOut, ">\n";  # _DEBUG_
			last;
		}
		die qq/Unexpected error: cannot determine outside elevation./ if !defined $elevOut;
		$self->{_elevType} = ($elevOut >= $self->{_borderMin} || $elevOut <= $NO_ELEV_VALUE+1)? 'DEPRESSION' : 'PEAK';
	}
	my %borderColor = ( VARYING => '#FFDD00', DEPRESSION => '#33FF33', PEAK => '#FF00FF' );

#	if( $EDITOR ){
#		foreach my $pt ( values %$hBorder ){
#			$EDITOR->updatePhotoPixel( $pt->[1], $pt->[0], $borderColor{$self->{_elevType}} );
#		}
#	}

	$self->{_border} = $hBorder;
}




sub makeStreamElevation_R {
	my( $self, $aContour, $hOpt ) = @_;
	my $aSubShapes = $self->contourDelimitedSubshapes( $aContour );
	foreach my $subShape ( @$aSubShapes ){
#		print STDERR "\%{\$subShape->{_contour}} <", join('|',%{$subShape->{_contour}}), ">\n";  # _DEBUG_
#		print STDERR "subShape <", join('|',keys %{$subShape->{_shape}}), ">\n";  # _DEBUG_
		if( $hOpt && $hOpt->{-start} ){
			if( $subShape->containsPoint($hOpt->{-start}) ){
				$EDITOR->setPixelPaintDelay( 0.01 );
			}else{
				next;
			}
		}
		$subShape->setContourPoints( $aContour );
		my $ret = $subShape->setLowestContourPath( $aContour );
		$subShape->makeStreamElevation_R( $aContour ) if $ret;
	}
}

sub containsPoint {
	my( $self, $pt ) = @_;
	return (exists $self->{_shape}{ptag($pt)});
}


sub setLowestContourPath {
	my( $self, $aContour ) = @_;
	my $ret = 0;
	my $ptS = $self->getLowestStartPoint();
	if( defined $ptS ){
		$self->setContourDist_R( $ptS, 1 );
		my $ptE = $self->getLowestEndPoint( $ptS );
		if( $ptE ){
			$self->setContourPath( $ptS, $ptE, $aContour );
			$ret = 1;
		}
	}else{
		map {$EDITOR->updatePhotoPixel($_->[1],$_->[0],'#FFFFFF')} values %{$self->{_shape}} if $EDITOR;
	}
	return $ret;
}

sub setContourDist_R {
	my( $self, $pt, $dist ) = @_;
	my $hShape = $self->{_shape};

	$self->{_dist}{ptag($pt)} = $dist;
	$EDITOR->updatePhotoPixel( $pt->[1], $pt->[0], '#0000FF' ) if $EDITOR;      # _DEBUG_
#	$hReached->{$ptag} = 1;

	foreach my $dd ( @DDXX ){
		my $pt2 = [ $pt->[0] + $dd->[0], $pt->[1] + $dd->[1] ];
		my $ptag2 = ptag($pt2);
		next if ! $hShape->{$ptag2};
		next if $self->{_dist}{$ptag2};
		my $cdist = $self->minContourDist( $pt2, $self->{_dist} );
		$self->setContourDist_R( $pt2, $cdist );
	}
}


sub minContourDist {
	my( $self, $pt, $hDist ) = @_;
	my $hShape = $self->{_shape};
#	my $ptag = ptag( $pt );
	my $minDist = 999999;

	foreach my $dd ( @DDXX ){
		my( $yd, $xd ) = ( $pt->[0] + $dd->[0], $pt->[1] + $dd->[1] );
		my $ptag = ptag( [$yd,$xd] );
		if( defined $hDist->{$ptag} ){
			my $dist = (abs($xd) + abs($yd) == 2)? $SQRT_2 : 1;
			if( $hDist->{$ptag} + $dist < $minDist ){
				$minDist = $hDist->{$ptag} + $dist;
			}
		}
	}
	die qq/Unexpected error: minDist == 999999/ if $minDist == 999999;
#	print STDERR "minDist [", $pt->[0], ",", $pt->[1], "]  $minDist\n";  # _DEBUG_
	return $minDist;
}

sub internalMaxDist {
	my( $hPoints ) = @_;
	my @points = map {tagPt($_)} keys %$hPoints;
	my $maxDist = 0;
	for( my $i = 0; $i <= $#points; ++$i ){
		for( my $j = 0; $j < $i; ++$j ){
			my $dist = ptDist( $points[$i], $points[$j] );
			$maxDist = $dist if $dist > $maxDist;
		}
	}
	return $maxDist;
}


our $MIN_VALID_DIST = 20;

sub getLowestStartPoint {
	my( $self, $aContour ) = @_;
	my @contourValues = sort {$a <=> $b} values %{$self->{_contour}};
	if( ! @contourValues ){
#		print STDERR "shape <", join('|',keys %{$self->{_shape}}), ">\n";  # _DEBUG_
#		die qq/Unexpected error: empty contourValues array !!!/;
		return undef;
	}
	my $val = $contourValues[0];
	return undef if $val == $contourValues[-1] && internalMaxDist($self->{_contour}) < $MIN_VALID_DIST;
	my @points = grep {$self->{_contour}{$_} == $val} keys %{$self->{_contour}};
	return tagPt( $points[0] );
}

sub getLowestEndPoint {
	my( $self, $ptS ) = @_;
	my( $hContour, $hDist ) = ( $self->{_contour}, $self->{_dist} );
	my $startElev = $hContour->{ptag($ptS)};
	my( $minInc, $ptE ) = ( 999999 );
	foreach my $ptag ( keys %$hContour ){
		next if $hContour->{$ptag} == $startElev && ptDist($ptS,tagPt($ptag)) < $MIN_VALID_DIST;
		my $inc = ($hContour->{$ptag} - $startElev) / $hDist->{$ptag};
		( $minInc, $ptE ) = ( $inc, tagPt($ptag) ) if $inc < $minInc;
	}
	warn qq/Unexpected error: no lowest end point found (/, ptag($ptS), qq/)\n/ if ! defined $ptE;
	return $ptE;
}

sub setContourPath {
	my( $self, $ptS, $ptE, $aContour ) = @_;
	my( $hContour, $hDist, $hShape ) = ( $self->{_contour}, $self->{_dist}, $self->{_shape} );
	my( $ptagS, $ptagE ) = ( ptag($ptS), ptag($ptE) );
	my( $startElev, $inc ) = ( $hContour->{$ptagS}, ($hContour->{$ptagE} - $hContour->{$ptagS}) / $hDist->{$ptagE} );
	my $pt = $ptE;
	while( 1 ){
		$aContour->[$pt->[0]][$pt->[1]] = $startElev + $hDist->{ptag($pt)} * $inc;
		$EDITOR->updatePhotoPixel( $pt->[1], $pt->[0], '#22EE00' ) if $EDITOR;      # _DEBUG_
		last if ptag($pt) eq $ptagS;

		my( $minDist, $ptMin ) = ( 999999 );
		foreach my $dd ( @DDXX ){
			my $pt2 = [ $pt->[0] + $dd->[0], $pt->[1] + $dd->[1] ];
			my $ptag2 = ptag( $pt2 );
			next if ! $hShape->{$ptag2};
			( $minDist, $ptMin ) = ( $hDist->{$ptag2}, $pt2 ) if $hDist->{$ptag2} < $minDist;
		}
		die qq/Unexpected error: no minDist neighbor point/ if ! defined $ptMin;
		$pt = $ptMin;
	}
}

sub contourDelimitedSubshapes {
	my( $self, $aContour ) = @_;
	my $hShape = $self->{_shape};
	my @subShapes = ();

	my $pt;
	while( defined($pt = getNonContourPoint($hShape,$aContour)) ){
		my $subShape = OGF::Util::StreamShape->new();
		$self->addToSubshape_R( $pt, $subShape, $aContour );
		push @subShapes, $subShape;
#		print STDERR "\%{\$subShape->{_contour}} <", join('|',%{$subShape->{_contour}}), ">\n";  # _DEBUG_
	}

#	print STDERR "subShapes: ", (scalar @subShapes), "\n";  # _DEBUG_
	return \@subShapes;
}

sub addToSubshape_R {
	my( $self, $pt, $subShape, $aContour ) = @_;
	my( $hShape, $hSub ) = ( $self->{_shape}, $subShape->{_shape} );

	my $ptag = ptag( $pt );
	$hSub->{$ptag} =	delete $hShape->{$ptag};
	my( $y, $x ) = @$pt;
	$EDITOR->updatePhotoPixel( $x, $y, '#00FFFF' ) if $EDITOR;      # _DEBUG_

	foreach my $i ( 0..$#DDXX ){
		my $dd = $DDXX[$i];
		my $pt2 = [ $y + $dd->[0], $x + $dd->[1] ];
		if( $hShape->{ptag($pt2)} ){
			my $contourValue = contourBarrier( $pt, $i, $aContour );
#			if( isContourPoint($pt2,$aContour) || contourBarrier($pt,$i,$aContour) ){
			if( $contourValue == $NO_ELEV_VALUE ){
				$self->addToSubshape_R( $pt2, $subShape, $aContour );
			}
		}
	}
}

sub getNonContourPoint {
	my( $hShape, $aContour ) = @_;
	my @points = values %$hShape;
	my $ptNC;
	foreach my $pt ( @points ){
		if( ! isContourPoint($pt,$aContour) ){
			$ptNC = $pt;
			last;
		}
	}
	return $ptNC;
}

sub setContourPoints {
	my( $self, $aContour ) = @_;
	my $hShape = $self->{_shape};
#	print STDERR "shape <", join('|',keys %$hShape), ">\n";  # _DEBUG_
	foreach my $pt ( values %$hShape ){
		my $val = neighborContourValue( $pt, $aContour );
		$self->{_contour}{ptag($pt)} = $val if $val != $NO_ELEV_VALUE;
	}
}

sub neighborContourValue {
	my( $pt, $aContour ) = @_;
	my $val = $NO_ELEV_VALUE;
	foreach my $dd ( @DDXX ){
		my( $y2, $x2 ) = ( $pt->[0] + $dd->[0], $pt->[1] + $dd->[1] );
		my $val2 = $aContour->[$y2][$x2];
#		print STDERR "\$y2 <", $y2, ">  \$x2 <", $x2, ">  \$val2 <", $val2, ">\n";  # _DEBUG_
		$val = $val2 if $val2 != $NO_ELEV_VALUE && ($val2 < $val || $val == $NO_ELEV_VALUE);
	}
	return $val;
}

sub contourBarrier {
	my( $pt, $i, $aContour ) = @_;

	my( $y, $x ) = @$pt;
	my $dd = $DDXX[$i];
	my( $y0, $x0 ) = ( $y + $dd->[0], $x + $dd->[1] );

	my $val = $aContour->[$y0][$x0];
	return $val if $val != $NO_ELEV_VALUE;

	return $NO_ELEV_VALUE if $i % 2 != 0;

	my( $dd0, $dd1 ) = ( $DDXX[($i-1) % 8], $DDXX[($i+1) % 8] );
	my( $yd0, $xd0 ) = ( $y + $dd0->[0], $x + $dd0->[1] );
	my( $yd1, $xd1 ) = ( $y + $dd1->[0], $x + $dd1->[1] );

	$val = $aContour->[$yd0][$xd0];
	return $val if $val != $NO_ELEV_VALUE;
	$val = $aContour->[$yd1][$xd1];
	return $val if $val != $NO_ELEV_VALUE;

#	my $ret = (isContourPoint([$yd0,$xd0],$aContour) && isContourPoint([$yd1,$xd1],$aContour));
#	print STDERR "\$y <", $y, ">  \$x <", $x, ">  \$i <", $i, ">\n" if $ret;  # _DEBUG_
	return $NO_ELEV_VALUE;
}

sub isContourPoint {
	my( $pt, $aContour ) = @_;
	my( $y, $x ) = @$pt;
#	print STDERR "[", $y, ",", $x, "]";  # _DEBUG_
	my $ret = ($aContour->[$y][$x] != $NO_ELEV_VALUE);
#	print STDERR " -> ", $ret, "\n";  # _DEBUG_
	return $ret;
}


sub ptag {
	my $pt = shift;
	return $pt->[0] .",". $pt->[1];
}

sub tagPt {
	my $ptag = shift;
	if( $ptag =~ /^(\d+),(\d+)$/ ){
		my $pt = [ $1, $2 ];
		return $pt;
	}else{
		die qq/tagP: cannot parse "$ptag"/;
	}
}

sub ptDist {
	my( $ptA, $ptB ) = @_;
	my( $dx, $dy ) = ( $ptB->[1] - $ptA->[1], $ptB->[0] - $ptA->[0] );
	return sqrt( $dx * $dx + $dy * $dy );
}


sub setEditor {
	my( $editor, $delay ) = @_;
	$EDITOR = $editor;
	$EDITOR->setPixelPaintDelay( $delay ) if $EDITOR && defined $delay;
}


#-------------------------------------------------------------------------------

sub sharpenContourLines {
	my( $aContour ) = @_;
	my( $wd, $hg ) = ( scalar(@{$aContour->[0]}), scalar(@$aContour) );
	for( my $y = 1; $y < $hg-1; ++$y ){
		for( my $x = 1; $x < $wd-1; ++$x ){
			next if $aContour->[$y][$x] == $NO_ELEV_VALUE;
#			print STDERR "\$y <", $y, ">  \$x <", $x, ">\n";  # _DEBUG_
			my( $aArea, $elev ) = ( [], $aContour->[$y][$x] );
			$aArea->[1][1] = $NO_ELEV_VALUE;
			my $ct = 0;
			foreach my $dd ( @DDXX ){
				my( $yd, $xd ) = @$dd;
				my $val = $aContour->[$y+$yd][$x+$xd];
				$aArea->[$yd+1][$xd+1] = $val;
#				++$ct if $val != $NO_ELEV_VALUE;
				++$ct if $val == $elev;
			}
#			print STDERR "\$ct <", $ct, ">\n";  # _DEBUG_
			if( $ct > 1 ){
				my $aShapes = connectedShapes( $aArea, [3,3], 0 );
#				print STDERR "\$aShapes <", scalar(@$aShapes), ">\n";  # _DEBUG_
#				foreach my $hShape ( @$aShapes ){  print STDERR "\$hShape <", join('|',keys %{$hShape->{_shape}}), ">\n";  }  # _DEBUG_
				if( scalar(@$aShapes) <= 1 ){
					$aContour->[$y][$x] = $NO_ELEV_VALUE;
#					print STDERR "\$aContour->[$y][$x]\n";  # _DEBUG_
					$EDITOR->updatePhotoPixel( $x, $y, '#FFFFFF' ) if $EDITOR;      # _DEBUG_
				}
			}
		}
	}
}


#-------------------------------------------------------------------------------

sub setShapeElevation {
	my( $self, $aContour ) = @_;
	my $hShape = $self->{_shape};
	my @points = values %$hShape;

#	print STDERR "\@points <", scalar(@points), ">\n";  # _DEBUG_
	foreach my $pt ( @points ){
		my( $y, $x ) = @$pt;
		if( $aContour->[$y][$x] != $NO_ELEV_VALUE ){
			$self->setDistElevation( $y,$x, $aContour, $aContour->[$y][$x] );
		}
	}
	foreach my $pt ( @points ){
		my( $y, $x ) = @$pt;
		if( $aContour->[$y][$x] == $NO_ELEV_VALUE ){
			my $ptag = ptag([$y,$x]);
			my $hInfo = $hShape->{$ptag};
			if( ref($hInfo) eq 'HASH' ){  # TODO !!! how can $hInfo == ARRAY happen?
				my( $elevA, $elevB, $distA, $distB ) = map {$hInfo->{$_}} qw( elevA elevB distA distB );
				$aContour->[$y][$x] = ($elevA * $distB + $elevB * $distA) / ($distA + $distB);
#				print STDERR "[", ($y-128), "][", ($x-128), "] -> ", $aContour->[$y][$x], "\n";  # _DEBUG_
			}
		}
	}
}

# Setzt zu einem bestimmten Contourpunkt und dessen Elevation f\xFCr alle Shape-erreichbaren Punkte die Werte
# distA - Distanz zum n\xE4chsten Contourpunkt
# elevA - Elevation des n\xE4chsten Contourpunkts
# distB - Distanz zum zweitn\xE4chsten Contourpunkt
# elevB - Elevation des zweitn\xE4chsten Contourpunkts
sub setDistElevation {
	my( $self, $y, $x, $aContour, $elev, $hReached ) = @_;
	my $hShape = $self->{_shape};
	my $ptag = "$y,$x";

	my $dist;
	if( $hReached ){
		# return falls Punkt nicht in Shape ist oder es sich um einen Contourpunkt handelt
		return unless $hShape->{$ptag} && $aContour->[$y][$x] == $NO_ELEV_VALUE;
		# return falls Punkt [in demselben Rekursionsbaum, d.h. vom selben Contourpunkt aus] bereits zuvor erreicht wurde
		return if $hReached->{$ptag};
		# Finde Minimaldistanz zu einem Contourpunkt f\xFCr die gegebene Elevation $elev
		$dist = $self->minDist( $y, $x, $elev );
	}else{
		$hReached = {};
		$dist = 0;
	}

	# Markiere Punkt als bereits erreicht
	$hReached->{$ptag} = 1;

	my $hInfo = $hShape->{$ptag};
	if( ref($hInfo) eq 'HASH' ){  # Punkt wurde von einem anderem Contourpunkt aus erreicht
		if( $dist < $hInfo->{distA} ){
			if( $elev == $hInfo->{elevA} ){
				$hInfo->{elevA} = $elev;
				$hInfo->{distA} = $dist;
			}else{
				$hInfo->{elevB} = $hInfo->{elevA};
				$hInfo->{distB} = $hInfo->{distA};
				$hInfo->{elevA} = $elev;
				$hInfo->{distA} = $dist;
			}
		}elsif( $dist < $hInfo->{distB} ){
			if( $elev == $hInfo->{elevA} ){
				# do nothing
			}else{
				$hInfo->{elevB} = $elev;
				$hInfo->{distB} = $dist;
			}
		}else{
			# do nothing
		}
	}else{  # Punkt wurde noch nie erreicht
		my $pt = $hShape->{$ptag};
		$hShape->{$ptag} = { ppos => $pt, elevA => $elev, elevB => $NO_ELEV_VALUE, distA => $dist, distB => 999999 };
	}

	# Fahre rekursiv fort f\xFCr alle direkten Umgebungspunkte
	foreach my $dd ( @DDXX ){
		my( $yd, $xd ) = ( $y + $dd->[0], $x + $dd->[1] );
		$self->setDistElevation( $yd, $xd, $aContour, $elev, $hReached );
	}
}

# Ermittelt zum Elevation-Niveau $elev die kleinstm\xF6gliche Entfernung zu einem Contourpunkt dieses Niveaus, indem aus den
# direkten Umgebungspunkten mit Niveau $elev derjenige mit Minimaldistanz zu einem Contourpunkt ermittelt wird. F\xFCr
# den aktuellen Punkt addieren wird dann +1 dazu.
sub minDist {
	my( $self, $y, $x, $elev ) = @_;
	my $hShape = $self->{_shape};
	my $dist = 999999;

	foreach my $dd ( @DDXX ){
		my( $yd, $xd ) = ( $y + $dd->[0], $x + $dd->[1] );
		my $ptag = "$yd,$xd";
		if( ref($hShape->{$ptag}) eq 'HASH' ){
			my $hInfo = $hShape->{$ptag};
			$dist = $hInfo->{distA} if $hInfo->{elevA} == $elev && $hInfo->{distA} < $dist;
			$dist = $hInfo->{distB} if $hInfo->{elevB} == $elev && $hInfo->{distB} < $dist;
		}
	}
#	print STDERR "\$dist <", $dist, ">\n";  # _DEBUG_
	return $dist + 1;
}




#--- shape from photo -------------------------------------------------------------------------

sub singleShapeFromPhoto {
	my( $y,$x, $photo, $aColor, $aTileSize, $hShape ) = @_;
	$aTileSize = [ $T_WIDTH, $T_HEIGHT ] if ! defined $aTileSize;
	$hShape = {} if ! $hShape;
	my $ptag = "$y,$x";
	return if exists $hShape->{$ptag};

	my( $red, $green, $blue ) = $photo->get( $x, $y );

#	my $dist = 40;
#	return unless abs($red - $aColor->[0]) < $dist && abs($green - $aColor->[1]) < $dist && abs($blue - $aColor->[2]) < $dist;

#	my $dist = 50;
#	return unless abs($red - $aColor->[0]) ** 2 + abs($green - $aColor->[1]) ** 2 + abs($blue - $aColor->[2]) ** 2 < $dist ** 2;

	my $hueS = hueFromRGB( @$aColor );
	my $hueX = hueFromRGB( $red, $green, $blue );
	my $dist = 30;
	return unless abs($hueS - $hueX) < $dist || ($hueS + 360 - $hueX) < $dist || ($hueX + 360 - $hueS) < $dist;

	$hShape->{$ptag} = [ $y, $x ];
#	print STDERR "remove [$y,$x]\n";
	foreach my $dd ( @DDXX ){
		my( $yd, $xd ) = ( $y + $dd->[0], $x + $dd->[1] );
#		print STDERR "\$aStream->[$yd][$xd] <", $aStream->[$yd][$xd], ">\n";  # _DEBUG_
		if( inArea($aTileSize,[$xd,$yd]) ){
			singleShapeFromPhoto( $yd,$xd, $photo, $aColor, $aTileSize, $hShape );
		}
	}
	return $hShape;
}

sub hsvFromRGB {
	my( $red, $green, $blue ) = @_;
	my( $hue, $sat, $val );
	my( $min, $max, $idMax ) = ( 255, 0, '' );

	( $max, $idMax ) = ( $red,   'R' ) if $red   >= $max;
	( $max, $idMax ) = ( $green, 'G' ) if $green >= $max;
	( $max, $idMax ) = ( $blue,  'B' ) if $blue  >= $max;
	$min = $red   if $red   <= $min;
	$min = $green if $green <= $min;
	$min = $blue  if $blue  <= $min;
	my $span = $max - $min;

	if( $min == $max ){
		$hue = 0;
	}elsif( $idMax eq 'R' ){
		$hue = 60 * ($green - $blue)/$span + 360;
		$hue -= 360 while $hue > 360;
	}elsif( $idMax eq 'G' ){
		$hue = 60 * ($blue - $red)/$span + 120;
	}elsif( $idMax eq 'B' ){
		$hue = 60 * ($red - $green)/$span + 240;
	}
	$sat = ($max == 0)? 0 : $span/$max;
	$val = $max;

	return ( $hue, $sat, $val );
}



sub rgbFromHSV {
	my( $hue, $sat, $val ) = @_;

	my $cx = $sat * $val;
	my $hx = $hue / 60;	
	my $h2 = 2 * ($hx/2 - int($hx/2));

	my $xx = $cx * (1 - abs($h2 - 1));
	my( $rx, $gx, $bx );	

	if( 0 <= $hx && $hx < 1 ){
		( $rx, $gx, $bx ) = ( $cx, $xx, 0 );
	}elsif( 1 <= $hx && $hx < 2 ){
		( $rx, $gx, $bx ) = ( $xx, $cx, 0 );
	}elsif( 2 <= $hx && $hx < 3 ){
		( $rx, $gx, $bx ) = ( 0, $cx, $xx );
	}elsif( 3 <= $hx && $hx < 4 ){
		( $rx, $gx, $bx ) = ( 0, $xx, $cx );
	}elsif( 4 <= $hx && $hx < 5 ){
		( $rx, $gx, $bx ) = ( $xx, 0, $cx );
	}elsif( 5 <= $hx && $hx < 6 ){
		( $rx, $gx, $bx ) = ( $cx, 0, $xx );
	}else{
		( $rx, $gx, $bx ) = ( 0, 0, 0 );
	}

	my $mx = $val - $cx;
	my( $red, $green, $blue ) = ( $rx + $mx, $gx + $mx, $bx + $mx );

	return ( $red, $green, $blue );
}




#--- stream data OLD ------------------------------------------------------------------------

sub connectedSegments {
	my( $aStream ) = @_;
	my @segments;
	my( $wd, $hg ) = ( scalar(@{$aStream->[0]}), scalar(@$aStream) );
	for( my $y = 0; $y < $hg; ++$y ){
		for( my $x = 0; $x < $wd; ++$x ){
			if( $aStream->[$y][$x] != $NO_ELEV_VALUE ){
				my $val = $aStream->[$y][$x];
				my $aSeg = singleSegment( $val, $y,$x, $aStream );
				push @segments, { value => $val, path => $aSeg };
#				return \@segments;  # _DEBUG_
			}
		}
	}
	return \@segments;
}

sub singleSegment {
	my( $val, $y,$x, $aStream ) = @_;
	my $aPath = followPath( $val, $y,$x, $aStream, 1 );
	my $aPt = pop @$aPath;
	my $aSegment = followPath( $val, @$aPt, $aStream, -1 );
	print "Segment: "; foreach my $pt ( @$aSegment ){  print "[$pt->[0],$pt->[1]] ";  }  print "\n\n";  # _DEBUG_
#	removeConnectedSet( $val, $y,$x, $aStream );
	removeSegmentPoints( $aStream, $aSegment );
	return $aSegment;
}


sub removeSegmentPoints {
	my( $aStream, $aSegment ) = @_;
	foreach my $pt ( @$aSegment ){
		my( $y, $x ) = @$pt;
		$aStream->[$y][$x] = $NO_ELEV_VALUE;
	}
}

sub removeConnectedSet {
	my( $val, $y,$x, $aStream ) = @_;
	$aStream->[$y][$x] = $NO_ELEV_VALUE;
#	print STDERR "remove [$y,$x]\n";
	foreach my $dd ( @DDXX ){
		my( $yd, $xd ) = ( $y + $dd->[0], $x + $dd->[1] );
		if( $aStream->[$yd][$xd] == $val ){
			removeConnectedSet( $val, $yd,$xd, $aStream );
		}
	}
}

sub followPath {
	my( $val, $y, $x, $aStream, $rot ) = @_;
	$rot = 1 if !defined $rot;
	my( $wd, $hg ) = ( scalar(@{$aStream->[0]}), scalar(@$aStream) );
	my( $iA, $iB, $yd, $xd ) = ( 0, (8-$rot) % 8 );  # 7 );
	my( $numReached, %reachedPoints ) = ( 0 );
	my @segment;
	my $flag = 1;
	while( $flag ){
		my $ptag = "$y,$x";
		$numReached = $reachedPoints{$ptag} ? ($numReached + 1) : 0;
		last if $numReached >= 1;

		push @segment, [$y,$x];
		$reachedPoints{$ptag} = 1;

#		print STDERR "[$y,$x] $iA ";  # _DEBUG_
		for( my $j = $iA; $j != $iB; $j+=$rot ){
			$j = $j % 8;
			( $yd, $xd ) = ( $y + $DDXX[$j][0], $x + $DDXX[$j][1] );
			if( ! inArea([$wd,$hg],[$xd,$yd]) ){
				$flag = 0;
				last;
			}
			if( $aStream->[$yd][$xd] == $val ){
				( $y, $x ) = ( $yd, $xd );
				$iA = ($j + 5*$rot) % 8;
				$iB = ($j + 4*$rot) % 8;
				last;
			}
			if( $j == $iB ){
				$flag = 0;
				last;
			}
		}
#		last if $#segment >= 50;
	}
#	print STDERR "\n----------\n";  # _DEBUG_
	return \@segment;
}

#sub inArea {
#	my( $wd, $hg, $x, $y ) = @_;
#	return ($x >= 0 && $x < $wd && $y >= 0 && $y < $hg);
#}

sub inArea {
	my( $aSize, $aPt, $margin ) = @_;
	$margin = 0 if ! defined $margin;
	my( $wd, $hg, $x, $y ) = ( $aSize->[0], $aSize->[1], $aPt->[0], $aPt->[1] );
	return ($x >= 0+$margin && $x < $wd-$margin && $y >= 0+$margin && $y < $hg-$margin);
}

sub segmentEndValue {
	my( $aContour, $aPath, $idx ) = @_;
	my( $wd, $hg ) = ( scalar(@{$aContour->[0]}), scalar(@$aContour) );

	my $val = $NO_ELEV_VALUE;
	my $pt = $aPath->[$idx];
	my( $y, $x ) = @$pt;
	for( my $j = 0; $j < 8; ++$j ){
		my( $yd, $xd ) = ( $y + $DDXX[$j][0], $x + $DDXX[$j][1] );
		if( inArea([$wd,$hg],[$xd,$yd]) && $aContour->[$yd][$xd] != $NO_ELEV_VALUE ){
			$val = $aContour->[$yd][$xd];
			last;
		}
	}

	return $val;
}


sub setStreamElevation {
	my( $aContour, $hSeg ) = @_;
	my( $val, $aPath ) = ( $hSeg->{value}, $hSeg->{path} );
	my( $valPrev, $idxPrev ) = ( segmentEndValue($aContour,$aPath,0), -1 );
	my $n = scalar( @$aPath );
	my $printFlag = 0;
	for( my $i = 0; $i < $n; ++$i ){
		my( $y, $x ) = @{$aPath->[$i]};
#		print "[$y,$x] ";
		if( $aContour->[$y][$x] != $NO_ELEV_VALUE || $i == $n-1 ){
			my $val = $aContour->[$y][$x];
			$val = segmentEndValue($aContour,$aPath,-1) if $i == $n-1 && $val == $NO_ELEV_VALUE;
			if( $val != $NO_ELEV_VALUE && $valPrev != $NO_ELEV_VALUE ){
				my $dd = ($val - $valPrev) / ($i - $idxPrev);
				for( my $j = $idxPrev+1; $j < $i; ++ $j ){
					my( $yy, $xx ) = @{$aPath->[$j]};
					$aContour->[$yy][$xx] = int( $valPrev + $dd * ($j - $idxPrev) + .5 );
					print "[$yy,$xx]:", $aContour->[$yy][$xx], " ";  $printFlag = 1;  # _DEBUG_
					$EDITOR->updatePhotoPixel( $xx, $yy, '#FF0000' ) if $EDITOR;      # _DEBUG_
				}
			}
			( $valPrev, $idxPrev ) = ( $val, $i );
		}
	}
	print "\n\n" if $printFlag;
}








1;

