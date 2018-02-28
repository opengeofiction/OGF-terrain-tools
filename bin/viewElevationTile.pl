#! /usr/bin/perl -w
use strict;
use warnings;
use Tk;
use Tk::PNG;
use File::Find;
use OGF::Terrain::ElevationTile;
use OGF::Terrain::PhysicalMap;
use OGF::Util::Canvas;
use OGF::Util::Usage qw( usageInit usageError );



# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1201 C:/usr/tmp/S09E050.hgt -bigEndian
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1201 C:\Map\Roantra\SRTM3\tmp\N45E030.hgt -bigEndian
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1201 C:\Map\Roantra\SRTM3\tmp\N43E029.hgt -bigEndian
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 3601 C:/usr/tmp/S63E108.hgt -bigEndian
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl -bigEndian 1201 C:\Map\Elevation\tmp\S59E083.hgt
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 256 C:\Map\OGF\WW_elev\13\5735\5735_6001.bil
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 256 elev:OGF:13:5911-5935:6563-6581
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 183,296 C:/Map/Elevation/tmp/temp_layer.cnr
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1024 C:/Map/Sathria/elev/
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1024 C:/Map/Sathria/elev/2/1/1_1.bil
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 256 elev:WebWW:8:766-770:1190-1194
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 512 elev:Roantra:4:766-770:908-912
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1024 C:/Map/Sathria/elev/5 -noExist
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 256 elev:OGF:13:bbox=121.28014,-21.61147,121.46965,-21.43070
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 256 elev:WebWW:9:bbox=121.28014,-21.61147,121.46965,-21.43070
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1024 elev:SathriaLCC:5:bbox=42.62146,48.01932,44.47266,49.42884 -forceRemake
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1024 C:/Map/Paxtar/elev/0
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1024 elev:Paxtar:0:0-7:0-7
# perl C:/usr/OGF-terrain-tools/bin/viewElevationTile.pl 1201 C:/Map/Elevation/tmp/S25E123.hgt




my %opt;
usageInit( \%opt, qq/ bigEndian noRelief forceRemake noExist /, << "*" );
<size> <file1> [<file2> ...] [-bigEndian] [-noRelief] [-fullscreen]
*

my( $SIZE, @FILES ) = @ARGV;
usageError() unless $SIZE && @FILES;


my( $size, @files ) = ( $SIZE, @FILES );
my( $wd, $hg ) = ($SIZE =~ /,/)? (split /,/, $SIZE) : ( $SIZE, $SIZE );


my $TILE_DATA = [];

#$OGF::Terrain::ElevationTile::SUPPORTED_BPP{'2'} = 's>' if $files[0] =~ /\.hgt$/;



my $main = MainWindow->new( -title => 'Tk::Widget Test' );
initMainWindow( $main, $opt{'fullscreen'} );


my( $ct, $info ) = ( 0, '' );
my $lbInfo = $main->Label( -textvariable => \$info, -justify => 'left', -height => 1 )->pack( -expand => 1, -fill => 'x' );

#my $view = $main->Scrolled( 'Widget' )->pack();
#my $cnv = $main->Canvas(
my $cnv = $main->Scrolled( 'Canvas',
#   -width  => 2 * $wd,
#   -height => $hg,
    -width  => 1850,
    -height => 1000,
    -scrollregion => [ 0, 0, 10000, 10000 ],
    -scrollbars   => 'se',
)->pack( -expand => 1, -fill => 'both' );


my $cnvS = $cnv->Subwidget( 'scrolled' );
$cnvS->Tk::bind( '<Motion>' => sub {
	my( $x, $y ) = OGF::Util::Canvas::canvasEventPos( $cnvS );
#	print STDERR ++$ct . "   \$x <", $x, ">  \$y <", $y, ">\n";  # _DEBUG_
	my $text = "$x,$y";
	$text .= $TILE_DATA->[$y][$x] if $TILE_DATA->[$y] && defined $TILE_DATA->[$y][$x];
	$info = $text;
} );


