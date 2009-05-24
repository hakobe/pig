package Pig::Service::FeedReader;
use strict;
use warnings; 

use Any::Moose;
# TODO Pig::Service を Role にする

use Pig::Service::FeedReader::Channel;
use Pig::Service::FeedReader::Feed;
use URI;
use Encode;

has interval => (
    is => 'ro',
    default => sub {
        60 * 30; # 30分
    }
);

has bot_name => (
    is => 'rw',
    isa => 'Str',
    default => sub { 'feed' },
);

has channels => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { [] },
);

sub BUILDARGS {
    my $class = shift;

    my %args;
    if ( scalar(@_) eq 1 && ref $_[0] eq 'HASH') {
        %args = %{ $_[0] };
    }
    else {
        %args = @_;
    }

    my $channels = {};
    my $chs = delete $args{channels};
    for my $key (keys %$chs) {
        my $ch = $chs->{$key};
        my $feeds = [];
        for my $f (@{ $ch->{feeds} }) {
            push @$feeds, Pig::Service::FeedReader::Feed->new(uri => URI->new($f->{uri})); 
        }
        $channels->{$key} = Pig::Service::FeedReader::Channel->new(name => $key, feeds => $feeds);
    }
    $args{channels} = $channels;
    $class->SUPER::BUILDARGS(%args);
}

sub on_start { }

sub on_check {
    my ($self, $pig) = @_;

    $self->check_channel($pig, $_) for ( values %{ $self->channels } );
}

sub check_channel {
    my ($self, $pig, $channel) = @_;
    return unless $channel->is_active;
    $pig->log->debug(sprintf("Checking channel %s.", $channel->name));

    for my $feed (@{ $channel->feeds }) {
        $feed->each_new_entry( $pig, sub { 
            my $entry = shift;
            $pig->log->debug(
                encode_utf8(sprintf( "%s:%s: %s - %s",
                    ($entry->issued || '[no date]'),
                    ($entry->author || '[no name]'),
                    ($entry->title  || '[no title]'),
                    ($entry->link   || '[no link]'))));

            # TODO: メッセージフォーマットをconfigで指定できるよう
            my $message = sprintf("%s %s", ($entry->title || '[no title]'), ($entry->link || '[no url]'));
            $pig->ircd->privmsg( $self->bot_name, $channel->name, $message );
        });
    }

    $pig->log->debug(sprintf("Finish checking channel %s.", $channel->name));
}

sub on_ircd_public {
    my ($self, $pig, $nick, $channel, $message) = @_;
    $self->check_channel($pig, $self->channels->{$channel});
}

sub on_ircd_join {
    my ($self, $pig, $nick, $channel) = @_;
    return if $nick eq $self->bot_name;
    return unless $self->channels->{$channel};

    $self->channels->{$channel}->activate;
    $pig->ircd->join($self->bot_name, $channel);

    $self->check_channel($pig, $self->channels->{$channel});
}

sub on_ircd_part {
    my ($self, $pig, $nick, $channel) = @_;
    return if $nick eq $self->bot_name;
    return unless $self->channels->{$channel};

    $self->channels->{$channel}->deactivate;
    $pig->ircd->part($self->bot_name, $channel);
}

1;
