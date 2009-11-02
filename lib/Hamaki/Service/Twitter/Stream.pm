# retake of AnyEvent::Twitter::Stream;

package Hamaki::Service::Twitter::Stream;
use Moose;
use Moose::Util::TypeConstraints;
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Util;
use JSON;
use MIME::Base64;
use URI;
use List::Util qw(first);
use URI::Escape;
use Carp;
use namespace::clean -except => qw(meta);

my %methods = (
    firehose => [],
    sample   => [],
    filter   => [ qw(track follow) ]
);

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

has on_tweet => (
    is => 'ro',
    isa => 'CodeRef',
    predicate => 'has_on_tweet',
);

has on_error => (
    is => 'ro',
    isa => 'CodeRef',
    lazy_build => 1,
);

has on_eof => (
    is => 'ro',
    isa => 'CodeRef',
    predicate => 'has_on_eof',
);

has args => (
    is => 'ro',
    isa => 'ArrayRef',
    predicate => 'has_args'
);

has connection_guard  => (
    init_arg => undef,
    is => 'ro',
    writer => 'set_connection_guard',
    clearer => 'clear_connection_guard',
);

sub start_filter {
    my $self = shift;

    my $args = $self->args;
    my $uri = URI->new("http://stream.twitter.com/1/statuses/filter.json");
    my @init_args = (
        map { sprintf('%s=%s', $args->[$_ * 2], uri_escape($args->[$_ * 2 + 1])) }
            (0..(@$args/2 - 1))
    );
    $self->start_stream($uri, \@init_args, \&http_post);
}

sub start_stream {
    my ($self, $uri, $init_args, $sender) = @_;
    $sender ||= \&http_get;

    my $username = $self->username;
    my $password = $self->password;
    my $auth = MIME::Base64::encode("$username:$password", '');
    my $guard = $sender->($uri, @$init_args,
        headers => {
            Authorization => "Basic $auth",
            'Content-Type' =>  'application/x-www-form-urlencoded',
            Accept => '*/*'
        },
        on_header => sub {
            my($headers) = @_;
            if ($headers->{Status} ne '200') {
                return $self->on_error->("$headers->{Status}: $headers->{Reason}");
            }
            return 1;
        },
        want_body_handle => 1, # for some reason on_body => sub {} doesn't work :/
        sub {
            my ($handle, $headers) = @_;
            if (! $handle) {
                die "Failed to connect: $headers->{Reason}";
            }
            Scalar::Util::weaken($self);

            if ($handle) {
                $handle->on_error(sub {
                    undef $handle;
                    $self->on_error->(@_);
                });
                $handle->on_eof(sub {
                    undef $handle;
                    $self->on_eof->(@_);
                });
                my $reader; $reader = sub {
                    my($handle, $json) = @_;
                    # Twitter stream returns "\x0a\x0d\x0a" if there's no matched tweets in ~30s.
                    if ($json) {
                        my $tweet = JSON::decode_json($json);
                        $self->on_tweet->($tweet);
                    }
                    $handle->push_read(line => $reader);
                };
                $handle->push_read(line => $reader);
                $self->{guard} = AnyEvent::Util::guard { $self->on_eof->(); $handle->destroy; undef $reader  };
            }
        }
    );
    $self->set_connection_guard( $guard );
}

1;
