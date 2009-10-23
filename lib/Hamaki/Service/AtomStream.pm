package Hamaki::Service::AtomStream;
use Moose;
use AnyEvent::Atom::Stream;
use namespace::clean -except => qw(meta);

extends 'Hamaki::Service';

sub start {
    my $self = shift;

    my $mq = Tatsumaki::MessageQueue->instance("sixapart");
    my $entry_cb = sub {
        my $feed = shift;
        my $host = URI->new($feed->link->href)->host;
        for my $entry ($feed->entries) {
            $mq->publish({
                type => "message", address => $host, time => scalar localtime,
                name => $feed->title,
                avatar => "http://www.google.com/s2/favicons?domain=$host",
                html  => $entry->title,
                ident => $entry->link->href,
            });
        }
    };
    my $client; $client = AnyEvent::Atom::Stream->new(
        callback => $entry_cb,
        on_disconnect => sub { delete $client->{_guard} },
    );
    $client->{_guard} = $client->connect("http://updates.sixapart.com/atom-stream.xml");
    warn "Six Apart update stream is available at /chat/sixapart\n";
}

__PACKAGE__->meta->make_immutable();

1;
