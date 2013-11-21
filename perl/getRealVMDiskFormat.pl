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

##################################################################
# Author: William Lam
# 12/01/2009
# http://communities.vmware.com/docs/DOC-11554
# http://engineering.ucsb.edu/~duonglt/vmware/
##################################################################
use strict;
use warnings;
use Term::ANSIColor;
use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIExt;

$SIG{__DIE__} = sub{Util::disconnect();};

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my ($vm_name,$filelayout,$fm,$vim,$log_inventory_path,$datacenter,$local_target_path,$vm_log_path);
my $main_vmware_log_dir = "vmware_logs";

if(! -d $main_vmware_log_dir) {
        mkdir($main_vmware_log_dir, 0755)|| print $!;
}

$fm = VIExt::get_file_manager();
$vim = Vim->get_vim();

my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine');

foreach my $vm_view(@$vm_views) {
	$vm_name = $vm_view->config->name;
if($vm_name =~ m/vm-/) {
	$filelayout = $vm_view->layoutEx->file;
	$log_inventory_path = Util::get_inventory_path($vm_view, $vim);
	$datacenter = (split /\//,$log_inventory_path,)[0];
	$local_target_path = "$main_vmware_log_dir/$vm_name";
	$vm_log_path = "$local_target_path/$vm_name.log.$$";

	if(! -d $local_target_path ) {
		mkdir($local_target_path, 0755)|| print $!;
	}

	foreach(@$filelayout) {
		if( ($_->type eq 'log') && ($_->name =~ m/vmware.log/) ) {
			do_get($_->name,$vm_log_path);
			my $results = `grep 'FT enable' $vm_log_path`;
			if($results) {
				print "\t" . color("red") . $results . color("reset") . "\n\n";
			} else {
				print "\t" . color("green") . "Is FT ready!" . color("reset") . "\n\n";
			}
		}
	}
}
}

Util::disconnect();

sub do_get {
   my ($remote_source, $local_target) = @_;
   my ($mode, $dc, $ds, $filepath) = VIExt::parse_remote_path($remote_source);
   if (defined $local_target and -d $local_target) {
      my $local_filename = $filepath;
      $local_filename =~ s@^.*/([^/]*)$@$1@;
      $local_target .= "/" . $local_filename;
   }
   my $resp = VIExt::http_get_file($mode, $filepath, $ds, $datacenter, $local_target);
   # bug 301206, 266936
   if (defined $resp and $resp->is_success) {
	print  color("yellow") . $vm_name . color("reset") . "\n";
   } else {
      VIExt::fail("Error: File can not be downloaded to $local_target.");
   }
}

