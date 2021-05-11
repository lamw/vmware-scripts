#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2013/01/retrieving-esxtop-performance-data.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
	operation => {
		type => "=s",
                help => "Operation to perform [getcounters|getstats|freestats]",
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

my $serviceName = "Esxtop";
my $esxtopService = undef;
my %esxtopCommandMapping = (
        'getcounters' => 'CounterInfo',
        'getstats' => 'FetchStats',
	'freestats' => 'FreeStats'
);

if(!defined($esxtopCommandMapping{$operation})) {
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
		$esxtopService = Vim::get_view(mo_ref => $service->service);
		last;
	}
}

eval {
	my $results = $esxtopService->ExecuteSimpleCommand(arguments => [$esxtopCommandMapping{$operation}]);
	if($output) {
		print "Saving results to " . $output . "\n";
		open(RESULT_OUTPUT, ">$output");
		print RESULT_OUTPUT $results;
		close(RESULT_OUTPUT);
	} else {
		print ($results ? $results : "No Output\n");
	}
};
if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();
