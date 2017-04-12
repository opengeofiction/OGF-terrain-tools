package OGF::Geo::Measure;
use strict;
use warnings;
use Math::Trig;
use OGF::Const;
use OGF::Geo::Geometry;
use OGF::Data::Context;
use Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( geoAngle geoDist geoLength geoTriangle geoArea );


# Sathria  = 2524672 km2   ~ Algerien < S < Kasachstan / Sudan + Südsudan
# Kalm     =  673984 km2   ~ Frankreich mit Überseegebieten / Myanmar 



my $pi  = $OGF::PI;
my $deg = $OGF::DEG;
my $radAeq = $OGF::GEO_RAD_AEQ;
my $radPol = $OGF::GEO_RAD_POL;



#sub geoCosine {
#	my( $nodeA, $nodeB ) = @_;
#	my( $lonA, $latA, $lonB, $latB ) = ( $nodeA->{'lon'}, $nodeA->{'lat'}, $nodeB->{'lon'}, $nodeB->{'lat'} );
#	my( $zA, $rA ) = ( sin($latA*$deg), cos($latA*$deg) );
#	my( $xA, $yA ) = ( $rA * cos($lonA*$deg), $rA * sin($lonA*$deg) );
#	my( $zB, $rB ) = ( sin($latB*$deg), cos($latB*$deg) );
#	my( $xB, $yB ) = ( $rB * cos($lonB*$deg), $rB * sin($lonB*$deg) );
#	my $angCos = $xA * $xB + $yA * $yB + $zA * $zB;   # rad = 1
#	return $angCos;
#}
#

sub geoCosine {
	my( $nodeA, $nodeB ) = @_;
	my( $xA, $yA, $zA ) = spherePoint( $nodeA->{'lon'}, $nodeA->{'lat'}, 1 );
	my( $xB, $yB, $zB ) = spherePoint( $nodeB->{'lon'}, $nodeB->{'lat'}, 1 );
	my $angCos = $xA * $xB + $yA * $yB + $zA * $zB;   # rad = 1
	return $angCos;
}

sub geoAngle {
	my( $nodeA, $nodeB ) = @_;
	my $angle = Math::Trig::acos( geoCosine($nodeA,$nodeB) );
	return $angle;
}

sub surfaceAngle {
	my( $node, $nodeA, $nodeB ) = @_;
	my $cosA = geoCosine( $node, $nodeA );
	my $cosB = geoCosine( $node, $nodeB );
	my $cosC = geoCosine( $nodeA, $nodeB );
	my $distA = Math::Trig::acos( $cosA );
	my $distB = Math::Trig::acos( $cosB );
	my $ang = Math::Trig::acos( ($cosC - $cosA*$cosB) / (sin($distA) * sin($distB)) );
	return $ang;
}

sub surfaceOrientation {
	my( $node, $nodeA, $nodeB ) = @_;
	my( $x,  $y,  $z  ) = spherePoint( $node->{'lon'},  $node->{'lat'},  1 );
	my( $xA, $yA, $zA ) = spherePoint( $nodeA->{'lon'}, $nodeA->{'lat'}, 1 );
	my( $xB, $yB, $zB ) = spherePoint( $nodeB->{'lon'}, $nodeB->{'lat'}, 1 );
	my( $xN, $yN, $zN ) = ( $yA*$zB - $zA*$yB, $zA*$xB - $xA*$zB, $xA*$yB - $yA*$xB );
	my $cosN = $x * $xN + $y * $yN + $z * $zN;
	return ($cosN > 0)? 1 : -1;
}

sub geoDist {
	my( $nodeA, $nodeB ) = @_;
	my $geoDist = $radAeq * geoAngle($nodeA,$nodeB);
	return $geoDist;
}

sub geoLength {
	my( $way, $ctx ) = @_;
	$ctx = $way->{_context} if ! $ctx;
	my $geoLen = 0;
	my $imax = $#{$way->{'nodes'}};
	for( my $i = 0; $i < $imax; ++$i ){
		my( $nodeA, $nodeB ) = ( $ctx->{_Node}{$way->{'nodes'}[$i]}, $ctx->{_Node}{$way->{'nodes'}[$i+1]} ); 
		$geoLen += geoDist( $nodeA, $nodeB );
	}
	return $geoLen;
}

