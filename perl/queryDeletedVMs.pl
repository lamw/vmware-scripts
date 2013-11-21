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
# www.virtuallyghetto.com
# http://communities.vmware.com/docs/DOC-10282
# 06/26/09

use strict;
use warnings;
use VMware::VIRuntime;

my %opts = (
	vmname => {
	type => "=s",
	help => "Name of deleted VM to search for.",
	required => 1,
	},
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vmname');
my $eventMgr = Vim::get_view(mo_ref => Vim::get_service_content()->eventManager);

my $events = $eventMgr->QueryEvents(filter => EventFilterSpec->new(type => ['VmRemovedEvent']));

foreach(@$events) {
	if ( $_->fullFormattedMessage =~ m/$vmname/i) { 
		print "User: ", $_->userName,"\n";
		print "Deleted VM: ", $_->fullFormattedMessage,"\n";
		print "Date/Time: ", $_->createdTime,"\n\n";
	}
}

Util::disconnect();
