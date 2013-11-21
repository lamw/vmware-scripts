#!/usr/bin/perl -w
#
# Copyright (c) 2009 VMware, Inc.  All rights reserved subject to the terms of the
# vSphere Management Assistant (vMA) End User License Agreement.
#
# This script prints a list of all the targets added to vMA.
# William Lam
# Modified version of VMware's /opt/vmware/vma/bin/vitargetenumerate.pl using new vi-fastpass Perl library


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
