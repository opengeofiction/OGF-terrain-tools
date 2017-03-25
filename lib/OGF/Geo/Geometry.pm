package OGF::Geo::Geometry;
use strict;
use warnings;
use POSIX;
use OGF::Const;

my $pi  = $OGF::PI;
my $deg = $OGF::DEG;



sub ptag {  return "". $_[0][0] ."|". $_[0][1];  }

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

sub rectUnion {
	my( $rA, $rB ) = @_;
	my( $x0, $y0, $x1, $y1 ) = ( min($rA->[0],$rB->[0]), min($rA->[1],$rB->[1]), max($rA->[2],$rB->[2]), max($rA->[3],$rB->[3]) );
	return [$x0, $y0, $x1, $y1];
}

sub rectOverlap {
	my( $rA, $rB, $margin ) = @_;
	my $mg = (defined $margin)? $margin : 0;
#	if( $rB->[2] >= $rA->[0] && $rB->[3] >= $rA->[1] && $rA->[2] >= $rB->[0] && $rA->[3] >= $rB->[1] ){
	my( $x0, $y0, $x1, $y1 ) = ( max($rA->[0],$rB->[0])-$mg, max($rA->[1],$rB->[1])-$mg, min($rA->[2],$rB->[2])+$mg, min($rA->[3],$rB->[3])+$mg );
	return ($x0 <= $x1 && $y0 <= $y1)? [$x0, $y0, $x1, $y1] : undef;
}

sub rectArea {
	my( $rA ) = @_;
	my $val = ($rA->[2] - $rA->[0]) * ($rA->[3] - $rA->[1]);
	return $val;
}

sub rectContains {
	my( $rA, $pt, $dd ) = @_;
	$dd = 0 if !defined $dd;
	my $ret = ($pt->[0] >= $rA->[0]-$dd && $pt->[0] <= $rA->[2]+$dd && $pt->[1] >= $rA->[1]-$dd && $pt->[1] <= $rA->[3]+$dd);
	return $ret;
}

sub lineIntersect {
	my( $xA0, $yA0, $xA1, $yA1 );
	my( $xB0, $yB0, $xB1, $yB1 );

	if( scalar(@_) == 4 ){
		( $xA0, $yA0, $xA1, $yA1 ) = ( $_[0][0], $_[0][1], $_[1][0], $_[1][1] );
		( $xB0, $yB0, $xB1, $yB1 ) = ( $_[2][0], $_[2][1], $_[3][0], $_[3][1] );
	}else{
		( $xA0, $yA0, $xA1, $yA1 ) = @{$_[0]};
		( $xB0, $yB0, $xB1, $yB1 ) = @{$_[1]};
	}

	my $cAN = ($xB1 - $xB0) * ($yA0 - $yB0) - ($yB1 - $yB0) * ($xA0 - $xB0);
	my $cAD = ($yB1 - $yB0) * ($xA1 - $xA0) - ($xB1 - $xB0) * ($yA1 - $yA0);
	my $cBN = ($xA1 - $xA0) * ($yA0 - $yB0) - ($yA1 - $yA0) * ($xA0 - $xB0);
	my $cBD = ($yB1 - $yB0) * ($xA1 - $xA0) - ($xB1 - $xB0) * ($yA1 - $yA0);

	return undef if $cAD == 0 || $cBD == 0;

	my( $cA, $cB ) = ( $cAN / $cAD, $cBN / $cBD );
	my( $xI, $yI ) = ( $xA0 + $cA * ($xA1 - $xA0), $yA0 + $cA * ($yA1 - $yA0) );
	return [ $xI, $yI, $cA, $cB ];
}

#print STDERR join('|', @{ lineIntersect([0,0],[1,1],[1,0],[0,1]) }), "\n";
#print STDERR join('|', @{ lineIntersect([2,0],[2,1],[0,2],[1,2]) }), "\n";
#print STDERR join('|', @{ lineIntersect([2,1],[2,0],[1,2],[0,2]) }), "\n";
#print STDERR join('|', @{ lineIntersect([0,0],[2,2],[0,2],[1,1]) }), "\n";
#print STDERR join('|', @{ lineIntersect([0,0],[2,2],[1,1],[1,1]) }), "\n";
#exit;

