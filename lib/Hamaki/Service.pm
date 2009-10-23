package Hamaki::Service;
use Moose;
use namespace::clean -except => qw(meta);

has name => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

sub get_handlers {
    my $self = shift;
    my $name = $self->name;
    return (
        {
            path => qr{^/chat/($name)/poll},
            handler => 'Hamaki::ChatPollHandler'
        },
        {
            path => qr{/chat/($name)/mxhrpoll},
            handler => 'Hamaki::ChatMultipartPollHandler',
        },
        {
            path => qr{/chat/($name)/post},
            handler => 'Hamaki::ChatPostHandler',
        },
        {
            path => qr{/chat/($name)},
            handler => 'Hamaki::ChatRoomHandler',
        }
    )
}


sub start {}

sub BUILD {
    my $self = shift;
    $self->start();
    return $self;
};

__PACKAGE__->meta->make_immutable();

1;
