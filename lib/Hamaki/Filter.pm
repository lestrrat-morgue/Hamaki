package Hamaki::Filter;
use Moose;
use namespace::clean -except => qw(meta);

sub filter { 1 }

__PACKAGE__->meta->make_immutable();

1;
