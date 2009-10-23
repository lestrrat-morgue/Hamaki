package Hamaki::Service;
use Moose;
use namespace::clean -except => qw(meta);

sub start {}

sub BUILD {
    my $self = shift;
    $self->start();
    return $self;
};

__PACKAGE__->meta->make_immutable();

1;
