package Messaging::BalancingDispatcher::Master;
use base qw(Class::Accessor);
use strict;
use warnings;

use AE;
use Const::Fast;
use Log::Any qw($log);
use Messaging::BalancingDispatcher::Node;
use Messaging::BalancingDispatcher::Util::ZMQ qw(:all);
use ZMQ::Constants qw(:all);
use ZMQ::LibZMQ3;

__PACKAGE__->mk_ro_accessors(qw(watchers sockets zmq nodes config));
const my %EVENT_HANDLERS => (
	'advertisement' => \&handle_advertisment,
);

const my %RESPONSES => (
	'ack' => {
		event => 'ack',
	},
);

# FIXME Make this config driven
const my $DISCOVERY_ENDPOINT => "tcp://127.0.0.1:31337";

sub new {
	my ($proto) = @_;
	my $class = ref($proto) || $proto;
	my $self = bless({}, $class);

	$self->{'config'} ||= {
		'discovery' => {
			'endpoint' => $DISCOVERY_ENDPOINT,
		},
	};
	$self->{'sockets'} ||= {};
	$self->{'watchers'} ||= {};
	$self->{'nodes'} ||= {};
	$self->{'event_handlers'} = {};

	return $self;
}

sub init {
	my $self = shift;
	$self->{'zmq'} = zmq_init();
	return $self;
}

sub run {
	my $self = shift;
	$self->init();
	$self->_start_discovery_service();
	AE::cv->recv();
	return;
}

sub _start_discovery_service {
	my $self = shift;
	my $endpoint = $self->config->{'discovery'}->{'endpoint'};

	my $socket = $self->sockets->{'discovery'} = zmq_socket($self->zmq, ZMQ_REP);
	zmq_bind($socket, $endpoint);
	my $fh = zmq_getsockopt($socket, ZMQ_FD);

	$self->watchers->{'discovery'} = AE::io $fh, 0, sub {
		my $msg = zmq_msg_init();
		while (my $data = receive_zmq_message($socket, $msg)) {
			my $response = $self->handle_event(delete($data->{'event'}), $data);
			send_zmq_message($socket, $response);
		}
		delete $self->watchers->{'discovery'};
	};
	$log->debugf("Initialised node discovery service at '%s'", $endpoint);
}

sub handle_event {
	my ($self, $event, $message) = @_;
	$log->trace("Executing handler for event '$event'");
	return $EVENT_HANDLERS{$event}->($self, $message);
}

sub handle_advertisment {
	my ($self, $message) = @_;
	my $node = Messaging::BalancingDispatcher::Node->new($message->{'node'});
	$log->debugf("Discovered node '%s'", $node->id);
	$self->add_node($node);
	return $RESPONSES{'ack'};
}

sub add_node {
	my ($self, $node) = @_;
	$self->nodes->{$node->id} = $node;
}

1;

