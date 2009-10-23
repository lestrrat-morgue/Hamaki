package Hamaki::Service::IRC;
use Moose;
use AnyEvent::IRC::Client;
use Encode ();
use Tatsumaki::MessageQueue;
use namespace::clean -except => qw(meta);

extends 'Hamaki::Service';

has host => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has nickname => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has password => (
    is => 'ro',
    isa => 'Str',
);

has port => (
    is => 'ro',
    isa => 'Str',
    default => 6667,
);

sub start {
    my $self = shift;

    my $irc = AnyEvent::IRC::Client->new;
    $irc->reg_cb(disconnect => sub { warn @_; undef $irc });
    $irc->reg_cb(publicmsg => sub {
        my($con, $channel, $packet) = @_;
        $channel =~ s/\@.*$//; # bouncer (tiarra)
        $channel =~ s/^#//;
        if ($packet->{command} eq 'NOTICE' || $packet->{command} eq 'PRIVMSG') { # NOTICE for bouncer backlog
            my $msg = $packet->{params}[1];
            (my $who = $packet->{prefix}) =~ s/\!.*//;
            my $mq = Tatsumaki::MessageQueue->instance($channel);
            $mq->publish({
                type => "message", address => $self->host, time => scalar localtime,
                name => $who,
                ident => "$who\@gmail.com", # let's just assume everyone's gmail :)
                text => Encode::decode_utf8($msg),
            });
        }
    });
    $irc->connect($self->host, $self->port || 6667, { nick => $self->nickname, password => $self->password });
    warn "Accepting input from IRC at (" . $self->host . ":" . $self->port . ")";
}

__PACKAGE__->meta->make_immutable();

1;