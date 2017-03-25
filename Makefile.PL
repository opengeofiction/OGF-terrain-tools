use 5.016000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'OGF',
    VERSION_FROM      => 'lib/OGF.pm', # finds $VERSION
    PREREQ_PM         => {
        'POSIX'                  => 0,
        'Geo::Proj4'             => 0,
        'Math::Trig'             => 0,
        'XML::SAX'               => 0,
        'Archive::Zip'           => 0,
        'IO::Scalar'             => 0,
        'IO::Uncompress::Gunzip' => 0,
        'Time::HiRes'            => 0,
        'Time::Local'            => 0,
        'Data::Dumper'           => 0,
        'Date::Format'           => 0,
        'Date::Parse'            => 0,
        'Tk'                     => 0,
        'LWP'                    => 0,
        'URI::Escape'            => 0,
        'HTML::Entities'         => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/OGF.pm', # retrieve abstract from module
       AUTHOR         => 'Thilo Stapff <info@opengeofiction.net>') : ()),
);
