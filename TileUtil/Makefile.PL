use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.


# perl Makefile.PL LIB=C:/usr/MapView

#$MSVC_LIBS = ($^O eq 'MSWin32') ? "\"-Lc:\\Programme\\Mic\\Vc98\\lib\"" : '';


WriteMakefile(
    'NAME'		    => "OGF::TileUtil",
    'VERSION_FROM'	=> "TileUtil.pm", # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    'LIBS'			=> [],  #  "$MSVC_LIBS" ],
    'OBJECT' => q[ TileUtil$(OBJ_EXT) tile_util$(OBJ_EXT) ],
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'INC'			=> "",
);


