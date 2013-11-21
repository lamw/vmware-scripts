#!/usr/bin/perl -w
# Copyright (c) 2009-2013 William Lam All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author or contributors may not be used to endorse or
#    promote products derived from this software without specific prior
#    written permission.
# 4. Consent from original author prior to redistribution

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# William Lam
# http://blogs.vmware.com/vsphere/automation

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
	operation => {
		type => "=s",
                help => "Operation to perform [start|stop|reset|getstats]",
		required => 1,
	},
	output => {
                type => "=s",
                help => "Output to a file",
                required => 0,
        },
);

Opts::add_options(%opts);

Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $output = Opts::get_option('output');

my $serviceName = "VscsiStats";
my $vscsiStatsService = undef;
my %vScsiStatsCommandMapping = (
        'start' => 'StartVscsiStats',
	'stop' => 'StopVscsiStats',
	'reset' => 'ResetVscsiStats',
        'getstats' => 'FetchAllHistograms'
);

if(!defined($vScsiStatsCommandMapping{$operation})) {
        print "\nInvalid operation!\n\n";
        Util::disconnect();
        exit 1;
}

my $serviceContent = Vim::get_service_content();
if($serviceContent->about->apiVersion ne "5.1" || $serviceContent->about->apiType ne "HostAgent") {
	print "Script requires connecting directly to an ESXi 5.1 host\n";
	Util::disconnect();
	exit 1
}

my $services = Vim::get_view(mo_ref => $serviceContent->serviceManager)->service;
foreach my $service (@$services) {
	if($service->serviceName eq $serviceName) {
		$vscsiStatsService = Vim::get_view(mo_ref => $service->service);
		last;
	}
}

eval {
	my $results = $vscsiStatsService->ExecuteSimpleCommand(arguments => [$vScsiStatsCommandMapping{$operation}]);
	if($output) {
		print "Saving results to " . $output . "\n";
		open(RESULT_OUTPUT, ">$output");
		print RESULT_OUTPUT $results;
		close(RESULT_OUTPUT);
	} else {
		print $results . "\n";
	}
};
if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();
