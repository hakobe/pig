use strict;
use warnings;
use XML::Feed;
use URI;
use DateTime;
use MooseX::Declare;

my $LAST_UPDATE;
class Pig {
    use Moose;
    use MooseX::POE::SweetArgs qw(event);
    use POE qw(Component::Server::IRC);

    has ircd => (
        is => 'ro',
        default => sub {
            POE::Component::Server::IRC->spawn( config => {
                servername => 'localhost',
                nicklen    => 15,
                network    => 'pig',
            });
        },
    );

    has config => (
        is => 'ro',
        isa => 'HashRef',
        default => sub {
            +{
                bot_name    => 'pig',
                bot_channel => '#pig',
                port        => 6667,
                interval    => 10,
                callback    => sub { # オブジェクトにはき出す
                    my ($ircd, $name, $channel) = @_;
                    my $feed = XML::Feed->parse(URI->new('http://www.hatena.ne.jp/hakobe932/activities.rss'))
                        or die XML::Feed->errstr; # TODO If-Modifed-Since をみて抜けたりする
                    
                    my $has_new = 0;
                    for my $entry ($feed->entries) {
                        next if $LAST_UPDATE > $entry->issued;
                        $has_new++;
                        my $message = sprintf("%s (%s)", $entry->title, $entry->link);
                        warn $message;
                        $ircd->yield( 'daemon_cmd_privmsg', $name, $channel, $message );
                    }
                    #$LAST_UPDATE = DateTime->now(time_zone => 'Asia/Tokyo') if $has_new;
                },
            };
        },
    );

    sub START {
        my ($self) = @_;
        $self->ircd->yield( 'register' );
        $self->ircd->add_listener( port => $self->config->{port} );

        # カウントスタート
        $self->yield( 'count' );

        warn 'starting';
        warn $self->config->{bot_name};
        warn $self->config->{bot_channel};

        $self->_register_bot;
        undef;
    }

    event count => sub {
        my ($self) = @_;
        warn 'counting...';
        $self->config->{callback}->($self->ircd, $self->config->{bot_name}, $self->config->{bot_channel});

        # MooseX::POEを拡張してalarmも呼べるようにしたい!
        POE::Kernel->alarm( count => time() + $self->config->{interval}, 0);
    };

    sub _register_bot {
        my ($self) = @_;

        $self->ircd->yield(add_spoofed_nick => { nick => $self->config->{bot_name} });
        $self->ircd->yield(daemon_cmd_join => $self->config->{bot_name}, $self->config->{bot_channel});
    }

}
Pig->new;
POE::Kernel->run;


