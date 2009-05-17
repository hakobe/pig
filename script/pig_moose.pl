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
            };
        },
    );

    has service => (
        is => 'ro',
    );

    sub START {
        my ($self) = @_;
        $self->ircd->yield( 'register' );
        $self->ircd->add_listener( port => $self->config->{port} );

        $self->yield( 'check' );

        warn 'starting';
        warn $self->config->{bot_name};
        warn $self->config->{bot_channel};

        # botをしこむ
        $self->ircd->yield(add_spoofed_nick => { nick => $self->config->{bot_name} });
        $self->ircd->yield(daemon_cmd_join => $self->config->{bot_name}, $self->config->{bot_channel});

        undef;
    }

    event check => sub {
        my ($self) = @_;
        warn 'check...';
        $self->service->on_check($self);

        # MooseX::POEを拡張してalarmも呼べるようにしたい!
        POE::Kernel->alarm( check => time() + $self->service->interval, 0);
    };

}

class Pig::Service::MyHatena { # Role とかにする
    use XML::Feed;
    use DateTime;

    has interval => (
        is => 'ro',
        default => sub {
            60 * 30; # 30分
        }
    );

    has last_update => (
        is => 'rw',
        default => sub {
            DateTime->now(time_zone => 'local');
        }
    );

    sub fix_last_update {
        my $self = shift;
        $self->last_update(DateTime->now(time_zone => 'Asia/Tokyo'));
    }

    sub on_check {
        my ($self, $pig) = @_;

        my $feed = XML::Feed->parse(URI->new('http://www.hatena.ne.jp/hakobe932/activities.rss'))
            or die XML::Feed->errstr; # TODO If-Modifed-Since をみて抜けたりする
        
        my $has_new = 0;
        for my $entry ($feed->entries) {
            next if $self->last_update > $entry->issued;
            $has_new++;
            my $message = sprintf("%s (%s)", $entry->title, $entry->link);
            warn $message;
            $pig->ircd->yield( 'daemon_cmd_privmsg', $pig->config->{bot_name}, $pig->config->{bot_channel}, $message );
        }
        $self->fix_last_update if $has_new;
    }

    # TODO チャンネルのjoinとかいろんなタイミングにhookする
}

Pig->new( service => Pig::Service::MyHatena->new(interval => 5));
POE::Kernel->run;


