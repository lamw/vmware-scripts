#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2012/04/scripts-to-extract-vcloud-director.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

$SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   moref => {
      type => "=s",
      help => "MoRef ID for vCD VM",
      required => 1,
   },
);

Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $moref = Opts::get_option('moref');
my %parentVMDisks = ();
my %linkedCloneVMDisks = ();
my %linkedCloneToParentDisksMapping = ();
my ($linkedCloneVM,$parentVM, $parentVMRef,$parentVMName,$parentVMFiles) = ();

# Retrieve parent VM's disk to compare later
$parentVMRef = ManagedObjectReference->new(type => "VirtualMachine", value => $moref);
$parentVM = Vim::get_view(mo_ref => $parentVMRef, properties => ['name','layoutEx.file']);
$parentVMFiles = eval {$parentVM->{'layoutEx.file'}} || [];
$parentVMName = $parentVM->{'name'};
foreach my $file (@$parentVMFiles) {
	if($file->type eq "diskDescriptor") {
		$parentVMDisks{$file->name} = $parentVMName;
	}
}

# Retrieve all VMs disks to compare later
my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name','parent','layoutEx']);

my $count = 0;
foreach my $vm_view(@$vm_views) {
	if($vm_view->{'name'} ne $parentVMName && defined($vm_view->{'parent'})) {
		my $disks = eval {$vm_view->{'layoutEx'}->disk} || [];
		my $files = eval {$vm_view->{'layoutEx'}->file} || [];
		foreach my $disk (@$disks) {
			my $chains = eval {$disk->chain} || [];
			foreach my $chain(@$chains) {
				my $filekeys = eval {$chain->fileKey} || [];
				foreach my $filekey (@$filekeys) {
					if(defined($files->[$filekey])) {
						# only care about descriptor
						if($files->[$filekey]->type eq "diskDescriptor") {
							my $parentFolder = Vim::get_view(mo_ref => $vm_view->{'parent'});
							$linkedCloneVMDisks{$parentFolder->name . "==" . $count} = $files->[$filekey]->name;
							$count++;
						}
					}
				}
			}
		}
	}
}

# compare VM to see if we have any mapping to our parent VM
# which means we have a Linked Clone
for my $key ( keys %linkedCloneVMDisks ) {
        my $value = $linkedCloneVMDisks{$key};

	if($parentVMDisks{$value}) {
		my ($a,$b) = split("==",$key);
		$linkedCloneToParentDisksMapping{$a} = $parentVMDisks{$value};
	}
}

print "\n";
format format =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< | @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$linkedCloneVM,$parentVM
-----------------------------------------------------------------------------------------------------------------
.
($linkedCloneVM,$parentVM) = ("vCD Linked Clone vApp","vCD Parent vApp");
$~ = 'format';
write;

for my $key ( keys %linkedCloneToParentDisksMapping ) {
	my $value = $linkedCloneToParentDisksMapping{$key};
	$linkedCloneVM = $key;
	$parentVM = $value;
	write;
}
print "\n";

Util::disconnect();
