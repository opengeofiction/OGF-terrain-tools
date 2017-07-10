package OGF::View::TileLayer;
use strict;
use warnings;
use POSIX qw( floor fmod );
use UTAN::Util qw( exception );
use UTAN::Parser;
use OGF::Const;
use OGF::Util;
use OGF::View::Projection;
use OGF::LayerInfo;


sub new {
	my( $pkg, $dsc, %param ) = @_;
#	print STDERR "\$pkg <", $pkg, ">  \$dsc <", $dsc, ">  \%param <", join('|',%param), ">\n";  # _DEBUG_

	my $self = {
		_descriptor => $dsc,
		_level      => undef,
		_info       => undef,
		_proj       => undef,
		_tileOrder  => undef,
	};
	bless $self, $pkg;
	$self->initLayerInfo( $dsc );

	return $self;
}

sub initLayerInfo {
	my( $self, $dsc ) = @_;

	my $wwInfo;
	if( ref($dsc) eq 'OGF::LayerInfo' ){
		$wwInfo = $dsc;
	}elsif( ref($dsc) eq 'SCALAR' || $dsc =~ /\.(tlr|pvd)$/ ){
		$wwInfo = bless {
			'type'  => 'image',
			'layer' => 'DYNAMIC',
			'level' => 0,
		}, 'OGF::LayerInfo';
		my $hTransf = $wwInfo->{'transform'} = {};
		$self->initLayerFromTlr( $dsc, $wwInfo, $hTransf );		
	}else{
		$dsc =~ s/^WW://;
		$dsc =~ s/(:\d+)$/$1:all/;
		$wwInfo = OGF::LayerInfo->tileInfo( $dsc );
	}
	$self->{_info} = $wwInfo;

	( $OGF::ELEV_TILE_WIDTH, $OGF::ELEV_TILE_HEIGHT ) = $wwInfo->tileSize();
	print STDERR "\$OGF::ELEV_TILE_WIDTH <", $OGF::ELEV_TILE_WIDTH, ">  \$OGF::ELEV_TILE_HEIGHT <", $OGF::ELEV_TILE_HEIGHT, ">\n";  # _DEBUG_

	if( $wwInfo->{'transform'} && $self->{_proj4} ){
		# loaded from tlr description	
		$self->{_proj} = OGF::View::Projection->new( $self->{_proj4}, $wwInfo->{'transform'} );
	}elsif( $wwInfo->getTransform() ){
#		use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [$self],    ['self'] ),    "\n";
#		use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [$wwInfo],  ['wwInfo'] ),  "\n";
#		use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [$hTransf], ['hTransf'] ), "\n";
		my $projDsc = $wwInfo->getProjection() || '';
		my( $minY, $maxY, $minX, $maxX, $baseLevel, $orderX, $orderY ) = OGF::LayerInfo->minMaxInfo( $wwInfo->{'layer'}, $wwInfo->{'level'} );
		my $to = $self->{_tileOrder} = [ $orderX, $orderY, $maxX-$minX+1, $maxY-$minY+1 ];
		my $lvC = 2 ** ($wwInfo->{'level'} - $baseLevel);
		my $hTransf = $wwInfo->getTransform();
		$hTransf->{'X'}[1] *= $lvC;
		$hTransf->{'X'}[3] *= $lvC;
		$hTransf->{'Y'}[1] *= $lvC;
		$hTransf->{'Y'}[3] *= $lvC;
		$self->{_proj} = OGF::View::Projection->new( $projDsc, $hTransf );
	}elsif( $wwInfo->{'layer'} =~ /^(Roantra|Cearno|Larraincon)$/ ){
#		$self->{_proj} = OGF::View::Projection->new( $dsc );
		my( $lv, $sizeX, $sizeY ) = ( $self->{_level} = $wwInfo->{'level'} + $OGF::WW_ADD_LEVEL, $wwInfo->tileSize() );
		$self->{_tileOrder} = [ 1, -1, 2*(2**$lv), 2**$lv ];
		if( $wwInfo->{'proj'} ){
			my $tileDeg = 180 / (2 ** $lv);
			my( $pxLon, $pxLat ) = OGF::View::Projection->latitudeProjectionInfo( @{$wwInfo->{'proj'}} );
			( $sizeX, $sizeY ) = ( int($tileDeg * $pxLon + .5), int($tileDeg * $pxLat + .5) );
		}
		my( $worldWd, $worldHg ) = ( $sizeX*2*(2**$lv), $sizeY*(2**$lv) );
		my $hTransf = { 'X' => [ -180 => 0, 180 => $worldWd ], 'Y' => [ -90 => $worldHg, 90 => 0 ] };
		$self->{_proj} = OGF::View::Projection->new( '', $hTransf );
	}elsif( $wwInfo->{'layer'} =~ /^(LATPROJ|Cesium|WebWW)$/ ){
#		$self->{_proj} = OGF::View::Projection->new( $dsc );
		my( $lv, $sizeX, $sizeY ) = ( $self->{_level} = $wwInfo->{'level'}, $wwInfo->tileSize() );
		my( $minY, $maxY, $minX, $maxX, $baseLevel ) = OGF::LayerInfo->minMaxInfo( $wwInfo->{'layer'}, $wwInfo->{'level'} );
		my $to = $self->{_tileOrder} = [ 1, -1, $maxX-$minX+1, $maxY-$minY+1 ];
		if( $wwInfo->{'proj'} ){
			my $tileDeg = 180 / $to->[2];
			my( $pxLon, $pxLat ) = OGF::View::Projection->latitudeProjectionInfo( @{$wwInfo->{'proj'}} );
			( $sizeX, $sizeY ) = ( int($tileDeg * $pxLon + .5), int($tileDeg * $pxLat + .5) );
		}
		my( $worldWd, $worldHg ) = ( $sizeX * $to->[2], $sizeY * $to->[3] );
		my $hTransf = { 'X' => [ -180 => 0, 180 => $worldWd ], 'Y' => [ -90 => $worldHg, 90 => 0 ] };
		$self->{_proj} = OGF::View::Projection->new( '', $hTransf );
	}elsif( $wwInfo->{'layer'} =~ /^(O[ST]M|OGF[TR]?)$/ ){
#		$self->{_proj} = OGF::View::Projection->new( $dsc );
		my( $lv, $sizeX, $sizeY ) = ( $self->{_level} = $wwInfo->{'level'}, $wwInfo->tileSize() );
		$self->{_tileOrder} = [ 1, 1, 2**$lv, 2**$lv ];
		my( $worldWd, $worldHg ) = ( $sizeX*(2**$lv), $sizeY*(2**$lv) );
#		my $wsz = 2 * 20037508.3427892;
#		my $hTransf = { 'X' => [ 0 => 0, $wsz => $worldHg ], 'Y' => [ 0 => $worldWd, $wsz => 0 ] };
		my $wsz = 20037508.3427892;
		my $hTransf = { 'X' => [ -$wsz => 0, $wsz => $worldWd ], 'Y' => [ -$wsz => $worldHg, $wsz => 0 ] };
#		$self->{_proj} = OGF::View::Projection->new( '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=-180.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs', $hTransf );
		$self->{_proj} = OGF::View::Projection->new( '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs', $hTransf );
	}else{
		exception( "Unsupported projection descriptor: $dsc" );
	}
}

