package OGF::Data::XML;
use strict;
use warnings;
use OGF::Data::Context;
use OGF::Data::Node;
use OGF::Data::Way;
use OGF::Data::Relation;
use OGF::Data::Changeset;
use base qw( XML::SAX::Base );



our @COMMON_ATTR = qw/ id version action timestamp user /;
our %CLASS_ATTR = (
	'node'      => [ @COMMON_ATTR, qw/lon lat/ ],
	'way'       => [ @COMMON_ATTR ],
	'relation'  => [ @COMMON_ATTR ],
	'changeset' => [ qw/id user uid created_at closed_at min_lon min_lat max_lon max_lat/ ],
);


sub new {
	my( $pkg, %args ) = @_;
	my $self = $pkg->SUPER::new();
#	print STDERR "\$self <", $self, ">\n";  # _DEBUG_

	$self->{_OGF_context} = $args{'context'} || OGF::Data::Context->dummyContext();
	$self->{_OGF_process} = $args{'process'} if $args{'process'};
	$self->{_OGF_currentObj}    = undef;
	$self->{_OGF_currentAction} = undef;
	$self->{_OGF_statistics} = {};

	return $self;
}

sub start_element {
	my( $self, $elem ) = @_;
#	use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [$elem], ['elem'] ), "\n";
#	print STDERR $elem->{'LocalName'}, "\n";
	my $name = $elem->{'LocalName'};
	if( $name =~ /^(node|way|relation|changeset)$/ ){
		my $class = 'OGF::Data::'. uc(substr($name,0,1)) . substr($name,1);
#		my @nodeAttr = ($name eq 'node')? ('lon','lat') : ();
		my $hAttr = convertAttr( $elem, @{$CLASS_ATTR{$name}} );
		$self->{_OGF_currentObj} = $class->new( $self->{_OGF_context}, $hAttr );
		++$self->{_OGF_statistics}{$name};
	}elsif( $name eq 'tag' ){
		my $hAttr = convertAttr( $elem, 'k', 'v' );
		$self->{_OGF_currentObj}->add_tag( $hAttr->{'k'}, $hAttr->{'v'} );
	}elsif( $name eq 'nd' ){
		my $hAttr = convertAttr( $elem, 'ref' );
		$self->{_OGF_currentObj}->add_node( $hAttr->{'ref'} );
	}elsif( $name eq 'member' ){
		my $hAttr = convertAttr( $elem, 'type', 'role', 'ref' );
		$self->{_OGF_currentObj}->add_member( $hAttr );
	}elsif( $name eq 'bounds' ){
		my $hAttr = convertAttr( $elem, qw/minlon minlat maxlon maxlat/ );
		$self->{_OGF_bbox} = [ map {$hAttr->{$_}} qw/minlon minlat maxlon maxlat/ ];
	}elsif( $name =~ /^(create|modify|delete)$/ ){
		$self->{_OGF_currentAction} = $name;
	}
}

sub end_element {
	my( $self, $elem ) = @_;
	my $name = $elem->{'LocalName'};
	if( $name =~ /^(node|way|relation)$/ ){
#		use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [$self->{_OGF_currentObj}], ['self->{_OGF_currentObj}'] ), "\n";  # _DEBUG_
		$self->{_OGF_process}->( $self->{_OGF_currentObj}, $self ) if $self->{_OGF_process};
		$self->{_OGF_currentObj} = undef;
	}
	if( $name =~ /^(create|modify|delete)$/ ){
		$self->{_OGF_currentAction} = undef;
	}
}

sub convertAttr {
	my( $elem, @attr ) = @_;
	my %val;
	foreach my $attr ( @attr ){
		$val{$attr} = $elem->{'Attributes'}{'{}'.$attr}{'Value'};
		$val{$attr} =~ s/^(.)/uc($1)/e if $attr eq 'type';
	}
	return \%val;
}




1;

