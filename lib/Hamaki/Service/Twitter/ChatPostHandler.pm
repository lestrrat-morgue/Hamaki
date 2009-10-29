package Hamaki::Service::Twitter::ChatPostHandler;
use utf8;
use Moose;
use Tatsumaki::MessageQueue;
use namespace::clean -except => qw(meta);

extends qw(Tatsumaki::Handler);

has service => (
    is => 'ro',
    isa => 'Hamaki::Service::Twitter',
    required => 1,
);

sub post {
    my($self, $channel) = @_;

    # TODO: decode should be done in the framework or middleware
    my $v = $self->request->params;
    my $text = Encode::decode_utf8($v->{text});

    if ( length($text) > 140 ) {
        return $self->write({ success => 0 });
    }

    $self->service->client->update_status( $text );

    # bring it back to the application
    my $html = $self->service->format_chat_message($text);
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->publish({
        type => "message", html => $html, ident => $v->{ident},
        avatar => $v->{avatar}, name => $v->{name},
        address => $self->request->address, time => scalar localtime(time),
    });
    $self->write({ success => 1 });
}

__PACKAGE__->meta->make_immutable();

1;