#sub geoTriangle {
#	my( $nodeA, $nodeB, $nodeC ) = @_;
#	$nodeC = {'lon' => 0, 'lat' => 90} if ! $nodeC;
#	my( $lonA,$latA, $lonB,$latB, $lonC,$latC ) = ( $nodeA->{'lon'},$nodeA->{'lat'}, $nodeB->{'lon'},$nodeB->{'lat'}, $nodeC->{'lon'},$nodeC->{'lat'} );
##	print STDERR "\$lonA <", $lonA, ">  \$latA <", $latA, ">  \$lonB <", $lonB, ">  \$latB <", $latB, ">\n";  # _DEBUG_
#
#	my $distA = geoAngle( $nodeB, $nodeC );
#	my $distB = geoAngle( $nodeC, $nodeA );
#	my $distC = geoAngle( $nodeA, $nodeB );
##	print STDERR "\$distA <", $distA, ">  \$distB <", $distB, ">  \$distC <", $distC, ">\n";  # _DEBUG_
#	return 0 if $distA == 0 || $distB == 0 || $distC == 0;
#
#	my $alpha = Math::Trig::acos( (cos($distA) - cos($distB)*cos($distC)) / (sin($distB) * sin($distC)) );
#	my $beta  = Math::Trig::acos( (cos($distB) - cos($distC)*cos($distA)) / (sin($distC) * sin($distA)) );
#	my $gamma = Math::Trig::acos( (cos($distC) - cos($distA)*cos($distB)) / (sin($distA) * sin($distB)) );
##	print STDERR "\$gamma <", $gamma, ">  \$alpha <", $alpha, ">  \$beta <", $beta, ">\n";  # _DEBUG_
#
#	my $exc = $alpha + $beta + $gamma - $pi;  # spherical excess
##	print STDERR "\$exc <", $exc, ">\n";  # _DEBUG_
#	return $exc;
#}
#

sub geoTriangle {
	my( $nodeA, $nodeB, $nodeC ) = @_;
#	print STDERR "\$nodeA <", $nodeA->{'id'}, ">  \$nodeB <", $nodeB->{'id'}, ">\n";  # _DEBUG_
	$nodeC = {'lon' => 0, 'lat' => 90} if ! $nodeC;
	my( $lonA,$latA, $lonB,$latB, $lonC,$latC ) = ( $nodeA->{'lon'},$nodeA->{'lat'}, $nodeB->{'lon'},$nodeB->{'lat'}, $nodeC->{'lon'},$nodeC->{'lat'} );
#	print STDERR "\$lonA <", $lonA, ">  \$latA <", $latA, ">  \$lonB <", $lonB, ">  \$latB <", $latB, ">  \$lonC <", $lonC, ">  \$latC <", $latC, ">\n";  # _DEBUG_

	my $cosA = geoCosine( $nodeB, $nodeC );
	my $cosB = geoCosine( $nodeC, $nodeA );
	my $cosC = geoCosine( $nodeA, $nodeB );

	my $distA = Math::Trig::acos( $cosA );
	my $distB = Math::Trig::acos( $cosB );
	my $distC = Math::Trig::acos( $cosC );
#	print STDERR "\$distA <", $distA, ">  \$distB <", $distB, ">  \$distC <", $distC, ">\n";  # _DEBUG_
	return 0 if $distA == 0 || $distB == 0 || $distC == 0;

#	checkCosineValues(
#		$cosA - $cosB * $cosC, sin($distB) * sin($distC),
#		$cosB - $cosC * $cosA, sin($distC) * sin($distA),
#		$cosC - $cosA * $cosB, sin($distA) * sin($distB),
#	);

	my $alpha = Math::Trig::acos( ($cosA - $cosB * $cosC) / (sin($distB) * sin($distC)) );
	my $beta  = Math::Trig::acos( ($cosB - $cosC * $cosA) / (sin($distC) * sin($distA)) );
	my $gamma = Math::Trig::acos( ($cosC - $cosA * $cosB) / (sin($distA) * sin($distB)) );
#	print STDERR "\$gamma <", $gamma, ">  \$alpha <", $alpha, ">  \$beta <", $beta, ">\n";  # _DEBUG_

	my $exc = $alpha + $beta + $gamma - $pi;  # spherical excess
	$exc = 0 if $exc =~ /i/;
#	print STDERR "\$exc <", $exc, ">\n";  # _DEBUG_
	return $exc;
}

