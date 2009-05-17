use strict;
use warnings;
use MooseX::Declare;

class Pig {
    use Moose;
    use MooseX::POE::SweetArgs qw(event);
    use POE qw(Component::Server::IRC);

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

    sub DEFAULT { # FOR DEBUG
        my ( $self, $event, @args ) = @_;
        print STDOUT "$event: ";
        foreach (@args) {
        SWITCH: {
                if ( ref($_) eq 'ARRAY' ) {
                    print STDOUT "[", join ( ", ", @$_ ), "] ";
                    last SWITCH;
                }
                if ( ref($_) eq 'HASH' ) {
                    print STDOUT "{", join ( ", ", %$_ ), "} ";
                    last SWITCH;
                }
                print STDOUT "'$_' ";
            }
        }
        print STDOUT "\n";
        return 0;    # Don't handle signals.
    }

}

class Pig::Service::MyHatena { # Role とかにする
    use XML::Feed;
    use URI;
    use DateTime;
    use Time::HiRes qw(sleep);

    has interval => (
        is => 'ro',
        default => sub {
            60 * 30; # 30分
        }
    );

    has last_updates => (
        is => 'rw',
        isa => 'HashRef',
        default => sub { +{} },
    );

    has hatena_users => (
        is => 'rw',
        isa => 'HashRef',
        default => sub { +{} },
    );

    sub fix_last_update_for {
        my ($self, $user) = @_;
        $self->last_updates->{$user} = DateTime->now(time_zone => 'Asia/Tokyo');
    }

    sub on_check {
        my ($self, $pig) = @_;

        use Data::Dumper;
        warn Dumper [keys %{ $self->hatena_users }];

        for my $hatena_user (keys %{ $self->hatena_users }) {
            # TODO If-Modifed-Since をみて抜けたりする
            my $feed = XML::Feed->parse(URI->new(sprintf('http://www.hatena.ne.jp/%s/activities.rss', $hatena_user)));
            sleep 1; # 適度にまつ

            if (!$feed) {
                warn "$hatena_user fetching rss is failed";
                next;
            }
            if (   $feed->entriese 
                && (reverse($feed->entries))[0]->issued < $self->last_updates->{$hatena_user}) {
                warn "$hatena_user: not updated";
                next;
            }
            
            my $has_new = 0;
            for my $entry (reverse($feed->entries)) {
                $has_new = 1;
                # TODO: メッセージフォーマットをconfigで指定できるよう
                my $message = sprintf("%s (%s)", $entry->title, $entry->link);
                $pig->privmsg( $hatena_user, "#$hatena_user", $message );
            }
            $self->fix_last_update_for($hatena_user) if $has_new;
        }
    }

    sub on_ircd_join {
        my ($self, $pig, $nick, $channel) = @_;
        my ($hatena_user) = $channel =~ m/^\#(.*)$/xms;
        return if $self->hatena_users->{$nick};

        $pig->join($hatena_user, "#$hatena_user");
        $self->hatena_users->{$hatena_user} = 1;
    }

    sub on_ircd_part {
        my ($self, $pig, $nick, $channel) = @_;
        my ($hatena_user) = $channel =~ m/^\#(.*)$/xms;
        return if $self->hatena_users->{$nick};

        $pig->part($hatena_user, "#$hatena_user");
        delete $self->hatena_users->{$hatena_user};
    }
}

Pig->new( service => Pig::Service::MyHatena->new(interval => 5));
POE::Kernel->run;


