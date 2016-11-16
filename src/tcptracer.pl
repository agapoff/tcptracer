#!/usr/bin/perl

#
# Vitaly Agapov agapov.vitaly@gmail.com
#
# v1.0 2016-11-15
#
# TCP Tracer
#
use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__);
}
use tcptracer;

sub cleanup {
    tcptracer->cleanup();
}
local $SIG{INT} = \&cleanup;
local $SIG{QUIT} = \&cleanup;
local $SIG{TERM} = \&cleanup;
local $SIG{PIPE} = \&cleanup;
local $SIG{HUP} = \&cleanup;


tcptracer->new()->run();
print "Finished";
