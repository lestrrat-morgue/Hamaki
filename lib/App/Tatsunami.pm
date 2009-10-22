package App::Tatsunami;
use Moose;
use Tatsumaki::Server;
use Tatsunami;
use Try::Tiny;

with qw(MooseX::Getopt MooseX::SimpleConfig);

has config => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

has debug => (
    is => 'ro',
    isa => 'Bool',
    default => 0
);

sub run {
    my $self = shift;

    my $tatsunami = Tatsunami->new(
        debug => $self->debug,
        config => $self->config
    );

    try {
        my $app = $tatsunami->to_app;
        Tatsumaki::Server
            ->new(port => $self->config->{port} || 9999)
            ->run( $app );
    } catch {
        warn "An error occured: $_";
    }
}

1;
