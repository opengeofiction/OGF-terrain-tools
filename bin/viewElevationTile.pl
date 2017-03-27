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



# perl C:/usr/MapView/bin/viewElevationTile.pl 1201 C:/usr/tmp/S09E050.hgt -bigEndian
# perl C:/usr/MapView/bin/viewElevationTile.pl 1201 C:\Map\Roantra\SRTM3\tmp\N45E030.hgt -bigEndian
# perl C:/usr/MapView/bin/viewElevationTile.pl 1201 C:\Map\Roantra\SRTM3\tmp\N43E029.hgt -bigEndian
# perl C:/usr/MapView/bin/viewElevationTile.pl 3601 C:/usr/tmp/S63E108.hgt -bigEndian
# perl C:/usr/MapView/bin/viewElevationTile.pl -bigEndian 1201 C:\Map\Elevation\tmp\S59E083.hgt
# perl C:/usr/MapView/bin/viewElevationTile.pl 256 C:\Map\OGF\WW_elev\13\5735\5735_6001.bil
# perl C:/usr/MapView/bin/viewElevationTile.pl 256 elev:OGF:13:5911-5935:6563-6581
# perl C:/usr/MapView/bin/viewElevationTile.pl 262,239 C:/Map/Elevation/tmp/temp_layer.cnr


my %opt;
usageInit( \%opt, qq/ bigEndian noRelief /, << "*" );
<size> <file1> [<file2> ...] [-bigEndian] [-noRelief]
*

my( $SIZE, @FILES ) = @ARGV;
usageError() unless $SIZE && @FILES;





my( $size, @files ) = ( $SIZE, @FILES );
my( $wd, $hg ) = ($SIZE =~ /,/)? (split /,/, $SIZE) : ( $SIZE, $SIZE );


my $TILE_DATA = [];

#$OGF::Terrain::ElevationTile::SUPPORTED_BPP{'2'} = 's>' if $files[0] =~ /\.hgt$/;



my $main = MainWindow->new( -title => 'Tk::Widget Test' );

my( $ct, $info ) = ( 0, '' );
my $lbInfo = $main->Label( -textvariable => \$info, -justify => 'left' )->pack( -expand => 1, -fill => 'x' );

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
	$text .= "  " . $TILE_DATA->[$y][$x] if $TILE_DATA->[$y] && defined $TILE_DATA->[$y][$x];
	$info = $text;
} );


#$main->geometry( "${wd}x${hg}+200+0" );
$main->geometry( "1850x1000+0+0" );

#my $obj->bind( '<Double-ButtonPress-1>', sub{} );
$main->bind( '<Control-KeyPress-Q>', sub{ exit; } );


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
            $photo->delete;
        }

        my $file = $File::Find::name;
        return unless $file =~ /\.bil$/;

        print STDERR "load $file\n";
        ( $img, $photo ) = viewElevationTile( $cnv, $file, 0, 0, $wd, $hg, \%opt );
#    	  (my $pngFile1 = $file) =~ s/\.bil$/.png/;
        my $pngFile = $file . '.png';

        die q/ERROR $file == $pngFile/ if $file eq $pngFile;
        print STDERR "save $pngFile\n";
        $photo->write( $pngFile );
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
	my $packTemplate = $hOpt->{'bigEndian'} ? 's>' : 's';
    my $aTile = $TILE_DATA = OGF::Terrain::ElevationTile::makeArrayFromFile( $file, $wd, $hg, 2, undef, $packTemplate );
    my( $photo, $data, $cSub ) = OGF::Terrain::PhysicalMap::makePhotoFromElev( $cnv, $aTile, $wd, $hg, $hOpt );
    my $img = $cnv->createImage( $x0, $y0, -image => $photo, -anchor => 'nw', -tags => 'tile' );
    $cSub->( $cnv ) if $cSub;
    return ( $img, $photo );
}



