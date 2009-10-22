package Hamaki::Filter::Regexp;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Hamaki::Filter';

has default => (
    is => 'ro',
    isa => 'Bool',
    default => 0
);

has on_match => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has regexp_map => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

sub filter {
    my ($self, $event) = @_;

    my $ok = $self->default;
    my $map = $self->regexp_map;
    while ( my($key, $re) = each %$map ) {
        if ($event->{$key} =~ /$re/) {
            $ok = $self->on_match; last;
        }
    }
    return $ok;
}

__PACKAGE__->meta->make_immutable();

1;

