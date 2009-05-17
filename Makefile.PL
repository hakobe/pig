use inc::Module::Install;
name 'Pig';
all_from 'lib/Pig.pm';

requires $_ for (qw/ /);

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
