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

# William Lam
# 10/14/2011
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

my $content = Vim::get_service_content();
my $customFieldMgr = Vim::get_view(mo_ref => $content->customFieldsManager);

my %field_key;
if ( defined $customFieldMgr->field ) {
	foreach (@{$customFieldMgr->field}) {
        	$field_key{$_->key} = $_->name;
        }
}

my $host_views = Vim::find_entity_views(view_type => 'HostSystem', properties => ['name','customValue']);
foreach my $host (@$host_views) {
	if(defined($host->{'customValue'})) {
		my $customFields = $host->{'customValue'};
		foreach(@$customFields) {
			print ref($host) . "\t" . $host->{'name'} . "\t" . $field_key{$_->key} . "\t" . $_->value . "\n";
		}
	}
}

my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name','customValue']);
foreach my $vm (@$vm_views) {
        if(defined($vm->{'customValue'})) {
                my $customFields = $vm->{'customValue'};
                foreach(@$customFields) {
                        print ref($vm) . "\t" . $vm->{'name'} . "\t" . $field_key{$_->key} . "\t" . $_->value . "\n";
                }
        }
}


Util::disconnect();
