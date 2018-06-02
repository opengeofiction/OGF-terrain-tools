package OGF::Util::GlobalTile;
use strict;
use warnings;
use POSIX qw( floor );
use OGF::LayerInfo;
use OGF::View::TileLayer;


our $MAX_TILES_DEFAULT = 1500;
our $CLEAR_TILES_CHUNK =  100;

sub new {
	my( $pkg, $wwInfo, $hOpt ) = @_;
#	$pkg = 'OGF::Util::GlobalTile::View' if $hOpt && $hOpt->{'-visual'};

	my $self = {
		_tiles      => {},
		_tileAccess => {},
		_tileCount  => 0,
		_maxTiles   => $MAX_TILES_DEFAULT,
	};
	if( ref($wwInfo) eq 'OGF::View::TileLayer' ){
		$self->{_tileLayer} = $wwInfo;
	}elsif( $wwInfo =~ /\.cpx$/ ){
		my $hBlocks = OGF::Util::extractFileBlocks( $wwInfo );
		$self->{_tileLayer} = OGF::View::TileLayer->new( \$hBlocks->{'tlr'} );
	}else{
		$self->{_tileLayer} = OGF::View::TileLayer->new( $wwInfo );
	}
	$self->{_layerInfo} = $self->{_tileLayer}{_info};
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$self->{_layerInfo}], ['self->{_layerInfo}'] ), "\n";  exit;  # _DEBUG_

	bless $self, $pkg;
	return $self;
}

sub getPixel {
	my( $self, $x, $y, $verbose ) = @_;
	$verbose = 0 if ! $verbose;

	return $self->{_default} if $x < 0 || $y < 0;
	my( $aData, $xt, $yt ) = $self->getTileArray( $x, $y, $verbose );
	my $val = $aData->[$yt][$xt];
	print STDERR "getPixel $x $y $xt $yt - $val\n" if $verbose && defined $val;
	$val = 0 if ! defined $val;	
	return $val;
}

sub setPixel {
	my( $self, $x, $y, $val ) = @_;
	my( $aData, $xt, $yt ) = $self->getTileArray( $x, $y );
	$aData->[$yt][$xt] = $val;
}

sub getElevation {
	my( $self, $x, $y ) = @_;
    if( ref($x) && defined $x->{'lon'} ){
        my( $x, $y ) = $self->{_tileLayer}->geo2cnv( $x->{'lon'}, $x->{'lat'} );
        return $self->getElevation( $x, $y );
	}
    my( $x0, $y0 ) = ( floor($x), floor($y) );
    my( $x1, $y1 ) = ( $x0 + 1, $y0 + 1 );
    my( $elev00, $elev10, $elev01, $elev11 ) = ( $self->getPixel($x0,$y0), $self->getPixel($x1,$y0), $self->getPixel($x0,$y1), $self->getPixel($x1,$y1) );
    my $elev = ($x1-$x)*($y1-$y)*$elev00 + ($x-$x0)*($y1-$y)*$elev10 + ($x1-$x)*($y-$y0)*$elev01 + ($x-$x0)*($y-$y0)*$elev11;
    $elev = floor( $elev + .5 );
	return $elev;
}

sub getTileArray {
	my( $self, $x, $y, $verbose ) = @_;
#	my( $tx, $ty, $tileWd, $tileHg ) = $self->getTileXY( $x, $y );
	my( $tx, $ty, $xt, $yt ) = $self->cnv2tile( $x, $y );
#	print STDERR "\$tx <", $tx, ">  \$ty <", $ty, ">  \$xt <", $xt, ">  \$yt <", $yt, ">\n";  # _DEBUG_
	my( $tileWd, $tileHg )   = $self->{_layerInfo}->tileSize();
	my( $key, $flag ) = ( "$tx:$ty", 0 );

	if( ! $self->{_tiles}{$key} ){
#		print STDERR "\$x <", $x, ">  \$y <", $y, ">  \$tileWd <", $tileWd, ">  \$tileHg <", $tileHg, ">\n";  # _DEBUG_
		print STDERR "load tile $self->{_layerInfo}{type}:$self->{_layerInfo}{layer}:$self->{_layerInfo}{level}:$ty:$tx\n";
		my $file = $self->{_tileLayer}->tileName( $tx, $ty );
#		print STDERR "\$file <", $file, ">\n";  # _DEBUG_
		if( $file ){
			$self->{_tiles}{$key} = $self->{_layerInfo}->tileArray( $file );
#			print STDERR "$key -> $file\n";
			$flag = 1;
			++$self->{_tileCount};
			$self->{_tileAccess}{$key} = time;
		}else{
			$self->{_tiles}{$key} = [];
#			print STDERR "$key -> ---\n";
		}
		print STDERR "tileCount = ", $self->{_tileCount}, "\n";  # _DEBUG_
		$self->clearTiles() if $self->{_tileCount} > $self->{_maxTiles};
	}

	print STDERR "getTileArray $x $y $tx $ty [", scalar(@{$self->{_tiles}{$key}}) ,"]\n" if $verbose;
#	return ( $self->{_tiles}{$key}, $x % $tileWd, $y % $tileHg, $flag );
	return ( $self->{_tiles}{$key}, $xt, $yt, $flag );
}

sub minMaxInfo {
	my( $self ) = @_;
	my $wwInfo = $self->{_layerInfo};
	my( $minY, $maxY, $minX, $maxX, $baseLevel ) = OGF::LayerInfo->minMaxInfo( $wwInfo->{'layer'}, $wwInfo->{'level'} );
	return ( $minY, $maxY, $minX, $maxX, $baseLevel );
}

sub clearTiles {
	print STDERR "--- clearTiles ---\n";
	my( $self ) = @_;
	my $hTime = $self->{_tileAccess};
	my @tileKeys = sort {$hTime->{$a} <=> $hTime->{$b}} keys %{$self->{_tiles}};
	for( 1 .. $CLEAR_TILES_CHUNK ){
		my $key = shift @tileKeys;
		delete $self->{_tiles}{$key};
		delete $self->{_tileAccess}{$key};
	}
	$self->{_tileCount} = scalar(@tileKeys);
}


#-------------------------------------------------------------------------------

sub geo2cnv {
	my $self = shift;
	return $self->{_tileLayer}{_proj}->geo2cnv( @_ );
}

sub cnv2geo {
	my $self = shift;
	return $self->{_tileLayer}{_proj}->cnv2geo( @_ );
}

sub tile2cnv {
	my $self = shift;
	return $self->{_tileLayer}->tile2cnv( @_ );
}

sub cnv2tile {
	my $self = shift;
	return $self->{_tileLayer}->cnv2tile( @_ );
}

sub tile2geo {
	my $self = shift;
	return $self->{_tileLayer}->tile2geo( @_ );
}

sub geo2tile {
	my $self = shift;
	return $self->{_tileLayer}->geo2tile( @_ );
}







1;

