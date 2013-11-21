#!/usr/bin/perl -w
# Copyright (c) 2009-2011 William Lam All rights reserved.

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
# 4. Written Consent from original author prior to redistribution

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
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of VirtalMachine",
      required => 1,
   },
   key => {
      type => "=s",
      help => "Extension key (e.g. com.vmware.vGhetto)",
      required => 1,
   },
   type => {
      type => "=s",
      help => "Type",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

unless(Vim::get_service_content()->about->apiVersion eq "5.0" && Vim::get_service_content()->about->productLineId eq "vpx") {
	print "ManagedBy property is only supported with vSphere vCenter 5.0!\n";
	Util::disconnect();
	exit;
}

my $vmname = Opts::get_option('vmname');
my $key = Opts::get_option('key');
my $type = Opts::get_option('type');

my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine',filter => {"config.name" => $vmname});

unless($vm_view) {
	print "Unable to locate $vmname!\n";
	Util::disconnect();
	exit;
}

eval {
	my $managedBy = ManagedByInfo->new(extensionKey => $key, type => $type);
	my $spec = VirtualMachineConfigSpec->new(managedBy => $managedBy);
	$vm_view->ReconfigVM_Task(spec => $spec);
};
if($@) {
	print $@ . "\n";
}

Util::disconnect();
