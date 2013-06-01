package Messaging::BalancingDispatcher::Util::ZMQ;
use strict;
use warnings;

use Exporter qw(import);
use JSON v2.0 qw(decode_json encode_json);
use ZMQ::Constants qw(:all);
use ZMQ::LibZMQ3;

our @EXPORT_OK = qw(
	decode_zmq_message
	encode_zmq_message
	receive_zmq_message
	send_zmq_message
);
our %EXPORT_TAGS = (
	'all' => \@EXPORT_OK,
);

sub send_zmq_message {
	my ($socket, $data) = @_;
	my $msg = encode_zmq_message($data);
	zmq_msg_send($msg, $socket) or die("unable to send message: $!");
}

sub receive_zmq_message {
	my ($socket, $msg) = @_;
	$msg ||= zmq_msg_init();
	zmq_msg_recv($msg, $socket) or die("unable to receive mssage: $!");
	return decode_zmq_message($msg);
}

sub decode_zmq_message {
	my ($msg) = @_;
	my $payload = zmq_msg_data($msg);
	return decode_json($payload);
}

sub encode_zmq_message {
	my ($data) = @_;
	my $payload = encode_json($data);
	return zmq_msg_init_data($payload);
}

