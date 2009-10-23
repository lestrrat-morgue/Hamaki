package Hamaki::Service::Superfeedr;
use Moose;
use AnyEvent::Superfeedr;
use Tatsumaki::MessageQueue;
use namespace::clean -except => qw(meta);

extends 'Hamaki::Service';

has jid => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has password => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

sub start {
    my $self = shift;

    # XXX Hmm? is this kosher?
    $XML::Atom::ForceUnicode = 1;

    my $mq = Tatsumaki::MessageQueue->instance("superfeedr");
    my $entry_cb = sub {
        my($entry, $feed_uri) = @_;
        my $host = URI->new($feed_uri)->host;
        $mq->publish({
            type => "message", address => $host, time => scalar localtime,
            name => $entry->title,
            avatar => "http://www.google.com/s2/favicons?domain=$host",
            html  => $entry->summary,
            ident => $entry->link->href,
        });
    };
    my $superfeedr; $superfeedr = AnyEvent::Superfeedr->new(
        debug => 0,
        jid => $self->jid,
        password => $self->password,
        on_notification => sub {
            scalar $superfeedr;
            my $notification = shift;
            for my $entry ($notification->entries) {
                $entry_cb->($entry, $notification->feed_uri);
            }
        },
    );
    warn "Superfeedr channel is available at /chat/superfeedr\n";
}

__PACKAGE__->meta->make_immutable();

1;
