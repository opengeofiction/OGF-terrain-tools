package OGF::Data::Changeset;
use strict;
use warnings;
use OGF::Util;


sub new {
	my( $pkg, $context, $attr ) = @_;

	my $self = {};
	bless $self, $pkg;
	$self->parseAttr( $attr );
	$context->addObject( 'Changeset', $self );

	return $self;	
}

sub class {  'Changeset';  }

sub uid {  'C|' . $_[0]->{'id'};  }

sub tagMatch {
	my( $self, $hMatch ) = @_;
	return OGF::Data::Context::tagMatch( $self, $hMatch );
}

sub add_tag {
	my( $self, %args ) = @_;
	map {$self->{'tags'}{$_} = $args{$_}} keys %args;
}

#sub toString {
#	my( $self ) = @_;
#	my $str = join( '|', 'W', $self->{'id'}, $self->{'version'} );
#	if( $self->{'tags'} ){
#		$str .= OGF::Util::tagText( $self->{'tags'} );
#	}
#	if( $self->{'nodes'} ){
#		$str .= '|'. join( '|', @{$self->{'nodes'}} ); 
#	}
#	return $str;
#}

sub parseAttr {
	my( $self, $str ) = @_;
	if( ref($str) ){	
		map {$self->{$_} = $str->{$_}} keys %$str;
		return;
	}

	die qq/OGF parsing not yet implemented for changesets !!!/;
#	chomp $str;
#	my( $type, $id, $version, @list ) = split /\|/, $str;
#	$self->{'id'}      = $id;
#	$self->{'version'} = $version;
#	my $hTags  = $self->{'tags'}  = {};
#	my $aNodes = $self->{'nodes'} = [];
#
#	foreach my $item ( @list ){
#		if( $item !~ /^-?\d/ ){
#			OGF::Util::tagParse( $hTags, $item );
#		}else{
#			push @$aNodes, $item;
#		}
#	}
}



1;


