package Pig::Service::FeedReader::Feed;
use strict;
use warnings;
use Moose;
use XML::Feed;
use URI;
use DateTime;
use Time::HiRes qw(sleep);

has uri => (
    is => 'ro',
    isa => 'URI'
);

has last_update => (
    is => 'rw',
    isa => 'DateTime',
);

sub fix_last_update {
    my ($self, $user) = @_;
    $self->last_update(DateTime->now(time_zone => 'Asia/Tokyo'));
}

sub each_new_entry {
    my ($self, $code) = @_;

    # TODO If-Modifed-Since をみて抜けたりする
    my $xml_feed = XML::Feed->parse($self->uri);
    sleep 1; # 適度にまつ
    if (!$xml_feed) {
        warn "fetching feed is failed " . $self->uri;
        return;
    }
    
    my $has_new = 0;
    for my $entry (reverse($xml_feed->entries)) {

        next if $self->last_update && $entry->issued < $self->last_update;
        $has_new = 1;
        $code->($entry);
    }
    $self->fix_last_update if $has_new;
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
