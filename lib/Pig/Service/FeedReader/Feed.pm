package Pig::Service::FeedReader::Feed;
use strict;
use warnings;
use Moose;
use XML::Feed;
use XML::Atom;
$XML::Atom::ForceUnicode = 1; # FIXME こうしないと日本語がばける…
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
    default => sub { DateTime->from_epoch( epoch => 0 ) },
);

sub fix_last_update {
    my ($self, $user) = @_;
    $self->last_update(DateTime->now(time_zone => 'Asia/Tokyo'));
}

sub each_new_entry {
    my ($self, $pig, $code) = @_;

    # TODO If-Modifed-Since をみて抜けたりする
    my $xml_feed = XML::Feed->parse($self->uri);
    sleep 1; # 適度にまつ
    if (!$xml_feed) {
        $pig->log->info('Fetching Feed failed for ' . $self->uri);
        return;
    }
    
    my $has_new = 0;
    for my $entry (reverse($xml_feed->entries)) {
        # FIXME Gmailのフィードがhoursが24以上の日付を返してくるため
        no warnings 'redefine';
        local *XML::Feed::Entry::Format::Atom::iso2dt = \&iso2dt;

        if ($self->last_update && $entry->issued < $self->last_update) {
            #$pig->log->debug(sprintf("Skipped. ( %s < %s )", $entry->issued, $self->last_update));
            next;
        }
        $has_new = 1;
        $code->($entry);
    }
    $self->fix_last_update if $has_new;
}

# FIXME from XML::Atom::Util
sub iso2dt {
    my($iso) = @_;
    return unless $iso =~ /^(\d{4})(?:-?(\d{2})(?:-?(\d\d?)(?:T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|([+-]\d{2}:\d{2}))?)?)?)?/;
    my($y, $mo, $d, $h, $m, $s, $zone) =
        ($1, $2 || 1, $3 || 1, $4 || 0, $5 || 0, $6 || 0, $7);
    if ($h > 23) {
        $h = $h % 24;
        $d += 1;
    }
    require DateTime;
    my $dt = DateTime->new(
               year => $y,
               month => $mo,
               day => $d,
               hour => $h,
               minute => $m,
               second => $s,
               time_zone => 'UTC',
    );  
    if ($zone && $zone ne 'Z') {
        my $seconds = DateTime::TimeZone::offset_as_seconds($zone);
        $dt->subtract(seconds => $seconds);
    }
    $dt;
} 


__PACKAGE__->meta->make_immutable;
no Moose;
1;
