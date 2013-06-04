package Messaging::BalancingDispatcher;
use strict;
use warnings;

our $VERSION = v0.0.1;

1;

=head1 NAME

Messaging::BalancingDispatcher - Master-Worker messaging pattern

=head1 DESCRIPTION

An implementation of the Master-Worker messaging pattern for
distributing work, only to nodes that can work on it immediately.

This pattern enables increasing the capacity of the system by the
addition of L<Workers|Messaging::BalancingDispatcher::Worker>
dynamically.

=head1 AUTHORS

=over

=item Sebastian Nowicki <sebnow@gmail.com>

=back

=cut

