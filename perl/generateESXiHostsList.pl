#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2012/03/automating-ssl-certificate-expiry.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   output => {
      type => "=s",
      help => "Name of output file",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $output = Opts::get_option('output');

my $host_views = Vim::find_entity_views(view_type => 'HostSystem', properties => ['name']);

open(OUTPUT,">$output");
foreach my $host (@$host_views) {
	print OUTPUT $host->{'name'} . " 443\n";
}
close(OUTPUT);

Util::disconnect();
