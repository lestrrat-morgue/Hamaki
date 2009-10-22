package Hamaki::Service::Twitter;
use Moose;
use AnyEvent::HTTP;
use MIME::Base64;
use Tatsumaki::MessageQueue;
use Hamaki::ChatPostHandler;
use Try::Tiny;
use namespace::clean -except => qw(meta);

has username => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has password => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

sub BUILD {
    my $self = shift;
    my $tweet_cb = sub {
        my $channel = shift;
        my $mq = Tatsumaki::MessageQueue->instance($channel);
        return sub {
            my $tweet = shift;
            return unless $tweet->{user}{screen_name};
            $mq->publish({
                type   => "message", address => 'twitter.com', time => scalar localtime,
                name   => $tweet->{user}{name},
                avatar => $tweet->{user}{profile_image_url},
                html   => Hamaki::ChatPostHandler->format_message($tweet->{text}), # FIXME
                ident  => "http://twitter.com/$tweet->{user}{screen_name}/status/$tweet->{id}",
            });
        };
    };

    if (try { require AnyEvent::Twitter::Stream }) {
        my $uri = "http://twitter.com/friends/ids/" . $self->username . ".xml";
        my @follow;
        my %headers = (
            Authorization => "Basic " . encode_base64 (join ':', $self->username, $self->password)
        );

        my $condvar = AnyEvent->condvar;
        my $guard = http_get $uri, \%headers, sub {
            my $xml = shift;
            while ($xml =~ /<id>(\d+)<\/id>/g) {
                push @follow, $1;
            }
            $condvar->send; 
        };

        $condvar->recv; 
        my $listener; $listener = AnyEvent::Twitter::Stream->new(
            username => $self->username,
            password => $self->password,
            method   => "filter",
            follow   => join(',', @follow),
            on_tweet => $tweet_cb->("twitter"),
            on_eof => sub {
                warn "AnyEvent::Twitter::Stream terminated";
                undef $listener;
            },
        );

        warn "Twitter stream is available at /chat/twitter\n";
    }

    if (try { require AnyEvent::Twitter }) {
        my $cb = $tweet_cb->("twitter_friends");
        my $client = AnyEvent::Twitter->new(
            username => $self->username,
            password => $self->password,
        );
        $client->reg_cb(statuses_friends => sub {
            scalar $client;
            my $self = shift;
            for (@_) { $cb->($_->[1]) }
        });
        $client->receive_statuses_friends;
        $client->start;
        warn "Twitter Friends timeline is available at /chat/twitter_friends\n";
    }
}

1;
