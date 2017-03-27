# OGF-terrain-tools


## Installation

To install this module, type the following:

    perl Makefile.PL
    make
    # no tests yet
    make install


## Configuration

Rename the file *ogftools.sample.conf* to *ogftools.conf* and copy it to one of the follofing
locations:

* the directory from where you intend to execute the scripts
* $HOME/.ogf/ogftools.conf
* /etc/ogftools.conf

Edit the config file (for example):

    layer_path_prefix = /home/username/ogf/layers
    terrain_color_map = /home/username/ogf/resources/DEM_poster.cpt

**layer_path_prefix** is the directory where the OGF tools will create the target data, mostly lots of elevation tiles.
The directory must be writabe by the user running the scripts, and belong to a file system that has enough space available.

**terrain_color_map** is a file that contains a color palette suitable for terrain maps, for example *DEM_poster.cpt*, which can be
downloaded from http://soliton.vm.bytemark.co.uk/pub/cpt-city/td/tn/DEM_poster.png.index.html .



## Tile range descriptors

Several of the included scripts accept a tile range descriptor of the following form as command line parameter:

    contour:OGF:13:5724-5768:5984-6030

Here, "contour" is the file type, "OGF" the layer name, and 13 the zoom level. Then follows the range of tiles in Y (latitude) and then X (longitude) direction.
In the current example, the result is a total number of (5768-5742+1) * (6030-5984+) = 27 * 47 = 1269 tiles.


## Examples

**ogfElevation.pl** converts an *.osm* contour file to "contour tiles", i.e. raster files that contain the contour information and are suitable
for further processing:

    perl ogfElevation.pl 13 contours_01.osm contours_02.osm

Here, 13 is the zoom level, followed by a list of contour files. The choice of the most suitable zoom level depends on the contour data. 
After finishing, *ogfElevation.pl* will display the commands that have to be executed next, in this case:

**makeElevationFromContour.pl** will convert the previously generated contour tiles into actual elevation tiles, which 
are still in Mercator projection and organized along the OSM tiling scheme.
  
    perl makeElevationFromContour.pl contour:OGF:13:5724-5768:5984-6030

**makeSrtmElevationTile.pl** will reproject the previously generated elevation tiles into 1x1 degree tiles in SRTM *.hgt* format

    perl makeSrtmElevationTile.pl OGF:13 1200 bbox=83,-59,85.001,-57.999

("OGF" is the layer name, 13 again is the zoom level).

**make3dElevation.pl** reprojects the OGF tiles to the format needed for 3D display with Web Worldwind:

    perl make3dElevation.pl level=9 size=256 bbox=83,-59,85.001,-57.999

**convertMapLevel.pl** creates the lower zoom levels for the 3D display and packs them into a ZIP archive.

    perl convertMapLevel.pl -sz 256,256 -zip  elev:WebWW:9:352-364:2992-3015 0


Finally, it's also possible to initiate all the steps above at once by running *ogfElevation.pl* with the  *-c* option:

    perl ogfElevation.pl  -c  13  contours_01.osm  contours_02.osm




## Dependencies

This module requires these other modules and libraries:




## Copyright and Licence

Copyright &copy; 2017 by Thilo Stapff

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.0 or,
at your option, any later version of Perl 5 you may have available.


