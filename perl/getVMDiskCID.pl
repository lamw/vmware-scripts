#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10189

=remove
[vi-admin@rafaeli ~]$ ./getVMDiskCID.pl --server mauna-loa.primp-industries.com --username primp --vmname lamw_base
Enter password:
Virtual Machine: lamw_base
        CURRENT VMDK: [everest-local-storage] lamw_base/lamw_base-000002.vmdk
        CID: 0xb95ddf5b
        PARENT VMDK: [everest-local-storage] lamw_base/lamw_base-000001.vmdk
        CID: 0xb95ddf5b
        PARENT VMDK: [everest-local-storage] lamw_base/lamw_base.vmdk
        CID: 0xb95ddf5b
=cut

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of the virtual machine",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {name => Opts::get_option('vmname')});

unless (defined $vm){
        die "No VM found.\n";
}

print "Virtual Machine: ", $vm->name,"\n";

if($vm->config->hardware->device) {
        my $devices = $vm->config->hardware->device;
        foreach(@$devices) {
                if($_->isa('VirtualDisk')) {
                        print "\tCURRENT VMDK: ", $_->backing->fileName,"\n";
                        print "\tCID: ", $_->backing->contentId,"\n";
                        if($_->backing->parent) {
                                getParent($_->backing->parent);
                        }
                }
        }
}

sub getParent {
        my ($parent) = @_;
        print "\tPARENT VMDK: ", $parent->fileName,"\n";
        print "\tCID: ", $parent->contentId,"\n";
        if($parent->parent) { getParent($parent->parent); }
}

Util::disconnect();
