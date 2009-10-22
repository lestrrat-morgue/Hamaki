
package Tatsunami::ChatPollHandler;
use Moose;
use Tatsumaki::MessageQueue;
use Try::Tiny;
use namespace::clean -except => qw(metA);

extends qw(Tatsumaki::Handler);

__PACKAGE__->asynchronous(1);

sub get {
    my($self, $channel) = @_;
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    my $session = $self->request->param('session')
        or Tatsumaki::Error::HTTP->throw(500, "'session' needed");
    $session = rand(1) if $session eq 'dummy'; # for benchmarking stuff
    $mq->poll_once($session, sub { $self->on_new_event(@_) });
}

sub on_new_event {
    my($self, @events) = @_;

    try {
        # filter the events
        if ( my $filter = $self->application->filter() ) {
            @events = grep { $filter->filter($_) } @events;
        }
    } catch {
        warn "Error while filtering: $_\n";
    };
    $self->write(\@events);
    $self->finish;
}

1;