sub lineDistance {
	my( $xA0, $yA0, $xA1, $yA1 ) = ( $_[0][0], $_[0][1], $_[1][0], $_[1][1] );
	my( $xB0, $yB0, $xB1, $yB1 ) = ( $_[2][0], $_[2][1] );

#	($xB1 - $xB0) * ($xA1 - $xA0) + ($yB1 - $yB0) * ($yA1 - $yA0) = 0;
	if( $xA0 != $xA1 ){
#		( $xB1, $yB1 ) = ( ($yB0 - 1) * ($yA1 - $yA0) / ($xA1 - $xA0) + $xB0, 1 );
		( $xB1, $yB1 ) = ( ($yA1 - $yA0) / ($xA1 - $xA0) + $xB0, $yB0 - 1 );
	}elsif( $yA0 != $yA1 ){
#		( $xB1, $yB1 ) = ( 1, ($xB0 - 1) * ($xA1 - $xA0) / ($yA1 - $yA0) + $yB0 );
		( $xB1, $yB1 ) = ( $xB0 - 1, ($xA1 - $xA0) / ($yA1 - $yA0) + $yB0 );
	}else{
		return dist( [$xA0,$yA0], [$xB0,$yB0] );
	}
#	print STDERR "\$xB1 <", $xB1, ">  \$yB1 <", $yB1, ">\n";  # _DEBUG_

	my $aI = lineIntersect( [$xA0,$yA0], [$xA1,$yA1], [$xB0,$yB0], [$xB1,$yB1] );
	my $dist = dist( [$aI->[0],$aI->[1]], [$xB0,$yB0]);

	return $dist;
}

sub segmentDistance {
	my( $xA0, $yA0, $xA1, $yA1 ) = ( $_[0][0], $_[0][1], $_[1][0], $_[1][1] );
	my( $xB0, $yB0, $xB1, $yB1 ) = ( $_[2][0], $_[2][1] );

	my( $dist, $dx, $dy );
	if( $xA0 != $xA1 ){
		( $xB1, $yB1 ) = ( ($yA1 - $yA0) / ($xA1 - $xA0) + $xB0, $yB0 - 1 );
	}elsif( $yA0 != $yA1 ){
		( $xB1, $yB1 ) = ( $xB0 - 1, ($xA1 - $xA0) / ($yA1 - $yA0) + $yB0 );
	}else{
		$dist = dist( [$xA0,$yA0], [$xB0,$yB0] );
		( $dx, $dy ) = ( $xA0 - $xB0, $yA0 - $yB0 );
		return wantarray ? ($dist, $dx, $dy) : $dist;
	}

	my $aI = lineIntersect( [$xA0,$yA0], [$xA1,$yA1], [$xB0,$yB0], [$xB1,$yB1] );
	my( $xC, $yC, $cA ) = @$aI;
	if( $cA <= 0 ){
		$dist = dist( [$xA0,$yA0], [$xB0,$yB0] );
		( $dx, $dy ) = ( $xA0 - $xB0, $yA0 - $yB0 );
	}elsif( $cA >= 1 ){
		$dist = dist( [$xA1,$yA1], [$xB0,$yB0] );
		( $dx, $dy ) = ( $xA1 - $xB0, $yA1 - $yB0 ); 
	}else{
		$dist = dist( [$xC,$yC], [$xB0,$yB0] );
		( $dx, $dy ) = ( $xC - $xB0, $yC - $yB0 );
	}

	return wantarray ? ($dist, $dx, $dy) : $dist;
}

sub linePointDist {
	my( $aPoints, $pt ) = @_;
	my( $minDist, $idx ) = ( 9999999 );
	my $n = $#{$aPoints} - 1;
	for( my $i = 0; $i <= $n; ++$i ){
		my $dd = segmentDistance( $aPoints->[$i], $aPoints->[$i+1], $pt );
		( $minDist, $idx ) = ( $dd, $i ) if $dd < $minDist;
	}
	return wantarray ? ($minDist,$idx) : $minDist;
}



#print STDERR lineDistance([0,0],[2,2],[0,2]), "\n";



sub segmentIntersect {
	my $aInter = lineIntersect( @_ );
	if( $aInter ){
		my(  $xI, $yI, $cA, $cB ) = @$aInter;
		$aInter = undef unless $cA >= 0 && $cA <= 1 && $cB >= 0 && $cB <= 1;
	}
	return $aInter;
}