sub initLayerFromTlr {
	my( $self, $file, $wwInfo, $hTransf ) = @_;
	my $hCmds = OGF::Util::parseConfig( $file, {
		'_tileOrder'  => [ $self,    'c' => 'p0,' ],
		'tileSize'    => [ $wwInfo,  'c' => 'p0,' ],
		'_tileImage'  => [ $self,    ['c','p0'] => 'p1' ],
		'_transform'  => [ $hTransf, 'p0' => 'p1-4' ],
		'_background' => [ $self,    'c'  => 'p0' ],
		'_proj4'      => [ $self,    'c'  => 'P'  ],
		'_tileOffset' => [ $self,    'c'  => 'p0,' ],
		'mapScale'    => [ $wwInfo,  'c'  => 'p0' ],
	} );
	use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [$self,$file,$wwInfo,$hTransf], ['self','file','wwInfo','hTransf'] ), "\n";  # _DEBUG_
}

sub tileName {
	my( $self, $tx, $ty ) = @_;
	if( $self->{_tileImage} ){
		return $self->{_tileImage}{"$tx,$ty"};
	}else{
		return $self->{_info}->copy( 'x' => $tx, 'y' => $ty )->tileNameGenerated( {'nocache' => 1} );
	}
}

sub tileInfoTag {
	my( $self, $tx, $ty ) = @_;
	return $self->{_info}->copy( 'x' => $tx, 'y' => $ty )->toString();
}

