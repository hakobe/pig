package Pig::Service::MyHatena;
use strict;
use warnings; 

use XML::Feed;
use URI;
use DateTime;
use Time::HiRes qw(sleep);

use Moose;
# TODO Pig::Service を Role にする

has interval => (
    is => 'ro',
    default => sub {
        60 * 30; # 30分
    }
);

has hatena_id => (
    is => 'ro',
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

sub on_start { }

sub on_check {
    my ($self, $pig) = @_;

    $self->check_antenna($pig);
    $self->check_hatena_user($pig);
}

# TODO いまはほとんどcheck_hatena_userと一緒だけど author の扱い方で結構かわってきそうだ
sub check_antenna {
    my ($self, $pig) = @_;
    return unless $pig->ircd->state_chan_exists('#antenna');
    warn "checking antenna";

    my $rss_uri = URI->new(sprintf('http://www.hatena.ne.jp/%s/antenna.rss', $self->hatena_id));

    # TODO If-Modifed-Since をみて抜けたりする
    my $feed = XML::Feed->parse($rss_uri);
    sleep 1; # 適度にまつ

    if (!$feed) {
        warn "antenna: fetching rss is failed";
        return;
    }
        
    my $has_new = 0;
    for my $entry (reverse($feed->entries)) {
        next if $self->last_updates->{antenna} 
                && $entry->issued < $self->last_updates->{antenna};

        $has_new = 1;
        # TODO メッセージフォーマットをconfigで指定できるよう
        my $message = sprintf("%s: %s %s", $entry->author, $entry->title, $entry->link);
        # TODO authorが発言できるとなお良い => anntenaのユーザのみを管理する必要
        $pig->privmsg( 'antenna', "#antenna", $message );
    }
    $self->fix_last_update_for('antenna') if $has_new;
}

sub check_hatena_user {
    my ($self, $pig) = @_;
    warn "checking: " . (join ", ", keys %{ $self->hatena_users }) if keys %{ $self->hatena_users };

    for my $hatena_user (keys %{ $self->hatena_users }) {
        my $rss_uri = URI->new(sprintf('http://www.hatena.ne.jp/%s/activities.rss', $hatena_user))  ;

        # TODO If-Modifed-Since をみて抜けたりする
        my $feed = XML::Feed->parse($rss_uri);
        sleep 1; # 適度にまつ

        if (!$feed) {
            warn "$hatena_user fetching rss is failed";
            next;
        }
        
        my $has_new = 0;
        for my $entry (reverse($feed->entries)) {
            next if $self->last_updates->{$hatena_user} 
                 && $entry->issued < $self->last_updates->{$hatena_user};

            $has_new = 1;
            # TODO: メッセージフォーマットをconfigで指定できるよう
            my $message = sprintf("%s %s", ($entry->title || '[no title]'), ($entry->link || '[no url]'));
            $pig->privmsg( $hatena_user, "#$hatena_user", $message );
        }
        $self->fix_last_update_for($hatena_user) if $has_new;
    }
}

# TODO このへんのantennaの扱いをまともに

sub on_ircd_join {
    my ($self, $pig, $nick, $channel) = @_;
    my ($hatena_user) = $channel =~ m/^\#(.*)$/xms;
    return if $nick eq 'antenna';
    return if $self->hatena_users->{$nick};

    $pig->join($hatena_user, "#$hatena_user");
    $self->hatena_users->{$hatena_user} = 1 if $hatena_user ne 'antenna';
}

sub on_ircd_part {
    my ($self, $pig, $nick, $channel) = @_;
    my ($hatena_user) = $channel =~ m/^\#(.*)$/xms;
    return if $nick eq 'antenna';
    return if $self->hatena_users->{$nick};

    $pig->part($hatena_user, "#$hatena_user");
    delete $self->hatena_users->{$hatena_user} if $hatena_user ne 'antenna';
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
