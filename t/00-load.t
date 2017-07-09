#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Device::AirscapeGen2WHF' ) || print "Bail out!\n";
}

diag( "Testing Device::AirscapeGen2WHF $Device::AirscapeGen2WHF::VERSION, Perl $], $^X" );
