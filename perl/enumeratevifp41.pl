#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2010/08/why-you-should-upgrade-from-vma-40-to.html

use strict;
use VMware::VIRuntime;
use VMware::VmaTargetLib;

my @targets = VmaTargetLib::enumerate_targets();

if ($#targets ne -1) {
        foreach my $target (@targets) {
                if($target->targetAuthenticationMode() ne 'adauth') {
                        my $username = $target->username();
                        my $password = $target->password();
                        print "Hostname: " . $target->name() . "\tUsername: " . $username . "\tPassword: " . $password . "\n";
                } else {
                        print "Hostname: " . $target->name() . " is using ADAUTH\n";
                }
        }
}