#	my $cAN = ($x4 - $x3) * ($y1 - $y3) - ($y4 - $y3) * ($x1 - $x3);
#	my $cAD = ($y4 - $y3) * ($x2 - $x1) - ($x4 - $x3) * ($y2 - $y1);
#	my $cBN = ($x2 - $x1) * ($y1 - $y3) - ($y2 - $y1) * ($x1 - $x3);
#	my $cBD = ($y4 - $y3) * ($x2 - $x1) - ($x4 - $x3) * ($y2 - $y1);

sub dist {
	my( $pt0, $pt1 ) = @_;
	my( $x0, $y0, $x1, $y1 ) = ( $pt0->[0], $pt0->[1], $pt1->[0], $pt1->[1] );
#	print STDERR "\$x0 <", $x0, ">  \$y0 <", $y0, ">  \$x1 <", $x1, ">  \$y1 <", $y1, ">\n";  # _DEBUG_
	my $dist = sqrt( ($x0 - $x1)*($x0 - $x1) + ($y0 - $y1)*($y0 - $y1) );
	return $dist;
}

sub rdist {
	my( $pt0, $pt1 ) = @_;
	my( $x0, $y0, $x1, $y1 ) = ( $pt0->[0], $pt0->[1], $pt1->[0], $pt1->[1] );
	return max( abs($x0 - $x1), abs($y0 - $y1) );
}

sub angleInfo {
	require Math::Trig;
	my( $pt, $ptA, $ptB ) = @_;
	my( $xA, $yA, $xB, $yB );
	if( defined $ptB ){
		( $xA, $yA ) = ( $ptA->[0] - $pt->[0], $ptA->[1] - $pt->[1] );
		( $xB, $yB ) = ( $ptB->[0] - $pt->[0], $ptB->[1] - $pt->[1] );
	}else{
		( $xA, $yA ) = ( 1, 0 );
		( $xB, $yB ) = ( $ptA->[0] - $pt->[0], $ptA->[1] - $pt->[1] );
	}

	my $distProd = dist([0,0],[$xA,$yA]) * dist([0,0],[$xB,$yB]);
#	my $angSin = ($xA * $yB - $yA * $xB) / $distProd;
	my $sign = (($xA * $yB - $yA * $xB) > 0)? 1 : -1;   # > oder >= macht den Unterschied bei Randpunkten
	my $angCos = ($xA * $xB + $yA * $yB) / $distProd;
	my $angle = Math::Trig::acos( $angCos );

	return ( $angle, $sign, [$xA,$yA], [$xB,$yB] );
}

sub rotationMatrix {
	my( $angle ) = @_;
	return [ cos($angle), -sin($angle), sin($angle), cos($angle) ];
}

sub matrixMult {
	my( $mat, $vec ) = @_;
	return [ $mat->[0]*$vec->[0] + $mat->[1]*$vec->[1], $mat->[2]*$vec->[0] + $mat->[3]*$vec->[1] ]
}

sub vecToLength {
	my( $vec, $len ) = @_;
	my $dd = dist( [0,0], $vec );
	return $vec if $dd == 0;
	return [ $vec->[0]/$dd * $len, $vec->[1]/$dd * $len ];
}

sub product {
	my $type = shift;
	my( $xA, $yA, $xB, $yB );
	if( scalar(@_) == 4 ){
		( $xA, $yA, $xB, $yB ) = ( $_[1][0]-$_[0][0],$_[1][1]-$_[0][1], $_[3][0]-$_[2][0],$_[3][1]-$_[2][1] );
	}else{
		( $xA, $yA, $xB, $yB ) = ( $_[0][0],$_[0][1], $_[1][0],$_[1][1] );
	}
	my $ret = ($type =~ /^sin/)? ($xA * $yB - $yA * $xB) : ($xA * $xB + $yA * $yB);
	if( $type =~ /-norm/ ){
		my $distProd = dist([0,0],[$xA,$yA]) * dist([0,0],[$xB,$yB]);
		$ret = $ret / $distProd;
	}
	return $ret;
}

sub scalarProduct {
	return product( 'cos', @_ );
}

sub vectorProduct {
	return product( 'sin', @_ );
}


#-------------------------------------------------------------------------------

sub polygonArea {
	my( $aSelf ) = @_;
	my $sum = 0;
	my $n = $#{$aSelf};
	for( my $i = 0; $i <= $n-1; ++$i ){
		$sum += ($aSelf->[$i][0] * $aSelf->[$i+1][1] - $aSelf->[$i+1][0] * $aSelf->[$i][1]);
	}
	return $sum / 2;
}

