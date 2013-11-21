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
#
# William Lam
# http://www.virtuallyghetto.com/

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
