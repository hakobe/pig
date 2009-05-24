package Pig::Service::FeedReader::Channel;
use strict;
use warnings;
use Any::Moose;
use URI;
use DateTime;

has name => (
    is => 'ro',
    isa => 'Str'
);

has is_active => (
    is => 'rw',
    isa => 'Bool',
    default => sub { 0 },
);

has feeds => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

sub activate {
    my $self = shift;
    $self->is_active(1);
}

sub deactivate {
    my $self = shift;
    $self->is_active(0);
}

1;
