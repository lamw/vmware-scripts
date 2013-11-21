#!/usr/bin/perl -w
# Copyright (c) 2009-2012 William Lam All rights reserved.

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
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of Virtual Machine to query number of vMotions",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vmname');
my %vmotions = ();
my $numvMotions = 0;

my $eventMgr = Vim::get_view(mo_ref => Vim::get_service_content()->eventManager);
my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"name" => $vmname});

unless($vm_view) {
	print "Unable to locate VM: " . $vmname . "\n";
	Util::disconnect();
	exit 1;
}

eval {
	my $recursion = EventFilterSpecRecursionOption->new("self");
	my $entity = EventFilterSpecByEntity->new(entity => $vm_view, recursion => $recursion);
	my $filterSpec = EventFilterSpec->new(type => ["VmMigratedEvent"], entity => $entity);
	my $events = $eventMgr->QueryEvents(filter => $filterSpec);
	$numvMotions = @$events;
	foreach(@$events) {
		if(defined($_->host)) {
			$vmotions{$_->host->name} += 1;
		}
	}
};
if($@) {
	print "Error: " . $@ . "\n";
}

print "\n" . $vmname . " has a total of " . $numvMotions . " vMotions:\n\n";
for my $key ( sort keys %vmotions ) {
        my $value = $vmotions{$key};
        print "$key => $value\n";
}
print "\n";

Util::disconnect();
