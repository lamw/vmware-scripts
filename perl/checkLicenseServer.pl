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

# William Lam 5/12/09

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

#first query License Server from vCenter
my $content = Vim::get_service_content();
if($content->about->apiType ne 'VirtualCenter') {
	print "Please input a valid vCenter hostname/IP for --server\n";
	Util::disconnect();
	exit 1;
}

my $lic_mgr = Vim::get_view(mo_ref => $content->licenseManager);
print "Checking License Server: ", $lic_mgr->source->licenseServer,"\n";
print "License Source availability ", $lic_mgr->sourceAvailable,"\n"; 

if($lic_mgr->sourceAvailable eq 'true') {
	my ($hosts, $host, @host_wo_lic);

	$hosts = Vim::find_entity_views(view_type => 'HostSystem');

	unless (defined $hosts){
		print "No hosts found.\n";	
		exit 0;
	}

	print "Querying hosts ...\n";
	foreach $host(@{$hosts}) {
		my $host_serv_content =  Vim::get_service_content();
		my $host_lic_mgr =  Vim::get_view(mo_ref => $content->licenseManager);
		if($host_lic_mgr->sourceAvailable eq 'false') {
			push @host_wo_lic, $host->name;
		}
	}
	if(@host_wo_lic) {
		foreach (@host_wo_lic) {
			print $_, " does not have valid license source\n";
		}
	} else {
		print "All hosts are licensed!\n";
	}
} else {
	print "License Server is down!\n";
}
Util::disconnect();
