#!/usr/bin/perl -w
# Copyright (c) 2009-2010 William Lam All rights reserved.

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
# 05/14/2009
# http://communities.vmware.com/docs/DOC-10189
# Usage example
#
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