if( -d $files[0] ){
#   my $startDir = 'C:/Map/Sathria/elev/2/0/0_2.bil';
#   my $startDir = 'C:/Map/Sathria/elev';
    my $startDir = $files[0];
    my( $img, $photo );

    find(	{ wanted => sub {
        if( $img ){
            $cnv->delete( $img );
        }
        if( $photo ){
            $photo->destroy;
#           $photo->delete;
        }

        my $file = $info = $File::Find::name;
        return unless $file =~ /\.bil$/;

        print STDERR "load $file\n";
        ( $img, $photo ) = viewElevationTile( $cnv, $file, 0, 0, $wd, $hg, \%opt );
#    	  (my $pngFile1 = $file) =~ s/\.bil$/.png/;
    }, no_chdir => 1 }, $startDir	);

}elsif( -f $files[0] ){
	my( $x0, $y0 ) = ( 0, 0 );
    foreach my $file ( @files ){
        viewElevationTile( $cnv, $file, $x0,$y0, $wd, $hg, \%opt );
        $x0 += $wd;
#       viewElevationTile( $cnv, $files[1], $wd,0, $wd, $hg ) if $files[1];
    }
}else{
	require OGF::LayerInfo;
	my $lrInfo = OGF::LayerInfo->tileInfo( $files[0] );
	die qq/ERROR: Cannot parse layer info./ if ! $lrInfo;
	my $tileOrder_N = ($lrInfo->{'layer'} eq 'WebWW')? 1 : 0;
	print STDERR "\$tileOrder_N <", $tileOrder_N, ">\n";  # _DEBUG_

	my( $tx, $ty ) = $lrInfo->getAttr( 'x', 'y' );
	$tx = $tx->[0] if ref($tx) eq 'ARRAY';
	$ty = $tileOrder_N ? $ty->[-1] : $ty->[0] if ref($ty) eq 'ARRAY';
	OGF::LayerInfo->tileIterator( $lrInfo, sub {
		my( $item ) = @_;
		my $file = $item->tileName();
#		print STDERR "\$file <", $file, ">\n";  # _DEBUG_
#		print STDERR $item->{'y'}, " ", $item->{'x'}, "\n";
		my $x0 = ($item->{'x'} - $tx) * $wd; 
		my $y0 = $tileOrder_N ? ($ty - $item->{'y'}) * $hg : ($item->{'y'} - $ty) * $hg;
        viewElevationTile( $cnv, $file, $x0,$y0, $wd, $hg, \%opt );
	} );
}


MainLoop();

#-------------------------------------------------------------------------------


# TODO: needs option for big-endian

sub viewElevationTile {
    my( $cnv, $file, $x0, $y0, $wd, $hg, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;

	my( $img, $photo );
    my $pngFile = $file . '.png';
    print STDERR "\$pngFile <", $pngFile, ">\n";  # _DEBUG_
    if( -f $pngFile && ! $opt{'forceRemake'} ){
        if( ! $opt{'noExist'} ){
            $photo = $cnv->Photo( -file => $pngFile );
            $img = $cnv->createImage( $x0, $y0, -image => $photo, -anchor => 'nw', -tags => 'tile' );
        }
        return ( $img, $photo );
    }

	my $packTemplate = ($hOpt->{'bigEndian'} || $file =~ /\.hgt$/)? 's>' : 's';
    my $aTile = $TILE_DATA = OGF::Terrain::ElevationTile::makeArrayFromFile( $file, $wd, $hg, 2, undef, $packTemplate );
    ( $photo, my $data, my $cSub ) = OGF::Terrain::PhysicalMap::makePhotoFromElev( $cnv, $aTile, $wd, $hg, $hOpt );
    $img = $cnv->createImage( $x0, $y0, -image => $photo, -anchor => 'nw', -tags => 'tile' );
    $cSub->( $cnv ) if $cSub;

    die q/ERROR $file == $pngFile/ if $file eq $pngFile;
    print STDERR "save $pngFile\n";
    $photo->write( $pngFile );

    return ( $img, $photo );
}




sub initMainWindow {
    my( $main, $fullScreen ) = @_;
    my( $wd, $hg, $x0, $y0 ) = ( $main->screenwidth, $main->screenheight, 0, 0 );
    ( $wd, $hg, $x0 ) = ( $wd - 20, $hg - 100, 200 ) if ! $fullScreen;
    $main->geometry( "${wd}x${hg}+$x0+$y0" );
    $main->FullScreen( $fullScreen ? 1 : 0 );
    $main->bind( '<Control-KeyPress-Q>' => sub{ exit; } );
}

