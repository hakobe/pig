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

has port => (
    is => 'ro',
    isa => 'Int',
);

has service => (
    is => 'ro',
    isa => 'HashRef',
);

has log_level => (
    is => 'ro',
    isa => 'Str',
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
        service   => $self->service,
        port      => $self->port,
        log_level => $self->log_level,
    });
}

1;
