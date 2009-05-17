package Pig;
use strict;
use warnings;

our $VERSION = '0.01';

use POE qw(Component::Server::IRC);
use Moose;
use MooseX::POE::SweetArgs qw(event);


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

has config => ( # TODO ファイルからとか呼び出せるように
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        +{
            port        => 6667,
        };
    },
);

has service => (
    is => 'ro',
);

sub run {
    POE::Kernel->run;
}

sub START {
    my ($self) = @_;
    $self->ircd->yield( 'register' );
    $self->ircd->add_listener( port => $self->config->{port} );

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
    warn 'check...';
    $self->service->on_check($self);

    # TODO MooseX::POEを拡張してalarmも呼べるようにしたい
    POE::Kernel->alarm( check => time() + $self->service->interval, 0);
};

event ircd_daemon_join => sub {
    my ($self, $user, $channel) = @_;
    my $nick = (split /\!/, $user)[0];

    $self->ircd->yield(add_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
    $self->service->on_ircd_join($self, $nick, $channel);
};

event ircd_daemon_part => sub {
    my ($self, $user, $channel) = @_;
    my $nick = (split /\!/, $user)[0];

    $self->ircd->yield(del_spoofed_nick => { nick => $nick }); # Po::Co::Server::IRCD だと必要
    $self->service->on_ircd_part($self, $nick, $channel);
};

#    sub DEFAULT { # FOR DEBUG
#        my ( $self, $event, @args ) = @_;
#        print STDOUT "$event: ";
#        foreach (@args) {
#        SWITCH: {
#                if ( ref($_) eq 'ARRAY' ) {
#                    print STDOUT "[", join ( ", ", @$_ ), "] ";
#                    last SWITCH;
#                }
#                if ( ref($_) eq 'HASH' ) {
#                    print STDOUT "{", join ( ", ", %$_ ), "} ";
#                    last SWITCH;
#                }
#                print STDOUT "'$_' ";
#            }
#        }
#        print STDOUT "\n";
#        return 0;    # Don't handle signals.
#    }

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

Pig is

=head1 AUTHOR

Yohei Fushii E<lt>hakobe@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
