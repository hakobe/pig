package Pig::Service::MyHatena;
use strict;
use warnings; 

use Moose;

use XML::Feed;
use URI;
use DateTime;
use Time::HiRes qw(sleep);
use Encode;

use Pig::Service::FeedReader::Channel;
use Pig::Service::FeedReader::Feed;

use Pig::Service::FeedReader;
extends qw(Pig::Service::FeedReader);

has hatena_id => (
    is => 'ro',
);

sub check_channel { # FIXME FeedReaderとあまりかわらないのでどうにかならないか
    my ($self, $pig, $channel) = @_;
    return unless $channel->is_active;

    my ($bot_name) = $channel->name =~ m/^\#(.*)$/xms;

    for my $feed (@{ $channel->feeds }) {
        $feed->each_new_entry( $pig, sub { 
            my $entry = shift;
            $pig->log->debug(
                encode_utf8(sprintf( "%s: %s - %s",
                    ($entry->author || '[no name]'),
                    ($entry->title  || '[no title]'),
                    ($entry->link   || '[no link]'))));

            my $message = $bot_name eq 'antenna' ?
                sprintf("%s: %s %s", $entry->author, $entry->title, $entry->link)               :
                sprintf("%s %s", ($entry->title || '[no title]'), ($entry->link || '[no url]')) ;
            $pig->privmsg( $bot_name, $channel->name, $message );
        });
    }
}

sub on_ircd_join {
    my ($self, $pig, $nick, $channel_name) = @_;
    return if $self->channels->{$channel_name};

    my ($bot_name) = $channel_name =~ m/^\#(.*)$/xms;

    my $feed_uri = $bot_name eq 'antenna' ?
        sprintf('http://www.hatena.ne.jp/%s/antenna.rss', $self->hatena_id) :
        sprintf('http://www.hatena.ne.jp/%s/activities.rss', $bot_name)  ;

    my $channel = Pig::Service::FeedReader::Channel->new(
        name => $channel_name,
        feeds => [
            Pig::Service::FeedReader::Feed->new(
                uri => URI->new($feed_uri),
            ),
        ]
    );
    $channel->activate;
    $self->channels->{$channel_name} = $channel;
    $pig->join($bot_name, $channel_name);

    $self->check_channel($pig, $channel);
}

sub on_ircd_part {
    my ($self, $pig, $nick, $channel_name) = @_;
    my ($bot_name) = $channel_name =~ m/^\#(.*)$/xms;

    $self->channels->{$channel_name}->deactivate;
    $pig->part($bot_name, $channel_name);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
