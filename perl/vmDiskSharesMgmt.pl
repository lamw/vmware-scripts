#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2010/07/script-configure-vm-disk-shares.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect()};

my %opts = (
   diskshares_file => {
      type => "=s",
      help => "Name of VM Disk Shares input file",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $diskshares_file = Opts::get_option('diskshares_file');

my %vmDiskShares = ();

&processFile($diskshares_file);

foreach my $vmname (keys %vmDiskShares) {
        my @diskShares = split("=",$vmDiskShares{$vmname});
        my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {name => $vmname});

        my @deviceChangeArr = ();
        my $diskShareChangeString = "";

        if($vm) {
                my $vmDevices = $vm->config->hardware->device;
                my @vmDisks = ();

                foreach(@$vmDevices) {
                        if($_->isa('VirtualDisk')) {
                                push @vmDisks,$_;
                        }
                }

                foreach(@diskShares) {
                        my ($disk,$share) = split(',',$_);
                        $disk =~ s/hd//g;
                        $disk = "Hard disk " . $disk;
                        my $diskView = &findvDisk($disk,@vmDisks);
                        if($diskView) {
                                my ($sharesLevel,$sharesValue);

                                if($share =~ m/low/) {
                                        $sharesLevel = 'low';
                                        $sharesValue = 500;
                                }elsif($share =~ m/normal/) {
                                        $sharesLevel = 'normal';
                                        $sharesValue = 1000;
                                }elsif($share =~ m/high/) {
                                        $sharesLevel = 'high';
                                        $sharesValue = 2000;
                                }else {
                                        $sharesLevel = 'custom';
                                        $sharesValue = $share;
                                }

                                my $shares = SharesInfo->new(level => SharesLevel->new($sharesLevel), shares => $sharesValue);

                                my $diskSpec = VirtualDisk->new(controllerKey => $diskView->controllerKey,
                                        unitNumber => $diskView->unitNumber,
                                        key => $diskView->key,
                                        backing => $diskView->backing,
                                        deviceInfo => $diskView->deviceInfo,
                                        capacityInKB => $diskView->capacityInKB,
                                        shares => $shares
                                );

                                my $devspec = VirtualDeviceConfigSpec->new(operation => VirtualDeviceConfigSpecOperation->new('edit'),
                                        device => $diskSpec,
                                );
                                push @deviceChangeArr, $devspec;
                                $diskShareChangeString .= $disk . "\t" . $share . "\n";
                        }
                }

                my $vmspec = VirtualMachineConfigSpec->new(deviceChange => \@deviceChangeArr);
                eval {
                        print "Reconfiguring disk shares for " . $vm->name . "\n";
                        print $diskShareChangeString;
                        my $task = $vm->ReconfigVM_Task(spec => $vmspec);
                        my $msg = "\tSucessfully reconfigured " . $vm->name . "\n";
                        &getStatus($task,$msg);

                };
                if($@) {
                        print "ERROR " . $@ . "\n";
                }
        }
}


Util::disconnect();

#### HELPER #####

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print $message,"\n";
                        return $info->result;
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

sub findvDisk {
        my ($vdisk,@disks) = @_;

        my $found = 0;
        my $disk;

        foreach(@disks) {
                if($vdisk eq $_->deviceInfo->label && $found ne 1) {
                        $found = 1;
                        $disk = $_;
                }
        }
        return $disk;
}

# Subroutine to process the input file
sub processFile {
        my ($conf) = @_;

        open(CONFIG, "$conf") || die "Error: Couldn't open the $conf!";
        while (<CONFIG>) {
                chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;
                my ($VM,$DISKSHARES) = split(';',$_,2);
                chomp($VM);
                $vmDiskShares{$VM} = $DISKSHARES;
        }
        close(CONFIG);
}