sub checkCosineValues {
	for( my $i = 0; $i <= $#_; ++$i ){
		if( $_[$i] < -1 || $_[$i] > 1 ){
#			use OGF::Util; OGF::Util::printStackTrace();
			die qq/cosine error [$i] $_[$i]\n/;
		}
	}
}



#sub geoArea {
#	my( $obj, $ctx ) = @_;
#	$ctx = $obj->{_context} if ! $ctx;
#
#	my( $xMin, $yMin, $xMax, $yMax ) = @{ $obj->boundingRectangle($ctx) };
#	my $nodeC = { 'lon' => ($xMax + $xMin)/2, 'lat' => ($yMax + $yMin)/2 };
##	my $nodeC = { 'lon' => $xMin, 'lat' => $yMin };
##	my $nodeC = {'lon' => 0, 'lat' => 90};
#
#	if( $obj->class eq 'Way' ){
#		my $way = $obj;
#		if( $way->{'nodes'}[0] != $way->{'nodes'}[-1] ){
#			print STDERR qq/ERROR geoArea: way is not closed ($way->{id})\n/;
#			print STDERR qq/end point: $way->{nodes}[-1]\n/;
##			push @{$DRAW->{_draw}}, $way;
#			return 0;
#		}
#		my $geoArea = 0;
#		my $imax = $#{$way->{'nodes'}};
#		for( my $i = 0; $i < $imax; ++$i ){
#			my( $nodeA, $nodeB ) = ( $ctx->{_Node}{$way->{'nodes'}[$i]}, $ctx->{_Node}{$way->{'nodes'}[$i+1]} ); 
##			my $c0 = ($ptA->[0] < $ptB->[0])? 1 : -1;
#			my $c0 = surfaceOrientation( $nodeC, $nodeA, $nodeB );
#			$geoArea += $c0 * geoTriangle( $nodeA, $nodeB, $nodeC );
#		}
#		my $c1 = ($radAeq/1000) * ($radPol/1000);
#		return abs($geoArea * $c1);
#	}elsif( $obj->class eq 'Relation' ){
#		my $rel = $obj;
#		my $aRelOuter = $rel->closedWayComponents( 'outer' );
#		my $aRelInner = $rel->closedWayComponents( 'inner' );
#		my $area = 0;
#		map {$area += geoArea($_,$ctx)} @$aRelOuter;
#		map {$area -= geoArea($_,$ctx)} @$aRelInner;
#		return $area;
#	}else{
#		print STDERR qq/ERROR geoArea: Unsupported object type: /, $obj->class, "\n";
#		return 0;
#	}
#}

sub geoArea {
	my( $obj, $ctx ) = @_;
	$ctx = $obj->{_context} if ! $ctx;

	my $aRect = $obj->boundingRectangle($ctx);
	die qq/Cannot determine bounding rectangle\n/ if ! $aRect;
	my( $xMin, $yMin, $xMax, $yMax ) = @$aRect;
	my $lon0 = ($xMax + $xMin)/2;
	my $proj = OGF::View::Projection->new( "+proj=eck4 +lon_0=$lon0 +x_0=$lon0 +y_0=0" );
#	my $proj = OGF::View::Projection->new( "+proj=sinu +lon_0=0=0" );

	if( $obj->class eq 'Way' ){
		my $way = $obj;
		if( $way->{'nodes'}[0] != $way->{'nodes'}[-1] ){
			print STDERR qq/ERROR geoArea: way is not closed ($way->{id})\n/;
			print STDERR qq/end point: $way->{nodes}[-1]\n/;
#			push @{$DRAW->{_draw}}, $way;
			die 'error at node ', $way->{nodes}[-1], "\n";
		}
		my $geoArea = 0;
		my $imax = $#{$way->{'nodes'}};
		for( my $i = 0; $i < $imax; ++$i ){
			my( $nodeA, $nodeB ) = ( $ctx->{_Node}{$way->{'nodes'}[$i]}, $ctx->{_Node}{$way->{'nodes'}[$i+1]} ); 
			my( $xA, $yA ) = $proj->geo2cnv( $nodeA->{'lon'}, $nodeA->{'lat'} );
			my( $xB, $yB ) = $proj->geo2cnv( $nodeB->{'lon'}, $nodeB->{'lat'} );
			$geoArea += ($xA * $yB - $yA * $xB);
		}
		return abs($geoArea / 2_000_000);
	}elsif( $obj->class eq 'Relation' ){
		my $rel = $obj;
		my $aRelOuter = $rel->closedWayComponents( 'outer' );
		if( ! @$aRelOuter ){
			die "no member way with role=outer\n";
		}
		my $aRelInner = $rel->closedWayComponents( 'inner' );
		my $area = 0;
		map {$area += geoArea($_,$ctx)} @$aRelOuter;
		map {$area -= geoArea($_,$ctx)} @$aRelInner;
		return $area;
	}else{
		print STDERR qq/ERROR geoArea: Unsupported object type: /, $obj->class, "\n";
		return 0;
	}
}

