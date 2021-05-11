#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11000

use strict;
use warnings;
use VMware::VIRuntime;

my %opts = (
        vmfile => {
        type => "=s",
        help => "Path to file containing list of virtual machines, one per line to upgrade Virtual HW.",
        required => 0,
        },
        upgrade_type => {
        type => "=s",
        help => "Upgrade only VMs in vmfile or ALL VMs [list|all]",
        required => 1,
        },
        hwversion => {
        type => "=s",
        help => "Virtual HW Version to upgrade to",
        required => 1,
        },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();

Util::connect();

my ($ret, $vm_name, $vm_view, $vm_file, @vm_list, $upgrade_type, $hwversion, $hwcurrent, $task_ref);

$vm_file = Opts::get_option("vmfile");
$upgrade_type = Opts::get_option("upgrade_type");
$hwversion = Opts::get_option("hwversion");

if($upgrade_type eq 'list') {
        &processFile($vm_file);
        foreach $vm_name( @vm_list ) {
                chomp($vm_name);

                $vm_view = Vim::find_entity_view(
                        view_type => "VirtualMachine",
                        filter => { 'name' => $vm_name }
                );

                $hwcurrent = $vm_view->config->version;
                $hwcurrent =~ s/vmx-0//;

                unless ( defined $vm_view ) {
                        Util::disconnect();
                        die "Virtual Machine, '$vm_name', not found.\n";
                }
                $ret = &validateVMPriorToUpgrade($vm_view);
                if($ret) {
                        &upgradeVirtualHW($vm_view,$hwcurrent,$hwversion);
                }
        }
} else {
        $vm_view = Vim::find_entity_views(view_type => "VirtualMachine");
        foreach $vm_name( @$vm_view ) {
                $hwcurrent = $vm_view->config->version;
                $hwcurrent =~ s/vmx-0//;

                $ret = &validateVMPriorToUpgrade($vm_name);
                if($ret) {
                        &upgradeVirtualHW($vm_name,$hwcurrent,$hwversion);
                }
        }
}

Util::disconnect();

sub validateVMPriorToUpgrade {
        my ($vm) = @_;
        my $success = 1;
        unless ( $vm->summary->runtime->powerState->val eq 'poweredOff') {
                $success = 0;
                print "VM: \"" . $vm->name . "\" must be powered off!\n";
        }
        unless ( $hwcurrent ne $hwversion ) {
                $success = 0;
                print "VM: \"" . $vm->name . "\" is already running Virtual HW version: " . $hwcurrent . "\n";
        }
        return $success;
}

sub upgradeVirtualHW {
        my ($vm,$curr,$hwver) = @_;
        print "Upgrading VM: \"" . $vm->name . "\" Virtual HW from: " . $curr . " to " . $hwver . "\n";
        eval {
                $task_ref = $vm->UpgradeVM_Task();
                my $msg = "\tSuccessfully upgraded Virtual HW for " . $vm->name . "\n";
                &getStatus($task_ref,$msg);
        };
        if($@) { print "Error: " . $@ . "\n"; }
}

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

# Subroutine to process the input file
sub processFile {
        my ($vmlist) =  @_;
        my $HANDLE;
        open (HANDLE, $vmlist) or die(timeStamp('MDYHMS'), "ERROR: Can not locate \"$vmlist\" input file!\n");
        my @lines = <HANDLE>;
        my @errorArray;
        my $line_no = 0;

        close(HANDLE);
        foreach my $line (@lines) {
                $line_no++;
                &TrimSpaces($line);

                if($line) {
                        if($line =~ /^\s*:|:\s*$/){
                                print "Error in Parsing File at line: $line_no\n";
                                print "Continuing to the next line\n";
                                next;
                        }
                        my $vm = $line;
                        &TrimSpaces($vm);
                        push @vm_list,$vm;
                }
        }
}

sub TrimSpaces {
        foreach (@_) {
                s/^\s+|\s*$//g
        }
}