sub polygonCentroid {
	my( $aSelf ) = @_;
	my( $X, $Y ) = ( 0, 0 );
	my $A6 = polygonArea( $aSelf ) * 6;
	my $n = $#{$aSelf};
	for( my $i = 0; $i <= $n-1; ++$i ){
		my $f_xy = ($aSelf->[$i][0] * $aSelf->[$i+1][1] - $aSelf->[$i+1][0] * $aSelf->[$i][1]);
		$X += ($aSelf->[$i][0] + $aSelf->[$i+1][0]) * $f_xy;
		$Y += ($aSelf->[$i][1] + $aSelf->[$i+1][1]) * $f_xy;
	}
	return ( $X/$A6, $Y/$A6 );
}




#-------------------------------------------------------------------------------


sub boundingRectangle {
	my( $aSelf ) = @_;
#	use ARS::Util::Exception; ARS::Util::Exception::printStackTrace();
	my( $xMin, $yMin, $xMax, $yMax ) = ( $aSelf->[0][0],$aSelf->[0][1], $aSelf->[0][0], $aSelf->[0][1] );
	foreach my $pt ( @{$aSelf} ){
		my( $x, $y ) = @$pt;
		$xMin = $x if $x < $xMin;
		$xMax = $x if $x > $xMax;
		$yMin = $y if $y < $yMin;
		$yMax = $y if $y > $yMax;
	}
	return [ $xMin, $yMin, $xMax, $yMax ];
}

