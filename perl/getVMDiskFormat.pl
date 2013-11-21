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
# 09/24/11
# http://www.virtuallyghetto.com/
##################################################################
use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

$SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   output => {
      type => "=s",
      help => "[console|csv]",
      required => 1,
   },
   filename => {
      type => "=s",
      help => "Name of output file",
      required => 0,
      default => 'vmDiskFormat.csv',
   },
);

Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $output = Opts::get_option("output");
my $filename = Opts::get_option("filename");

my ($vmname,$type,$diskLabel,$diskName) = ("VMNAME","DISKTYPE","DISKLABEL","DISKNAME");

if($output eq "console") {
	format format =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$vmname,$type,$diskLabel,$diskName
--------------------------------------------------------------------------------------------------------------------------------------------------
.

$~ = 'format';
write;
} else {
	print "Generating $filename ...\n";
	open(VMDISK_REPORT,">$filename");
	print VMDISK_REPORT "$vmname,$type,$diskLabel,$diskName\n";
	close(VMDISK_REPORT);
}

my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name','config.hardware.device']);

foreach my $vm_view(sort{$a->name cmp $b->name} @$vm_views) {
	$vmname = $vm_view->{'name'};
	my $devices = $vm_view->{'config.hardware.device'};
	foreach my $device (@$devices) {
		if($device->isa('VirtualDisk')) {
			if($device->backing->isa('VirtualDiskFlatVer2BackingInfo')) {
				$diskLabel = $device->deviceInfo->label;
				$diskName = $device->backing->fileName;
				if($device->backing->thinProvisioned) {
					$type = "thinProvisioned";
				} elsif($device->backing->eagerlyScrub) {
					$type = "eagerzeroedthick";
				} else {
					$type = "zeroedthick";
				}
				if($output eq "console") {
					write;
				} else {
					open(VMDISK_REPORT,">>$filename");
					print VMDISK_REPORT "$vmname,$type,$diskLabel,$diskName\n";
					close(VMDISK_REPORT);
				}
			}
		}
	}
}

Util::disconnect();

=head1 NAME

getVMDiskFormat.pl - Script to query virtual machines disk format (zeroedthick,eagerzioerdthick or thin)

=head1 Examples

=over 4

=item Query virtual machine disk format and output to console

=item

./getVMDiskFormat.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --output console

=item

=item Query virtual machine disk format and output to csv file

=item

./getVMDiskFormat.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --output csv

./getVMDiskFormat.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --output csv --filename [CSV_FILENAME]

=item

=back

=head1 SUPPORT

vSphere 5.0

=head1 AUTHORS

William Lam, http://www.virtuallyghetto.com/

=cut

