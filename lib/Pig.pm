package Pig;
use strict;
use warnings;

our $VERSION = '0.01';

use Any::Moose;

# Log
use Log::Log4perl qw(:easy);

# IRCd
use Pig::IRCD;

# Service
use UNIVERSAL::require;

has log => (
    is => 'rw',
    lazy => 1,
    default => sub { Log::Log4perl->get_logger(ref shift) },
);

has ircd => (
    is => 'rw',
);

has service => (
    is => 'rw',
);

sub bootstrap {
    my ($class, $config) = @_;

    my $log_config = delete $config->{log} || {};
    my $log_level = delete $config->{log_level};
    $log_config->{log_level} ||= $log_level;

    my $ircd_config = delete $config->{ircd} || {};
    my $port = delete $config->{port};
    $ircd_config->{port} ||= $port;

    my $service_config = delete $config->{service} || {};

    my $self = $class->new($config);
    $self->prepare_log($log_config);
    $self->prepare_ircd($ircd_config);
    $self->prepare_service($service_config);

    $self->run;
}

sub prepare_log {
    my ($self, $log_config) = @_;
    Log::Log4perl->easy_init( {
        ALL    => $ALL,
        TRACE  => $TRACE,
        DEBUG  => $DEBUG,
        INFO   => $INFO,
        WARN   => $WARN,
        ERROR  => $ERROR,
        FATAL  => $FATAL,
        OFF    => $OFF,
    }->{uc($log_config->{log_level})});
}

sub prepare_ircd {
    my ($self, $ircd_config) = @_;
    my $ircd = Pig::IRCD->new($ircd_config);
    $self->ircd($ircd);
}

sub prepare_service {
    my ($self, $service_config) = @_;
    my $name = delete $service_config->{name};
    my $service_class = 'Pig::Service::' . $name;
    eval {
        $service_class->use;
    };
    if ($@) { die "use $service_class failed: $@" }

    my $service = $service_class->new($service_config);
    $self->service($service);
}

sub run { 
    my $self = shift;
    my $service_name = ref $self->service;
    $self->log->info("Starting up pig with $service_name.");

    $self->ircd->init($self);
    $self->ircd->run;
}

1;
__END__

=encoding utf8

=head1 NAME

Pig -

=head1 SYNOPSIS

  use Pig;

=head1 DESCRIPTION

Pig is Perl IRC Gateway framework

=head1 AUTHOR

Yohei Fushii E<lt>hakobe@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
