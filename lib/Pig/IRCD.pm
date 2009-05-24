package Pig::IRCD;
use Any::Moose;

use POE qw(Component::Server::IRC);
use POE::Sugar::Args;

has pocosi => (
    is => 'ro',
    default => sub { # TODO BUILD か そのへんでconfigからよみだす
        POE::Component::Server::IRC->spawn( config => {
            servername => 'localhost',
            nicklen    => 15,
            network    => 'pig',
        });
    },
);

has port => (
    is => 'ro',
    isa => 'Int',
    default => sub { 16667 },
);

sub init {
    my ($self, $pig) = @_;

    POE::Session->create(
        object_states => [
            $self => [qw(
                _start           
                check            
                ircd_daemon_public
                ircd_daemon_join 
                ircd_daemon_part 
            )],
        ],
        heap => { pig => $pig },
    );
}

sub run { POE::Kernel->run }

### event listeners

sub _args {
    my $poe = sweet_args;
    ($poe->object, $poe->heap->{pig}, $poe->args);
}

sub _start {
    my ($self, $pig) = _args @_;
    $pig->log->debug("Starting up POE IRCd server.");

    $self->pocosi->yield( 'register' );
    $self->pocosi->add_listener( port => $self->port );

    $pig->service->on_start($pig);
    POE::Kernel->yield( 'check' );
}

sub check {
    my ($self, $pig) = _args @_;

    $pig->log->debug('Start checking.');
    $pig->service->on_check($pig);
    $pig->log->debug('Finish checking.');

    POE::Kernel->alarm( check => time() + $pig->service->interval, 0 );
};

sub ircd_daemon_public {
    my ($self, $pig, $user, $channel, $message) = _args @_;
    $pig->log->debug(qq{$user say "$message" to $channel.});
    my $nick = (split /\!/, $user)[0];

    $pig->service->on_ircd_public($pig, $nick, $channel, $message);
}

sub ircd_daemon_join {
    my ($self, $pig, $user, $channel) = _args @_;

    $pig->log->debug("$user join to $channel.");
    my $nick = (split /\!/, $user)[0];

    $self->pocosi->yield(add_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
    $pig->service->on_ircd_join($pig, $nick, $channel);
};

sub ircd_daemon_part {
    my ($self, $pig, $user, $channel) = _args @_;

    $pig->log->debug("$user part form $channel.");
    my $nick = (split /\!/, $user)[0];

    $self->pocosi->yield(del_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
    $pig->service->on_ircd_part($pig, $nick, $channel);
};

# irc actions

sub privmsg {
    my ($self, $nick, $channel, $message) = @_;
    $self->pocosi->yield(daemon_cmd_privmsg => $nick, $channel, $message );
}

sub join {
    my ($self, $nick, $channel) = @_;
    $self->pocosi->yield(add_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
    $self->pocosi->yield(daemon_cmd_join => $nick, $channel );
}

sub part {
    my ($self, $nick, $channel) = @_;
    $self->pocosi->yield(daemon_cmd_part => $nick, $channel );
    $self->pocosi->yield(del_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
}

1;