sub level {
	my( $self ) = @_;
	return $self->{_level};
}

sub projection {
	my( $self ) = @_;
	return $self->{_proj};
}

sub tile2cnv {
	my( $self, $tx, $ty, $xt, $yt ) = @_;
	return [ $self->tile2cnv(@$tx) ] if ref($tx);

	my( $dx, $dy, $maxX, $maxY ) = @{$self->{_tileOrder}};
	$tx = $maxX - 1 - $tx if $dx < 0;
	$ty = $maxY - 1 - $ty if $dy < 0;
#	$tx = ($tx + 2 ** ($self->{_level} - 1)) % (2 ** $self->{_level});   # 180 deg at center

	my( $tileWd, $tileHg ) = $self->{_info}->tileSize();
	my( $x, $y ) = ( $tx * $tileWd + $xt, $ty * $tileHg + $yt );
	( $x, $y ) = ( $x + $self->{_tileOffset}[0], $y + $self->{_tileOffset}[1] ) if $self->{_tileOffset};

	return ( $x, $y );
}

sub cnv2tile {
	my( $self, $x, $y ) = @_;
	return [ $self->cnv2tile(@$x) ] if ref($x);

	( $x, $y ) = ( $x - $self->{_tileOffset}[0], $y - $self->{_tileOffset}[1] ) if $self->{_tileOffset};
	my( $tileWd, $tileHg ) = $self->{_info}->tileSize();
	my( $tx, $ty, $xt, $yt ) = ( floor($x/$tileWd), floor($y/$tileHg), fmod($x,$tileWd), fmod($y,$tileHg) );

	my( $dx, $dy, $maxX, $maxY ) = @{$self->{_tileOrder}};
#	print STDERR "\$dx <", $dx, ">  \$dy <", $dy, ">  \$maxX <", $maxX, ">  \$maxY <", $maxY, ">\n";  # _DEBUG_
	$tx = $maxX - 1 - $tx if $dx < 0;
	$ty = $maxY - 1 - $ty if $dy < 0;

	return ( $tx, $ty, $xt, $yt );
}

sub tile2geo {
	my( $self, $tx, $ty, $xt, $yt ) = @_;
	return [ $self->tile2geo(@$tx) ] if ref($tx);

	my( $x, $y )     = $self->tile2cnv( $tx, $ty, $xt, $yt );
	my( $lon, $lat ) = $self->{_proj}->cnv2geo( $x, $y );
	return ( $lon, $lat );
}

sub geo2tile {
	my( $self, $lon, $lat ) = @_;
	return [ $self->geo2tile(@$lon) ] if ref($lon);

	my( $x, $y )             = $self->{_proj}->geo2cnv( $lon, $lat );
	my( $tx, $ty, $xt, $yt ) = $self->cnv2tile( $x, $y );
	return ( $tx, $ty, $xt, $yt );
}

sub geo2cnv {
	my $self = shift;
	return $self->{_proj}->geo2cnv( @_ );
}

sub cnv2geo {
	my $self = shift;
	return $self->{_proj}->cnv2geo( @_ );
}

sub bboxTileRange {
	my( $self, $bbox ) = @_;
	if( ! ref($bbox) ){
		$bbox =~ s/^bbox=//;
		$bbox = [ split /,/, $bbox ];
	}
	my( $minLon, $minLat, $maxLon, $maxLat ) = @$bbox;
    my( $tx0, $ty0, $xt0, $yt0 ) = $self->geo2tile( $minLon, $minLat );
    my( $tx1, $ty1, $xt1, $yt1 ) = $self->geo2tile( $maxLon, $maxLat );
	( $tx0, $tx1 ) = ( $tx1, $tx0 ) if $tx1 < $tx0;  # probably never happens
	( $ty0, $ty1 ) = ( $ty1, $ty0 ) if $ty1 < $ty0;
	return {'y' => [$ty0, $ty1], 'x' => [$tx0, $tx1]};
}


