package OGF::View::Projection;
use strict;
use warnings;
use Geo::Proj4;
use UTAN::Util qw( exception );
use OGF::Const;



sub new {
	my( $pkg, $dsc, $hTransf ) = @_;
	$hTransf = {'X' => [ @{$hTransf->{'X'}} ], 'Y' => [ @{$hTransf->{'Y'}} ]} if $hTransf;  # clone transform to prevent in-place modifications

	my $self = {
		_descriptor => $dsc,
		_transform  => $hTransf,
		_cnv2geo    => undef,
		_geo2cnv    => undef,
	};
	bless $self, $pkg;
	$self->initConversion( $dsc, $hTransf );

	return $self;
}

sub initConversion {
	my( $self, $dsc, $hTransf ) = @_;

	my $proj;
	if( $dsc ){
		require Geo::Proj4;
		$proj = Geo::Proj4->new( $dsc );
	}

	my( $cX, $cY, $tX, $tY );
	if( $hTransf ){
		my( $x0, $X0, $x1, $X1 ) = @{$hTransf->{'X'}};
		my( $y0, $Y0, $y1, $Y1 ) = @{$hTransf->{'Y'}};
		$cX = ($X1 - $X0) / ($x1 - $x0);
		$cY = ($Y1 - $Y0) / ($y1 - $y0);
		$tX = ($x1*$X0 - $x0*$X1) / ($x1 - $x0);
		$tY = ($y1*$Y0 - $y0*$Y1) / ($y1 - $y0);
#		$self->{_worldArea} = [ 0,0, abs($X1-$X0), abs($Y1-$Y0) ];
		$self->{_worldArea} = [ 0,0, $X1+$X0, $Y1+$Y0 ];
	}else{
		( $cX, $cY, $tX, $tY ) = ( 1, 1, 0, 0 );
		$self->{_worldArea} = [ 0,0, 9999, 9999 ];
	}

	if( $proj ){
		$self->{_geo2cnv} = sub{
			my( $lon, $lat ) = @_;
			my( $x, $y ) = $proj->forward( $lat, $lon );
			( $x, $y ) = ( $x * $cX + $tX, $y * $cY + $tY );
			return ( $x, $y );
		};
		$self->{_cnv2geo} = sub{
			my( $x, $y ) = @_;
			( $x, $y ) = ( ($x-$tX) / $cX, ($y-$tY) / $cY );
			my( $lat, $lon ) = $proj->inverse( $x, $y );
			return ( $lon, $lat );
		};
	}else{
		$self->{_geo2cnv} = sub{
			my( $lon, $lat ) = @_;
			my( $x, $y ) = ( $lon * $cX + $tX, $lat * $cY + $tY );
			return ( $x, $y );
		};
		$self->{_cnv2geo} = sub{
			my( $x, $y ) = @_;
			my( $lon, $lat ) = ( ($x-$tX) / $cX, ($y-$tY) / $cY );
			return ( $lon, $lat );
		};
	}
}

sub cnv2geo {
	my( $self, $x, $y ) = @_;
	return [ $self->{_cnv2geo}->(@$x) ] if ref($x);
	return $self->{_cnv2geo}->( $x, $y );
}

sub geo2cnv {
	my( $self, $lon, $lat ) = @_;
	return [ $self->{_geo2cnv}->(@$lon) ] if ref($lon);
	return $self->{_geo2cnv}->( $lon, $lat );
}

sub worldArea {
	my( $self ) = @_;
	return $self->{_worldArea};
}

sub identity {
	return OGF::View::Projection->new( undef, {'X' => [-180,-180,180,180], 'Y' => [-90,-90,90,90]} );
}

# http://en.wikipedia.org/wiki/Geodetic_datum#Conversion_calculations
sub latitudeProjectionInfo {
	my( $pkg, $centerY, $pxSize ) = @_;
	my $phiY = $centerY * $OGF::DEG;
#	print STDERR "\$phiY <", $phiY, ">\n";  # _DEBUG_

	my $e2 = 1 - ($OGF::GEO_RAD_POL / $OGF::GEO_RAD_AEQ) ** 2;
#	print STDERR "\$e2 <", $e2, ">\n";  # _DEBUG_
	my( $rM, $rN ) = ( $OGF::GEO_RAD_AEQ*(1 - $e2) / (1 - $e2 * sin($phiY)**2)**1.5, $OGF::GEO_RAD_AEQ / sqrt(1 - $e2 * sin($phiY)**2) );
#	print STDERR "\$rM <", $rM, ">  \$rN <", $rN, ">\n";  # _DEBUG_

	my $pxLon = $rN * cos($phiY) * $OGF::DEG / $pxSize;
	my $pxLat = $rM * $OGF::DEG / $pxSize;
#	print STDERR "\$dgX <", $dgX, ">  \$dgY <", $dgY, ">\n";  # _DEBUG_

	return ( $pxLon, $pxLat );  # pixels per degree
}

sub latitudeProjection {
	my( $pkg, $centerY, $pxSize ) = @_;
	my( $pxLon, $pxLat ) = $pkg->latitudeProjectionInfo( $centerY, $pxSize );
	my( $worldWd, $worldHg ) = ( 360*$pxLon, 180 * $pxLat );
	my $hTransf = { 'X' => [ -180 => 0, 180 => $worldWd ], 'Y' => [ -90 => $worldHg, 90 => 0 ] };
	my $proj = OGF::View::Projection->new( '', $hTransf );
}



1;

