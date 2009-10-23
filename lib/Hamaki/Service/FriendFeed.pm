package Hamaki::Service::FriendFeed;
use Moose;
use AnyEvent::FriendFeed::Realtime;
use namespace::clean -except => qw(meta);

extends 'Hamaki::Service';

has username => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

sub start {
    my $self = shift;

    my $mq = Tatsumaki::MessageQueue->instance("friendfeed");
    my $entry_cb = sub {
        my $entry = shift;
        $mq->publish({
            type => "message", address => 'friendfeed.com', time => scalar localtime,
            name => $entry->{from}{name},
            avatar => "http://friendfeed-api.com/v2/picture/$entry->{from}{id}",
            html => $entry->{body},
            ident => $entry->{url},
        });
    };

    my $client; $client = AnyEvent::FriendFeed::Realtime->new(
        request => "/feed/" . $self->username . "/friends",
        on_entry => $entry_cb,
        on_error => sub { $client },
    );
    warn "FriendFeed stream is available at /chat/friendfeed\n";
}

__PACKAGE__->meta->make_immutable();

1;

