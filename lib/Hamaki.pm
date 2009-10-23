package Hamaki;
use Moose;
use Plack::Middleware::Static;
use Tatsumaki;
use Tatsumaki::Application;
use Tatsumaki::Error;
use Tatsumaki::HTTPClient;
use Tatsumaki::Middleware::BlockingFallback;
use Hamaki::Filter;
use Hamaki::ChatPollHandler;
use Hamaki::ChatMultipartPollHandler;
use Hamaki::ChatPostHandler;
use Hamaki::ChatRoomHandler;
use Hamaki::MainHandler;
use namespace::clean -except => qw(meta);

our $VERSION = '0.00001';

extends 'Tatsumaki::Application';

has config => (
    is => 'ro',
    isa => 'HashRef',
);

has debug => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has filter => (
    is => 'rw',
    isa => 'Hamaki::Filter',
);

has services => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
);

sub add_service {
    my ($self, $name, $service) = @_;
    $self->services->{$name} = $service;
}

sub BUILDARGS {
    my $class = shift;

    my $rules;
    if (ref $_[0] eq 'ARRAY') {
        $rules = shift @_;
    } else {
        $rules = [];
    }

    my $chat_re = '[\w\.\-]+';
    push @$rules, (
        "/stream"                   => 'Hamaki::StreamWriter',
        "/feed/(\\w+)"              => 'Hamaki::FeedHandler',
        "/chat/($chat_re)/poll"     => 'Hamaki::ChatPollHandler',
        "/chat/($chat_re)/mxhrpoll" => 'Hamaki::ChatMultipartPollHandler',
        "/chat/($chat_re)/post"     => 'Hamaki::ChatPostHandler',
        "/chat/($chat_re)"          => 'Hamaki::ChatRoomHandler',
        "/"                         => 'Hamaki::MainHandler',
    );
    unshift @_, $rules;
    return $class->SUPER::BUILDARGS(@_);
}

sub BUILD {
    my $self = shift;

    $self->template_path( $self->config->{template_path} || './templates' );

    if (my $config = $self->config->{filter}) {
        my $class = delete $config->{class} ;
        Class::MOP::load_class($class);

        $self->filter( $class->new( $config ) );
    }

    # Get the service names that we want, and go go go
    my $services = $self->config->{services};
    while ( my ($name, $config) = each %$services) {
        my $class = delete $config->{class};
        Class::MOP::load_class($class);

        $self->add_service( $name, $class->new($config) );
    }

    return $self;
}

sub to_app {
    my $self = shift;
    my $app = $self->psgi_app;
    $app = Plack::Middleware::Static->wrap($app,
        path => qr/^\/static/,
        root => $self->config->{static_path} || '.'
    );
    $app = Tatsumaki::Middleware::BlockingFallback->wrap($app);

    if ($self->debug) {
        require Plack::Middleware::StackTrace;
        require Plack::Middleware::AccessLog;
        $app = Plack::Middleware::StackTrace->wrap($app);
        $app = Plack::Middleware::AccessLog->wrap($app, logger => sub { print STDERR @_ });
    }

    return $app;
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

Hamaki - Tsunami of tweets based on Tatsumaki

=head1 SYNOPSIS

   tatsunami.pl --configfile=/path/to/file.yaml
   # see eg/sample.yaml

=head1 AUTHOR

Miyagawa Tatsuhiko 

=head1 COPY N' PASTE + SOME FILTERING

Daisuke Maki

=cut