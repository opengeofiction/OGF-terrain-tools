package OGF::TileUtil;

require 5.005_62;
use strict;
use warnings;

require Exporter;
require DynaLoader;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter DynaLoader);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use OGF::TileUtil ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	printTest
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(  );

our $VERSION = '0.01';

bootstrap OGF::TileUtil $VERSION;

# Preloaded methods go here.


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

OGF::TileUtil - Perl extension

=head1 SYNOPSIS

  use OGF::TileUtil;
  OGF::TileUtil::makeStruct( typeName, defString );

=head1 DESCRIPTION


=head2 EXPORT

None by default.


=head1 AUTHOR

Thilo Stapff

=head1 SEE ALSO

perl(1).

=cut
