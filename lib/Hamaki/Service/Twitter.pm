package Hamaki::Service::Twitter;
use Moose;
use AnyEvent::HTTP;
use AnyEvent::Twitter;
use AnyEvent::Twitter::Stream;
use Hamaki::Service::Twitter::ChatPostHandler;
use Hamaki::Service::Twitter::Stream;
use MIME::Base64;
use Tatsumaki::MessageQueue;
use Try::Tiny;
use constant MAXBACKLOG => 100;
use namespace::clean -except => qw(meta);

extends 'Hamaki::Service';

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

has use_timeline => (
    is => 'ro', 
    isa => 'Bool',
    default => 0,
);

has client => (
    is => 'ro',
    isa => 'AnyEvent::Twitter',
    lazy_build => 1,
);

sub _build_client {
    my $self = shift;
    return AnyEvent::Twitter->new(
        username => $self->username,
        password => $self->password,
    );
}

override get_handlers => sub {
    my $self = shift;
    my @handlers = super();

    my $name = $self->name;
    foreach my $h (@handlers) {
        if ($h->{path} eq "(?-xism:/chat/($name)/post)") {
            $h->{handler} = 'Hamaki::Service::Twitter::ChatPostHandler';
            $h->{extra_args} = [ service => $self ]
        }
    }
    return @handlers;
};

# This formats for our chat room view
sub format_chat_message {
    my ($self, $text) = @_;

    $text =~ s, (https?://\S+) | (&(?!(?:amp|lt|gt|quot);)) | ([<>"']+) | @([\w_]+) | \#([\w_]+),
        $1 ? do {
            my $url = HTML::Entities::encode($1);
            qq(<a target="_blank" href="$url">$url</a>)
        } :
        $2 ? "&amp;" :
        $3 ? HTML::Entities::encode($3) :
        $4 ? qq(\@<a target="_blank" href="http://twitter.com/$4">$4</a>) :
        $5 ? qq(#<a target="_blank" href="http://twitter.com/search?q=%23$5">$5</a>) :
        ''
    ,egx;

    return $text;
}

sub get_followers {
    my $self = shift;

    my $uri = "http://twitter.com/friends/ids/" . $self->username . ".xml";
    my @followers;
    my %headers = (
        Authorization => "Basic " . encode_base64 (join ':', $self->username, $self->password)
    );

    my $condvar = AnyEvent->condvar;
    my $guard = http_get $uri, \%headers, sub {
        my $xml = shift;
        while ($xml =~ /<id>(\d+)<\/id>/g) {
            push @followers, $1;
        }
        $condvar->send; 
    };

    $condvar->recv; 
    return @followers;
}

sub start {
    my $self = shift;
    my $tweet_cb = sub {
        my $channel = shift;
        my $mq = Tatsumaki::MessageQueue->instance($channel);
        return sub {
            my $tweet = shift;
            return unless $tweet->{user}{screen_name};
            $mq->publish({
                type    => "message",
                address => 'twitter.com',
                time    => scalar localtime,
                name    => $tweet->{user}{name},
                avatar  => $tweet->{user}{profile_image_url},
                text    => $tweet->{text},
                html    => $self->format_chat_message($tweet->{text}),
                ident   => "http://twitter.com/$tweet->{user}{screen_name}/status/$tweet->{id}",
            });
        };
    };

    my @followers = $self->get_followers();
    my $listener; $listener = 
        Hamaki::Service::Twitter::Stream->new(
#AnyEvent::Twitter::Stream->new(
        username => $self->username,
        password => $self->password,
        args => [ follow   => join(',', @followers) ],
        on_tweet => $tweet_cb->("twitter"),
        on_error => sub {
            my $self = shift;
            $self->clear_connection_guard;
            AE::timer 5, 0, sub {
                warn "attempting to reconnect...";
                $self->start_filter();
            };
        },
        on_eof => sub {
            warn "AnyEvent::Twitter::Stream terminated";
            undef $listener;
        },
    );
    $listener->start_filter();

    warn "Twitter stream is available at /chat/twitter\n";

    my $client = $self->client();
    if ( $self->use_timeline ) { # XXX Bad. Bad.
        my $cb = $tweet_cb->("twitter_friends");
        $client->reg_cb(statuses_friends => sub {
            scalar $client;
            my $self = shift;
            for (@_) { $cb->($_->[1]) }
        });
        $client->receive_statuses_friends;
        $client->start;
        warn "Twitter Friends timeline is available at /chat/twitter_friends\n";
    }

    # If messages were not consumed, this process will just keep on 
    # consuming memory. pop the messages once in a while
    AnyEvent->timer(
        after => 60,
        interval => 60, 
        cb => sub { 
            warn "cleanup!";
            my $instance = Tatsumaki::MessageQueue->instance('twitter');
            my $tossed = 0;
            my $backlog = $instance->backlog;
            if (scalar @$backlog > MAXBACKLOG) {
                warn "tossing ". (@$backlog - MAXBACKLOG);
                splice(@$backlog, MAXBACKLOG, scalar @$backlog);
            }
        }
    );
}

1;
