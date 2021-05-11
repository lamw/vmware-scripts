#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2011/09/how-to-query-vm-disk-format-in-vsphere.html

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

William Lam, http://www.williamlam.com/

=cut

