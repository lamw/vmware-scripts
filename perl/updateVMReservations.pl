#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com

use strict;
use warnings;
use VMware::VIRuntime;

my %opts = (
        vmlist => {
        type => "=s",
        help => "List of VMs",
        required => 1,
        },
        mem_rsv => {
        type => "=s",
        help => "Memory reservation (MB)",
        required => 0,
        },
        cpu_rsv => {
        type => "=s",
        help => "CPU reservation (MHz)",
        required => 0,
        },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();

Util::connect();

my $vmlist = Opts::get_option("vmlist");
my $mem_rsv = Opts::get_option("mem_rsv");
my $cpu_rsv = Opts::get_option("cpu_rsv");
my @vmlist = ();

if(!$mem_rsv && !$cpu_rsv) {
	print "You must defined at least one type of reservation [mem_rsv|cpu_rsv]\n";
	Util::disconnect();
	exit 1;
}

&processConf($vmlist);

foreach(@vmlist) {
	my $vm_view = Vim::find_entity_view(view_type => "VirtualMachine", filter => {"name" => $_});
	if($vm_view) {
		print "Updating reservation for " . $_ . "\n";
        	eval {
			my ($memResv,$cpuResv,$vmSpec);
			if($mem_rsv) {
				$memResv = ResourceAllocationInfo->new(reservation => $mem_rsv);
			}
			if($cpu_rsv) {
				$cpuResv = ResourceAllocationInfo->new(reservation => $cpu_rsv);
			}

			if($mem_rsv && !$cpu_rsv) {
				$vmSpec = VirtualMachineConfigSpec->new(memoryAllocation => $memResv);
			}elsif(!$mem_rsv && $cpu_rsv) {
				$vmSpec = VirtualMachineConfigSpec->new(cpuAllocation => $cpuResv);
			}else {
				$vmSpec = VirtualMachineConfigSpec->new(memoryAllocation => $memResv, cpuAllocation => $cpuResv);
			}

                	my $task_ref = $vm_view->ReconfigVM_Task(spec => $vmSpec);
                	my $msg = "\tSuccessfully updated reservation for " . $vm_view->name . "\n";
                	&getStatus($task_ref,$msg);
        	};
        	if($@) { print "Error: " . $@ . "\n"; }
	} else {
		print "Unable to locate VM: \"" . $_ . "\"\n";
	}
}

Util::disconnect();

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print $message;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
                        die "$soap_fault\n";
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}

sub processConf {
        my ($vminput) = @_;

        open(CONFIG, "$vminput") || die "Error: Couldn't open the $vminput!";
        while (<CONFIG>) {
                chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;
		push @vmlist,$_;
        }
        close(CONFIG);
}
