package Tatsunami::MainHandler;
use base qw(Tatsumaki::Handler);

sub get {
    my $self = shift;
    $self->write("Hello World");
}

1;
