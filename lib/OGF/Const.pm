package OGF::Const;
use strict;
use warnings;


$OGF::TASKSERVICE_SCRIPT = 'C:/usr/MapView/bin/ogfTaskService.pl';
$OGF::TASKSERVICE_DIR  = 'C:/Map/OGF/taskService';
%OGF::TASKSERVICE_ADDR = (
	'tiles' => {
		'file'     => $OGF::TASKSERVICE_DIR . '/tiles/tasklist.txt',
		'options'  => {'interrupt' => 1},
		'commands' => [ 'tile' ],
	},
	'ogfclient' => {
		'file'     => $OGF::TASKSERVICE_DIR . '/ogfclient/tasklist.txt',
		'options'  => {'interrupt' => 0},
		'commands' => [ 'download', 'upload' ],
		'server'   => 'https://opengeofiction.net',
	},
);


$OGF::DATA_FORMAT_MAXWIDTH = 160;

$OGF::WW_ADD_LEVEL = 6;

$OGF::PI  = atan2( 0, -1 );
$OGF::DEG = $OGF::PI / 180;
$OGF::GEO_RAD_AEQ = 6_378_137;
$OGF::GEO_RAD_POL = 6_356_752.314;

$OGF::JOSM_RESOURCE_DIR = 'C:/usr/MapView/josm-tested';
$OGF::JOSM_ELEM_STYLES  = $OGF::JOSM_RESOURCE_DIR . '/styles/standard/elemstyles.xml';

$OGF::DEFAULT_NODE_ICON = 'C:/usr/MapView/OGF/resource/node_01.png';

$OGF::ELEV_UNDEF = -30001;

#$OGF::DISPLAY_PPI = 91;    # pixels per inch
$OGF::DISPLAY_PPI = 94.34;  # pixels per inch, via http://www.sven.de/dpi/
$OGF::DISPLAY_PPM = $OGF::DISPLAY_PPI / .0254;  # pixels per meter  = 3714.17322834646

$OGF::REPLICATION_DIR = '/opt/osm/replicate-05-min';
$OGF::COASTLINE_UPDATE_COMPLETION_FILE = '/var/lib/tirex/tmp/COASTLINE_UPDATE';

#-------------------------------------------------------------------------------

use Config::General;

my $HOME_DIR = ($^O eq 'MSWin32') ? $ENV{'HOMEDRIVE'}.$ENV{'HOMEPATH'} : $ENV{'HOME'};
#print STDERR "\$HOME_DIR <", $HOME_DIR, ">\n";  # _DEBUG_
my %conf = Config::General::ParseConfig( -ConfigFile => 'ogftools.conf', -ConfigPath => ["$HOME_DIR/.ogf","/etc/ogf"] );
#print STDERR "\%conf <", join('|',%conf), ">\n";  # _DEBUG_

$OGF::LAYER_PATH_PREFIX  = $conf{'layer_path_prefix'};
$OGF::TERRAIN_COLOR_MAP  = $conf{'terrain_color_map'};
$OGF::TERRAIN_OUTPUT_DIR = $conf{'terrain_output_dir'};
#print STDERR "\$OGF::LAYER_PATH_PREFIX <", $OGF::LAYER_PATH_PREFIX, ">\n";  # _DEBUG_
#print STDERR "\$OGF::TERRAIN_COLOR_MAP <", $OGF::TERRAIN_COLOR_MAP, ">\n";  # _DEBUG_

# $OGF::LAYER_PATH_PREFIX = ($^O eq 'MSWin32')? 'C:/Map' : '/opt/ogf';
# $OGF::TERRAIN_COLOR_MAP = 'C:/Map/Common/resource/hypsometric/DEM_poster.cpt';
# Download here:  http://soliton.vm.bytemark.co.uk/pub/cpt-city/td/tn/DEM_poster.png.index.html

#$OGF::TERRAIN_COLOR_MAP = 'C:/Map/Common/resource/hypsometric/bath_112_1.cpt';



1;

