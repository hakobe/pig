package Pig::Role::Service;
use Any::Moose '::Role';

has interval => (
    is => 'ro',
    default => sub {
        60 * 30; # 30分
    }
);

# events
# TODO まだ以下だけ必要に応じてPig::IRCDを弄ってふやすよ

sub on_start {}
sub on_check {}

sub on_ircd_public {}
sub on_ircd_join {}
sub on_ircd_part {}

1;
