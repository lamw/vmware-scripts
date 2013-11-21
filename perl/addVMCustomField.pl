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
# 08/13/2009
# http://communities.vmware.com/docs/DOC-10550
# http://engineering.ucsb.edu/~duonglt/vmware/

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   key => {
      type => "=s",
      help => "Name of custom field",
      required => 1,
   },
   operation => {
      type => "=s",
      help => "Operation 'add' or 'update'",
      required => 1,
   },
   vmname => {
      type => "=s",
      help => "Name of VM to add/update custom field",
      required => 0,
   },
   value => {
      type => "=s",
      help => "Value of key",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $cfkey = Opts::get_option('key');
my $value = Opts::get_option('value');
my $operation = Opts::get_option('operation');
my $vmname = Opts::get_option('vmname');

my $content = Vim::get_service_content();
my $customFieldMgr = Vim::get_view(mo_ref => $content->customFieldsManager);
my $fields = $customFieldMgr->field;

my $keyInt;
foreach(@$fields) {
	if($_->name eq $cfkey) {
		my $k = $_->key;
        	$keyInt = $k;
        }
}

my $success = 0;
if ( $operation eq 'add' ) {
	$customFieldMgr->AddCustomFieldDef(name => $cfkey, moType => 'VirtualMachine');
} elsif ( $operation eq 'update' ) {
	if($value eq '' || $vmname eq '') {
		print "\"--value\" & \"--vmname\" is required for an update!\n";
		exit 1
	}

	my $vm = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => $vmname});
	unless ($vm) {
		print "Unable to find VM: \"$vmname\"!\n";
		exit 1
	}
	$customFieldMgr->SetField(entity => $vm, key => $keyInt, value => $value);
}

Util::disconnect();
