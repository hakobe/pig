package Pig;
use strict;
use warnings;

our $VERSION = '0.01';

use Moose;
use UNIVERSAL::require;

# POE
use MooseX::POE::SweetArgs qw(event);
use POE qw(Component::Server::IRC);

# Log
use Log::Log4perl qw(:easy);

with 'MooseX::Log::Log4perl';

has ircd => (
    is => 'ro',
    default => sub { # TODO BUILD か そのへんでconfigからよみだす
        POE::Component::Server::IRC->spawn( config => {
            servername => 'localhost',
            nicklen    => 15,
            network    => 'pig',
        });
    },
);

has log_level => (
    is => 'ro',
    isa => 'Str',
    default => sub { 'info' },
);

has port => (
    is => 'ro',
    isa => 'Int',
    default => sub { 16667 },
);

has service => (
    is => 'ro',
);

sub bootstrap {
    my ($class, $config) = @_;
    my $service_config = delete $config->{service};
    my $service = $class->prepare_service($service_config);

    my $self = $class->new({service => $service, %$config});
    $self->run;
}


sub prepare_service {
    my ($class, $service_config) = @_;
    my $name = delete $service_config->{name};
    my $service_class = 'Pig::Service::' . $name;
    eval {
        $service_class->use;
    };
    if ($@) { die "use $service_class failed: $@" }

    return $service_class->new($service_config);
}

sub BUILD {
    my $self = shift;
    Log::Log4perl->easy_init( {
        ALL    => $ALL,
        TRACE  => $TRACE,
        DEBUG  => $DEBUG,
        INFO   => $INFO,
        WARN   => $WARN,
        ERROR  => $ERROR,
        FATAL  => $FATAL,
        OFF    => $OFF,
    }->{uc($self->log_level)});
}

# TODO 以下の機能はPig::IRCDとかにはき出す予定

sub run { 
    my $self = shift;
    my $service_name = ref $self->service;
    $self->log->info("Starting up pig with $service_name.");
    POE::Kernel->run;
}

sub START {
    my ($self) = @_;
    $self->log->debug("Starting up POE IRCd server.");
    $self->ircd->yield( 'register' );
    $self->ircd->add_listener( port => $self->port );

    $self->service->on_start($self);
    $self->yield( 'check' );
}

sub privmsg {
    my ($self, $nick, $channel, $message) = @_;
    $self->ircd->yield(daemon_cmd_privmsg => $nick, $channel, $message );
}

sub join {
    my ($self, $nick, $channel) = @_;
    $self->ircd->yield(add_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
    $self->ircd->yield(daemon_cmd_join => $nick, $channel );
}

sub part {
    my ($self, $nick, $channel) = @_;
    $self->ircd->yield(daemon_cmd_part => $nick, $channel );
    $self->ircd->yield(del_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
}

event check => sub {
    my ($self) = @_;
    $self->log->debug('Start checking.');
    $self->service->on_check($self);
    $self->log->debug('Finish checking.');

    # TODO MooseX::POEを拡張してalarmも呼べるようにしたい
    POE::Kernel->alarm( check => time() + $self->service->interval, 0);
};

event ircd_daemon_join => sub {
    my ($self, $user, $channel) = @_;
    $self->log->debug("$user join to $channel.");
    my $nick = (split /\!/, $user)[0];

    $self->ircd->yield(add_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
    $self->service->on_ircd_join($self, $nick, $channel);
};

event ircd_daemon_part => sub {
    my ($self, $user, $channel) = @_;
    $self->log->debug("$user part form $channel.");
    my $nick = (split /\!/, $user)[0];

    $self->ircd->yield(del_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
    $self->service->on_ircd_part($self, $nick, $channel);
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;
__END__

=encoding utf8

=head1 NAME

Pig -

=head1 SYNOPSIS

  use Pig;

=head1 DESCRIPTION

Pig is Perl IRC Gateway framework

=head1 AUTHOR

Yohei Fushii E<lt>hakobe@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
