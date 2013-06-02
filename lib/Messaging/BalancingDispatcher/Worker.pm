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
use Promises qw(when deferred);
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
	$self->_connect_to_discovery_service();
	$self->advertise();
	$self->request_work() while(1);
	return;
}

sub _connect_to_discovery_service {
	my $self = shift;
	$self->_connect_to_service('discovery', ZMQ_REQ);
}

sub _connect_to_service {
	my ($self, $name, $sock_type) = @_;
	my $endpoint = $self->config->{$name}->{'endpoint'};
	my $socket = $self->sockets->{$name} = zmq_socket($self->zmq, $sock_type);
	zmq_connect($socket, $endpoint);
	$log->debugf("Connected to '%s' service at '%s'", $name, $endpoint);
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

sub request_work {
	my $self = shift;
	send_zmq_message($self->sockets->{'discovery'}, {
		'event' => 'work_requested',
		'node' => $self->node->as_hash,
	});
	$log->debugf("Requested work");
	my $response = receive_zmq_message($self->sockets->{'discovery'});
	$response->{'event'} eq 'work' or die("not a 'work' event");
	$log->debugf("Received work '%s'", $response->{'correlation_id'});
	my $cid = $response->{'correlation_id'};
	when($self->handle_work($response->{'work'}))->then(
		sub {
			my $result = shift;
			$log->debugf("Succesfully processed work '%s'", $response->{'correlation_id'});
			$self->complete_work($result, 'correlation_id' => $cid);
		},
		sub {
			my $result = shift;
			$log->debugf("Failed processing work '%s': '%s'",
				$response->{'correlation_id'}, $result->{'error'});
			$self->complete_work($result, 'correlation_id' => $cid);
		}
	);
}

sub complete_work {
	my ($self, $result, %args) = @_;
	send_zmq_message($self->sockets->{'discovery'}, {
		'event' => 'work_completed',
		'node' => $self->node->as_hash,
		'correlation_id' => $args{'correlation_id'},
		'result' => $result,
	});
	my $response = receive_zmq_message($self->sockets->{'discovery'});
	$response->{'event'} eq 'ack' or die("error advertising node");
	$log->debugf("Completed work '%s'", $args{'correlation_id'});
	return;
}

sub handle_work {
	my ($self, $work) = @_;
	$self->can('_handle_work')
		or die("unable to handle work: " . ref($self) . " does not implement _handle_work");
	my $d = deferred();
	eval {$self->_handle_work($work, $d); 1}
		or $d->reject({'error' => $@});
	return $d->promise;
}

1;

