use strict;
use warnings;
use Pig::CLI;

my %args;
my $configfile = shift;
$args{configfile} = $configfile if $configfile;

Pig::CLI->new(%args)->run;
