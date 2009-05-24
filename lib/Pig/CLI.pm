package Pig::CLI;
use strict;
use warnings;
use Any::Moose;
use YAML::XS;
use Pig;

has 'configfile' => (
    is => 'ro',
    isa => 'Str',
    default => './config.yaml',
);

sub get_config_from_file {
    my $self = shift;

    my $config = {};
    eval {
        $config = YAML::XS::LoadFile($self->configfile);
    };
    if ($@){
        die "Failed to open config file: $@";
    }
    return $config;
}

sub run {
    my $self = shift;
    my $config = $self->get_config_from_file;

    Pig->bootstrap($config);
}

1;
