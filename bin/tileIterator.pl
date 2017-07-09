#! /usr/bin/perl -w
use strict;
use warnings;
use OGF::LayerInfo;
use OGF::Util::Usage qw( usageInit usageError );


my %opt;
usageInit( \%opt, qq/ bigEndian noRelief /, << "*" );
<action> <layerInfo>
*

my( $ACTION, $LAYER_INFO ) = @ARGV;
usageError() unless $ACTION && $LAYER_INFO;


my $lrInfo = OGF::LayerInfo->tileInfo( $LAYER_INFO );
die qq/ERROR: Cannot parse layer info./ if ! $lrInfo;
#my $tileOrder_N = ($lrInfo->{'layer'} eq 'WebWW')? 1 : 0;
#print STDERR "\$tileOrder_N <", $tileOrder_N, ">\n";  # _DEBUG_


OGF::LayerInfo->tileIterator( $lrInfo, sub {
    my( $item ) = @_;
    my $file = $item->tileName();
	print STDERR $item->{'y'}, " ", $item->{'x'}, " file: ", $file, "\n";  # _DEBUG_
    if( $ACTION eq 'delete' ){
        unlink $file if -f $file;
    }else{
        die qq/Unknown action: $ACTION\n/;
    }
} );