#-------------------------------------------------------------------------------

#sub appropriateLevel {
#	my( $wwInfo, $centerY, $pxSize ) = @_;
#	my $hMinMax = OGF::LayerInfo::getPlugin($wwInfo->{'layer'})->minMaxInfo();
#	my $maxLevel = $hMinMax->{'baseLevel'};
#	my( $tileWd, $tileHg ) = ( 512, 512 );
#	my @lvpxSize = map { $OGF::GEO_RAD_AEQ * $OGF::PI / ($tileHg * (2**($OGF::WW_ADD_LEVEL + $_))) } (0..$maxLevel);
#	@lvpxSize = grep {$_ >= $pxSize} @lvpxSize;
#	my $level = min( $#lvpxSize + 1, $maxLevel );
#	return $level;
#}

sub pixelSize {
	my( $self, $x, $y ) = @_;
	my( $mlon, $mlat ) = OGF::View::Projection->latitudeProjectionInfo( $y, 1 );
	my( $x0, $y0 ) = $self->{_proj}->geo2cnv( 0,       $y );
	my( $x1, $y1 ) = $self->{_proj}->geo2cnv( 1/$mlon, $y );
	my $pxSize = 1/($x1 - $x0);
	return $pxSize;
}

sub appropriateLevel {
	my( $wwInfo, $centerY, $pxSize ) = @_;

	my $maxLevel  = $wwInfo->levelInfo()->{'maxLevel'};
	my $baseLevel = 20;
	my $tl = OGF::View::TileLayer->new( $wwInfo->copy('level' => $baseLevel) );

#	my( $mlon, $mlat ) = OGF::View::Projection->latitudeProjectionInfo( $centerY, 1 );
#	my( $x0, $y0 ) = $tl->{_proj}->geo2cnv( 0,       $centerY );
#	my( $x1, $y1 ) = $tl->{_proj}->geo2cnv( 1/$mlon, $centerY );
#	my $lvpxSize = 1/($x1 - $x0);

	my $lvpxSize = $tl->pixelSize( 0, $centerY );
	my @lvpxSize = map { $lvpxSize * 2**($baseLevel-$_) } (0..$maxLevel);

	@lvpxSize = grep {$_ >= $pxSize} @lvpxSize;
	my $level = min( $#lvpxSize + 1, $maxLevel );
	return $level;
}

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }



#-------------------------------------------------------------------------------


sub tmpRectLayer {
	my( $self, $rect ) = @_;

	my( $orderX, $orderY, $numX, $numY ) = @{$self->{_tileOrder}};
	my $proj4   = $self->{_proj}{_descriptor};
	my $hTransf = $self->{_proj}{_transform};
	my( $xs0, $xt0, $xs1, $xt1 ) = @{$hTransf->{'X'}};
	my( $ys0, $yt0, $ys1, $yt1 ) = @{$hTransf->{'Y'}};

	my( $x0, $y0, $x1, $y1 ) = @$rect;
	my( $tileWd, $tileHg ) = ( $x1-$x0+1, $y1-$y0+1 );

	my $tlr = << "EOF";
tileSize     $tileWd,$tileHg 
tileOrder    $orderX,$orderY,$numX,$numY
tileOffset   $x0,$y0

tileImage    0,0    C:/Map/Elevation/tmp/temp_layer.cnr
proj4        $proj4

transform   X   $xs0 $xt0   $xs1 $xt1
transform   Y   $ys0 $yt0   $ys1 $yt1
EOF

	print STDERR "----- \$tlr -----\n", $tlr, "\n----------\n";  # _DEBUG_

	my $tmpLayer = OGF::View::TileLayer->new( \$tlr );
	return $tmpLayer;
}





1;

