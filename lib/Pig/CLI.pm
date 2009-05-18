package Pig::CLI;
use strict;
use warnings;
use Moose;
use YAML::XS;
use Pig;

with qw(MooseX::ConfigFromFile);

has '+configfile' => (
    default => './config.yaml',
);

has service => (
    is => 'ro',
    isa => 'HashRef',
);

has port => (
    is => 'ro',
    isa => 'Int',
);

__PACKAGE__->meta->make_immutable;
no Moose;

sub get_config_from_file {
    my ($class, $file) = @_;

    my $config = {};
    eval {
        $config = YAML::XS::LoadFile($file);
    };
    if ($@){
        die "Failed to open config file: $@";
    }
    return $config;
}

sub run {
    my $self = shift;

    Pig->bootstrap({
        service => $self->service,
        port    => $self->port,
    });
}

1;