sub geo2cnv_sinusoidal {
	my( $lon, $lat ) = @_;
	my $x = $lon * ($OGF::PI * 6367000 / 180) * cos($lat * $OGF::PI / 180);
	my $y = $lat * $OGF::PI * 6367000 / 180;
	return ( $x, $y );
}

sub spherePoint {
	my( $lon, $lat, $rad ) = @_;
	$rad = $radAeq if ! $rad;
	my( $z, $r ) = ( sin($lat*$deg), cos($lat*$deg) );
	my( $x, $y ) = ( $r * cos($lon*$deg), $r * sin($lon*$deg) );
	return ( $x*$rad, $y*$rad, $z*$rad );
}

sub sphereLonlat {
	my( $x, $y, $z, $rad ) = @_;
	$rad = sqrt($x*$x + $y*$y + $z*$z) if ! $rad;
	my $lat = Math::Trig::asin( $z / $rad ) / $deg;
	my( $angle, $sign ) = OGF::Geo::Geometry::angleInfo( [0,0], [$rad,0], [$x,$y] );
	my $lon = $sign * $angle / $deg;
	return ( $lon, $lat );
}


1;




#sub geoTriangle {
#	my( $nodeA, $nodeB ) = @_;
#	my( $lonA, $latA, $lonB, $latB ) = ( $nodeA->{'lon'}, $nodeA->{'lat'}, $nodeB->{'lon'}, $nodeB->{'lat'} );
##	print STDERR "\$lonA <", $lonA, ">  \$latA <", $latA, ">  \$lonB <", $lonB, ">  \$latB <", $latB, ">\n";  # _DEBUG_
#	my $ptC = [ 0, $pi/2 ];
#
#	my $gamma = abs($lonB-$lonA) * $deg;
#	return 0 if $gamma == 0;
#
##	my $distA = geoAngle( $ptB, $ptC );
##	my $distB = geoAngle( $ptC, $ptA );
#	my $distA = (90-$latA) * $deg;
#	my $distB = (90-$latB) * $deg;
#	my $distC = geoAngle( $nodeA, $nodeB );
##	print STDERR "\$distA <", $distA, ">  \$distB <", $distB, ">  \$distC <", $distC, ">\n";  # _DEBUG_
#	return 0 if $distC == 0;
#
##	my $c0 = ($distC > 0 )? (sin($gamma) / sin($distC)) : 0;
##	print STDERR "\$c0 <", $c0, ">  sin(\$distA) * \$c0 <", (sin($distA) * $c0), ">  sin(\$distB) * \$c0 <", (sin($distB) * $c0), ">\n";  # _DEBUG_
##	my $alpha = Math::Trig::asin( sin($distA) * $c0 );
##	my $beta  = Math::Trig::asin( sin($distB) * $c0 );
#
#	my $alpha = Math::Trig::acos( (cos($distA) - cos($distB)*cos($distC)) / (sin($distB) * sin($distC)) );
#	my $beta  = Math::Trig::acos( (cos($distB) - cos($distC)*cos($distA)) / (sin($distC) * sin($distA)) );
##	print STDERR "\$gamma <", $gamma, ">  \$alpha <", $alpha, ">  \$beta <", $beta, ">\n";  # _DEBUG_
#
#	my $exc = $alpha + $beta + $gamma - $pi;  # spherical excess
##	print STDERR "\$exc <", $exc, ">\n";  # _DEBUG_
#	return $exc;
#}