sub array_intersect {
	my( $aSelf, $aOther, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;

	my( $rA, $rB ) = $hOpt->{'rect'} ? @{$hOpt->{'rect'}} : ( boundingRectangle($aSelf), boundingRectangle($aOther) );
	return () unless rectOverlap( $rA, $rB, 5 );
#	my( $wA, $wB, $fSwap ) = (rectArea($rB) < rectArea($rA))? ($self,$other,0) : ($other,$self,1);

	my( $iS, $iE, $jS, $jE ) = ( 0, $#{$aSelf}, 0, $#{$aOther} );
	if( $hOpt->{'limit'} ){
		( $iS, $iE ) = ( $hOpt->{'limit'}[0], $hOpt->{'limit'}[1] );
		( $jS, $jE ) = ( $hOpt->{'limit'}[2], $hOpt->{'limit'}[3] ) if $#{$hOpt->{'limit'}} == 3;
	}
	my $shiftRange = $hOpt->{'range'} ? $hOpt->{'range'} : undef;

	my @inter;

	for( my $i = $iS; $i <= $iE-1; ++$i ){
#		print STDERR "  \$i = ", $i, "\n" if $i % 100 == 0 && $i > 0;  # _DEBUG_
		my( $pt0, $pt1 ) = ( $aSelf->[$i], $aSelf->[$i+1] );
		my $bd = [ min($pt0->[0],$pt1->[0]), min($pt0->[1],$pt1->[1]), max($pt0->[0],$pt1->[0]), max($pt0->[1],$pt1->[1]) ];
		next if ! rectOverlap( $bd, $rB );

#		my $m = $#{$other->{_ccnv}} - 1;
		( $jS, $jE ) = ( $i+2, min($i+$shiftRange,$#{$aOther}) ) if $shiftRange;
		for( my $j = $jS; $j <= $jE-1; ++$j ){
			my( $ptB0, $ptB1 ) = ( $aOther->[$j], $aOther->[$j+1] );
#			print STDERR "\$i=", $i, " (", $iE, ")  \$j=", $j, " (", $jE, ")  \$ptB0 <", join('|',@$ptB0), ">  \$ptB1 <", join('|',@$ptB1), ">\n";  # _DEBUG_
			my $aI = lineIntersect( $pt0, $pt1, $ptB0, $ptB1 );
			next if ! $aI;

			my( $x, $y, $cA, $cB ) = @$aI;
#			print STDERR "[$i,$j] \$x <", $x, ">  \$y <", $y, ">  \$cA <", $cA, ">  \$cB <", $cB, ">\n" if $cA > -0.1 && $cA < 1.1 && $cB > -0.1 && $cB < 1.1;  # _DEBUG_
			my( $i1, $j1 );

			if( $cA >= 0 && $cA < 1 ){
				$i1 = $i;
			}
			if( $cB >= 0 && $cB < 1 ){
				$j1 = $j;
			}
			if( $hOpt->{'outside'} ){
				my( $dd, $ptI ) = ( $hOpt->{'outside'}, [$x,$y] );
				if( $i == 0 && $cA < 0 && dist($ptI,$pt0) <= $dd ){
					$i1 = -1;
				}elsif( $i == $iE-1 && $cA >= 1 && dist($pt1,$ptI) <= $dd ){
					$i1 = $iE;
				}
				if( $j == 0 && $cB < 0 && dist($ptI,$ptB0) <= $dd ){
					$j1 = -1;
				}elsif( $j == $jE-1 && $cB >= 1 && dist($ptB1,$ptI) <= $dd ){
					$j1 = $jE;
				}
			}
			if( defined($i1) && defined($j1) ){
#				print STDERR "[$i,$j] \$x <", $x, ">  \$y <", $y, ">  \$cA <", $cA, ">  \$cB <", $cB, ">\n";  # _DEBUG_
				my $rInfo = $hOpt->{'infoAll'} ? {
					_point  => [$x,$y],
					_idx    => $i1,
					_idx2   => $j1,
					_ratio  => $cA,
					_ratio2 => $cB,
				} : [ [$x,$y], $i1, $j1 ];
				push @inter, $rInfo;
			}
		}
	}
#	print STDERR "A \@inter <", join('|',@inter), ">\n";  # _DEBUG_
#	if( $fSwap ){
#		@inter = map {[$_->[0],$_->[2],$_->[1]]} @inter;
#	}

#	$self->{_draw}->getCanvas()->after( 1000, sub{$self->{_draw}->drawMagnifiedPoints( [map {$_->[0]} @inter], '#FF0000' )} );
#	use Data::Dumper; local $Data::Dumper::Indent = 0; print STDERR Data::Dumper->Dump( [\@inter], ['inter'] ), "\n";
#	print STDERR "\@inter <", join('|',@inter), ">\n";  # _DEBUG_
	return @inter;
}

sub array_insert {
	my( $aSelf, @pointInfo ) = @_;

	my $hOpt = (ref($pointInfo[0]) eq 'HASH')? (shift @pointInfo) : {};
	my $cutOpt = $hOpt->{'cut'} ? $hOpt->{'cut'} : 0;
#	use Data::Dumper; local $Data::Dumper::Indent = 0; print STDERR Data::Dumper->Dump( [\@pointInfo], ['pointInfo'] ), "\n";

	my( @points );
	my( $j, $n ) = ( 0, $#{$aSelf} );
	my( $c0, $c1 ) = ( -1, $n+1 );
	$c0 = $pointInfo[0][1]  if $cutOpt && $pointInfo[0][1]  < $cutOpt;
	$c1 = $pointInfo[-1][1] if $cutOpt && $pointInfo[-1][1] > $n-$cutOpt;

	for( my $i = -1; $i <= $n; ++$i ){
		if( $i >= 0 && $i > $c0 && $i < $c1 ){
			push @points, $aSelf->[$i];
		}
		while( $j <= $#pointInfo && $pointInfo[$j][1] == $i ){
			my $pt = $pointInfo[$j][0];
			push @points, $pt;
			++$j;
		}
	}

	@$aSelf = @points;
}

sub pointInside {
	my( $aSelf, $pt, $hOpt ) = @_;
#	return 0 unless rectContains( $self->{_bounds}, $pt );
	my $minDist = ($hOpt && $hOpt->{'minInsideDist'})? 2 ** 32 : undef;

	my( $x, $y ) = @$pt;
#	print STDERR "\$aSelf <", $aSelf, ">\n";  # _DEBUG_
	my( $angle, $xP, $yP ) = ( 0, $aSelf->[-1][0] - $x, $aSelf->[-1][1] - $y );

	my $num = scalar( @$aSelf );
	for( my $i = 0; $i < $num; ++$i ){
		my( $xC, $yC ) = ( $aSelf->[$i][0] - $x, $aSelf->[$i][1] - $y );
		return 'BOUNDARY_ERROR' if $xC == 0 && $yC == 0;

		my( $angleAdd, $sign ) = angleInfo( [0,0], [$xP,$yP], [$xC,$yC] );
		$angle += $angleAdd * $sign;
		( $xP, $yP ) = ( $xC, $yC );

		if( $minDist ){
			my $dist = dist( $pt, $aSelf->[$i] );
			$minDist = $dist if $dist < $minDist;
		}
	}
#	print STDERR "\$angle <", $angle, ">";  # _DEBUG_

#	my $ret = (abs($angle) > 1)? 1 : 0;
	my $ret = POSIX::floor( $angle/(2 * $pi) + .5 );
	# positiv = Uhrzeigersinn. Dies ist genau andersherum als normalerweise in der Mathematik, was daran liegt,
	# dass die Pixelkoordinaten gegen\xFCber dem math. Koordinatensystem an der x-Achse gespiegelt sind.

#	print STDERR " --> ", $ret, "\n";  # _DEBUG_
	if( defined $minDist ){
		return ( $ret, $minDist );
	}else{
		return $ret;
	}
}

sub array_orientation {
	my( $aSelf, $maxCount ) = @_;
	$maxCount = 999_999_999 if ! $maxCount;
	my $rect = boundingRectangle( $aSelf );
	print STDERR "\@\$rect <", join('|',@$rect), ">\n";  # _DEBUG_
	my( $xMin, $yMin, $xMax, $yMax ) = @$rect;
	my( $ori, $ct ) = ( 0, 0 );
	while( $ori == 0 ){
		my( $x, $y ) = ( $xMin + rand($xMax-$xMin), $yMin + rand($yMax-$yMin) );
		$ori = pointInside( $aSelf, [$x,$y] );
		last if ++$ct > $maxCount;
	}
	return $ori;
}


#-------------------------------------------------------------------------------


sub circlePoints {
	my( $pt, $ptA, $ptB, $radius, $num, $pxSize ) = @_;
#	print STDERR "circlePoints( $pt, $ptA, $ptB, $radius, $num, $pxSize )\n";  # _DEBUG_
	my( $angle, $sgn, $ddA, $ddB ) = angleInfo( $pt, $ptA, $ptB ); 

    my $dd = vecToLength(	$ddA, $radius/$pxSize );
    my $mt1 = rotationMatrix( ($pi/2 - $angle/2) * -$sgn );
    my $mt2 = rotationMatrix( $pi/$num * -$sgn );

	my @points;
    $dd = matrixMult( $mt1, $dd );
    push @points, [ $pt->[0]+$dd->[0], $pt->[1]+$dd->[1] ];
    foreach my $i ( 1..$num ){
        $dd = matrixMult( $mt2, $dd );
        push @points, [ $pt->[0]+$dd->[0], $pt->[1]+$dd->[1] ];
    }

	return @points;
}


sub linePoints {
	my( $ptA, $ptB ) = @_;
	my @linePts;
	my( $xA, $yA, $xB, $yB ) = ( @{ptInt($ptA)}, @{ptInt($ptB)} );
	my( $dx, $dy ) = ( $xB - $xA, $yB - $yA );
	return @linePts if $dx == 0 && $dy == 0;

	if( abs($dx) >= abs($dy) ){
		my $dd = ($xB > $xA)? 1 : -1;
		for( my $x = $xA+$dd; $x*$dd < $xB*$dd; $x+=$dd ){
			my $y = POSIX::floor($yA + ($x-$xA) * $dy/$dx + .5);
			push @linePts, [$x,$y];
		}
	}else{
		my $dd = ($yB > $yA)? 1 : -1;
		for( my $y = $yA+$dd; $y*$dd < $yB*$dd; $y+=$dd ){
			my $x = POSIX::floor($xA + ($y-$yA) * $dx/$dy + .5);
			push @linePts, [$x,$y];
		}
	}

	if( $#linePts >= 0 ){
        foreach my $Z ( 2..4 ){
            if( defined $ptA->[$Z] && defined $ptB->[$Z] ){
                my( $zA, $zB ) = ( $ptA->[$Z], $ptB->[$Z] );
                my $dZ = ($zB - $zA) / ($#linePts + 1);
                for( my $i = 0; $i <= $#linePts; ++$i ){
                    $linePts[$i]->[$Z] = $zA + ($i+1) * $dZ;
                }
            }
        }
	}

	return @linePts;
}

sub ptInt {
	my( $x, $y ) = @{$_[0]};
	return [ POSIX::floor($x + .5), POSIX::floor($y + .5) ];
}



1;

