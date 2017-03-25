package OGF::Util::Usage;
use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure( 'no_ignore_case' );
Getopt::Long::Configure( 'no_auto_abbrev' );
use Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( usageInit usageError );


our $USAGE;
our %EXTENSIONS = initExtensions();

our $INIT_OPTION_DSC = "";
our $INIT_USAGE_TEXT = "";



sub usageInit {
	my( $hOptRef, $optionDsc, $text ) = @_;

	$optionDsc = "$INIT_OPTION_DSC $optionDsc";
	$text      = "$INIT_USAGE_TEXT $text";

	my $progName = $0;
	$progName =~ s|.*[\\/]||;
	$progName =~ s|\.\w+$||;
	$USAGE = "$progName $text";
	$USAGE =~ s/<<PROGNAME>>/$progName/g;

	my @optionDsc = grep {/\S/} split /\s+/, $optionDsc;
#	my( $tagArgs, $tagExt, $tagReq ) = ( '*', '+', '!' );
	my %prep = ( 'Opts' => [], 'Args' => [], 'Ext' => [], 'Req' => [] );
	foreach my $arg ( @optionDsc ){
		if( $arg =~ /^([*+]?)(\w+)(=\w+)?(!?)$/ ){
			my( $categ, $name, $dtype, $req ) = ( $1, $2, $3, $4 );
			push @{$prep{'Req'}}, $name if $req;
			if( ! $categ ){
				push @{$prep{'Opts'}}, $name . (defined($dtype) ? $dtype : '');
			}elsif( $categ eq '*' ){
				push @{$prep{'Args'}}, $name;
			}elsif( $categ eq '+' ){
				push @{$prep{'Ext'}}, $name;
			}
		}else{
			die qq/Invalid option specifier "$arg"/;
		}
	}
#	use Data::Dumper; print STDERR Data::Dumper->Dump( [\%prep], ['prep'] );
	foreach my $tag ( @{$prep{'Ext'}} ){
		push @{$prep{'Opts'}}, @{$EXTENSIONS{$tag}{'options'}};
	}

	usageError() unless GetOptions( $hOptRef, @{$prep{'Opts'}} );
#	use Data::Dumper; print STDERR Data::Dumper->Dump( [$hOptRef], ['opt'] );

	my $errReq = '';
	foreach my $tag ( @{$prep{'Req'}} ){
		$errReq .= qq/Option -$tag must be specified\n/ if ! exists $hOptRef->{$tag};
	}
	usageError($errReq) if $errReq;
	my $n = scalar( @{$prep{'Args'}} );
	for( my $i = 0; $i < $n; ++$i ){
		$hOptRef->{$prep{'Args'}[$i]} = $main::ARGV[$i];
	}
	foreach my $tag ( @{$prep{'Ext'}} ){
		$EXTENSIONS{$tag}{'function'}->( $hOptRef ) if $EXTENSIONS{$tag}{'function'};
	}
}

sub usageError {
	my( $addText ) = @_;
	my $errorText = "usage: $USAGE\n";
	$errorText .= "$addText\n" if defined $addText;
	die $errorText;
}


#-------------------------------------------------------------------------------

sub initExtensions {
    return ();
}




1;

