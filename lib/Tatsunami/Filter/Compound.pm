package Tatsunami::Filter::Compound;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Tatsunami::Filter';

has filters => (
    is => 'ro',
    isa => 'ArrayRef[Tsunami::Filter]',
    required => 1,
);

sub filter {
    my ($self, $event) = @_;

    foreach my $filter ( @{ $self->filters } ) {
        $filter->($event) or return;
    }

    return 1;
}

__PACKAGE__->meta->make_immutable();

1;
