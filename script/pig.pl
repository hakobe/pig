use strict;
use warnings;
use Pig;
use Pig::Service::MyHatena;

my $pig = Pig->new(
    service => Pig::Service::MyHatena->new,
);
$pig->run;


