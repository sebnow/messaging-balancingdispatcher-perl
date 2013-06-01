package Messaging::BalancingDispatcher::Node;
use base qw(Class::Accessor);
use strict;
use warnings;

use Data::UUID;

__PACKAGE__->mk_accessors(qw(id));

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->id(generate_id()) unless defined($self->id);

	return $self;
}

sub as_hash {
	my ($self) = @_;
	return {
		'id' => $self->id,
	};
}

sub generate_id {
	my $ug = Data::UUID->new();
	return $ug->to_string($ug->create());
}

1;

__END__

=head1 NAME

Messaging::BalancingDispatcher::Node - Worker node

=head1 DESCRIPTION

A structure encapsulating Node data such as the ID.

=head1 SYNOPSIS

	my $node = Messaging::BalancingDispatcher::Node->new();
	print Dumper($node>as_hash);

=cut

