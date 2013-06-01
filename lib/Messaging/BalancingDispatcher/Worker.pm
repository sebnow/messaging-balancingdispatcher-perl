package Messaging::BalancingDispatcher::Worker;
use base qw(Class::Accessor);
use strict;
use warnings;

use AE;
use Const::Fast;
use JSON qw(decode_json encode_json);
use Log::Any qw($log);
use Messaging::BalancingDispatcher::Node;
use Messaging::BalancingDispatcher::Util::ZMQ qw(:all);
use ZMQ::Constants qw(:all);
use ZMQ::LibZMQ3;

__PACKAGE__->mk_ro_accessors(qw(watchers sockets zmq config node));

const my $DISCOVERY_ENDPOINT => "tcp://127.0.0.1:31337";

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{'config'} ||= {
		'discovery' => {
			'endpoint' => $DISCOVERY_ENDPOINT,
		},
	};
	$self->{'sockets'} ||= {};
	$self->{'watchers'} ||= {};
	$self->{'node'} ||= Messaging::BalancingDispatcher::Node->new();

	return $self;
}

sub init {
	my $self = shift;
	$self->{'zmq'} = zmq_init();
}

sub run {
	my $self = shift;
	$self->init();
	$self->connect_to_discovery_service();
	$self->advertise();
	AE::cv->recv();
	return;
}

sub connect_to_discovery_service {
	my $self = shift;
	my $socket = $self->sockets->{'discovery'} = zmq_socket($self->zmq, ZMQ_REQ);
	zmq_connect($socket, $self->config->{'discovery'}->{'endpoint'});
	$log->debugf("Connected to discovery service at '%s'", $self->config->{'discovery'}->{'endpoint'});
}

sub advertise {
	my $self = shift;
	send_zmq_message($self->sockets->{'discovery'}, {
		'event' => 'advertisement',
		'node' => $self->node->as_hash,
	});
	my $response = receive_zmq_message($self->sockets->{'discovery'});
	$response->{'event'} eq 'ack' or die("error advertising node");
	$log->debugf("Advertised as node '%s'", $self->node->id);
}

1;

