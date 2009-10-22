package Hamaki::ChatPostHandler;
use Moose;
use Encode ();
use HTML::Entities;
use Tatsumaki::MessageQueue;
use namespace::clean -except => qw(meta);

extends qw(Tatsumaki::Handler);

sub post {
    my($self, $channel) = @_;

    # TODO: decode should be done in the framework or middleware
    my $v = $self->request->params;
    my $text = Encode::decode_utf8($v->{text});
    my $html = $self->format_message($text);
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->publish({
        type => "message", html => $html, ident => $v->{ident},
        avatar => $v->{avatar}, name => $v->{name},
        address => $self->request->address, time => scalar localtime(time),
    });
    $self->write({ success => 1 });
}

sub format_message {
    my($self, $text) = @_;
    $text =~ s{ (https?://\S+) | ([&<>"']+) }
              { $1 ? do { my $url = HTML::Entities::encode($1); qq(<a target="_blank" href="$url">$url</a>) } :
                $2 ? HTML::Entities::encode($2) : '' }egx;
    $text;
}

__PACKAGE__->meta->make_immutable();

1;