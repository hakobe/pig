use strict;
use warnings;
use POE qw(Component::Server::IRC);
use XML::Feed;
use URI;
use DateTime;

my $ircd = POE::Component::Server::IRC->spawn( config => {
    servername => 'localhost',
    nicklen    => 15,
    network    => 'pig',
});


my $LAST_UPDATE = DateTime->now(time_zone => 'Asia/Tokyo');
POE::Session->create(
    inline_states => {
        _start             => \&_start,
        counter            => \&counter,
    },
    heap => { 
        ircd   => $ircd,
        config => { # TODO objectの設定にはきだす => Moose?
            bot_name    => 'pig',
            bot_channel => '#pig',
            port        => 6667,
            interval    => 10,
            callback    => sub {
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
                $LAST_UPDATE = DateTime->now(time_zone => 'Asia/Tokyo') if $has_new;
            },
        },
    },
);

$poe_kernel->run;
exit 0;


sub _start {
    my ($kernel,$heap) = @_[KERNEL,HEAP];
    my $ircd = $heap->{ircd};
    my $config = $heap->{config};
    $ircd->yield( 'register' );
    $ircd->add_listener( port =>  $config->{port} );

    # カウントスタート
    $kernel->yield( 'counter' );


    warn 'starting';
    warn "$config->{bot_name}, $config->{bot_channel}";

    register_bot($ircd, $config->{bot_name}, $config->{bot_channel});
    undef;
}

sub register_bot {
    my ($ircd, $name, $channel) = @_; # TODO object_statesにしてheapを渡す必要がないようにしよう

    $ircd->yield(add_spoofed_nick => { nick => $name });
    $ircd->yield(daemon_cmd_join => $name, $channel);
}

sub counter {
    my ($kernel,$heap) = @_[KERNEL,HEAP];
    my $ircd = $heap->{ircd};
    my $config = $heap->{config};
    warn 'counting...';
    $config->{callback}->($ircd, $config->{bot_name}, $config->{bot_channel});
    $kernel->alarm( counter => time() + $config->{interval}, 0);
}

# for debug
sub _default {
    my ( $event, $args ) = @_[ ARG0 .. $#_ ];
    print STDOUT "$event: ";
    foreach (@$args) {
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
