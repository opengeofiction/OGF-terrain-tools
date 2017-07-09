package OGF::Data::Node;
use strict;
use warnings;
use OGF::Util;


sub new {
	my( $pkg, $context, $attr ) = @_;

	my $self = {};
	bless $self, $pkg;
	$self->parseAttr( $attr );
	$context->addObject( 'Node', $self );

	return $self;
}

sub class {  'Node';  }

sub uid {  'N|' . $_[0]->{'id'};  }

sub tagMatch {
	return OGF::Data::Context::tagMatch( @_ );
}

sub add_tag {
	my( $self, %args ) = @_;
	map {$self->{'tags'}{$_} = $args{$_}} keys %args;
}

sub toString {
	my( $self ) = @_;
	my $str = join( '|', 'N', $self->{'id'}, $self->{'version'}, $self->{'lon'}, $self->{'lat'} );
	if( $self->{'tags'} ){
		$str .= OGF::Util::tagText( $self->{'tags'} );
	}
	return $str;
}

sub parseAttr {
	my( $self, $str ) = @_;
	if( ref($str) ){
		map {$self->{$_} = $str->{$_}} keys %$str;
		return;
	}

	chomp $str;
	my( $type, $id, $version, $lon, $lat, @tags ) = split /\|/, $str;
	$self->{'id'}      = $id;
	$self->{'version'} = $version;
	$self->{'lon'}     = $lon;
	$self->{'lat'}     = $lat;

	if( @tags ){
		my $hTags = $self->{'tags'} = {};
		map {OGF::Util::tagParse($hTags,$_)} @tags;
	}
}

sub relatedWays {
	my( $self, $ctx ) = @_;
	$ctx = $self->{_context} if ! $ctx;
	$ctx->setReverseInfo();
	my @wayIds = keys %{$ctx->{_rev_info}{$self->uid}};
	print STDERR "\@wayIds <", join('|',@wayIds), ">\n";  # _DEBUG_
	my @ways = map {$ctx->getObject($_)} grep {/^W\|/} @wayIds;
	print STDERR "\@ways <", join('|',@ways), ">\n";  # _DEBUG_
	return @ways;
}







1;

