#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference:http://communities.vmware.com/docs/DOC-10805

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   resource_pool => {
      type => "=s",
      help => "Name of Resource Pool",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $rp_name = Opts::get_option('resource_pool');

my $rp = Vim::find_entity_view(view_type => 'ResourcePool', filter =>{ 'name'=> $rp_name});

unless($rp) {
        Util::disconnect();
        die "Unable to locate resource pool \"$rp_name\"\n";
}

my $vms = Vim::get_views(mo_ref_array => $rp->vm, properties => ['summary.config.name']);
foreach(@$vms) {
        print $_->{'summary.config.name'} . "\n";
}

Util::disconnect();
