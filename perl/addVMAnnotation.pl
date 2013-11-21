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
# 09/28/2009
# http://communities.vmware.com/docs/DOC-10779
# http://engineering.ucsb.edu/~duonglt/vmware/

use strict;
use warnings;
use Term::ANSIColor;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   annotationfile => {
      type => "=s",
      help => "Annotation input file",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my %vmlist = ();
my $annotationfile = Opts::get_option('annotationfile');

processFile($annotationfile);

for my $vmname ( keys %vmlist ) {
        my $annotation = $vmlist{$vmname};
	my $vm = Vim::find_entity_view(view_type => 'VirtualMachine',
                        filter => {"config.name" => $vmname});

	unless ($vm) {
		Util::disconnect();
        	die "Unable to find VM: \"$vmname\"!\n";
	}	

	eval {
        	my $spec = VirtualMachineConfigSpec->new(annotation => $annotation);
	        print color("yellow") . "Reconfiguring \"$vmname\" with annotation: " . color("reset") . "\n\"$annotation\"\n";
        	my $task = $vm->ReconfigVM_Task(spec => $spec);
	        my $msg = color("green") . "\tSucessfully updated annotation for \"$vmname\"!\n" . color("reset");
        	&getStatus($task,$msg);
	};
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

# Subroutine to process the input file
sub processFile {
        my ($vmlist) =  @_;
        my $HANDLE;
        open (HANDLE, $vmlist) or die "ERROR: Unable to open \"$vmlist\" input file!\n";
        my @lines = <HANDLE>;
        my @errorArray;
        my $line_no = 0;

        close(HANDLE);
        foreach my $line (@lines) {
                $line_no++;
                &TrimSpaces($line);

                if($line) {
                        if($line =~ /^\s*:|:\s*$/){
                                &log("error", "Error in Parsing File at line: $line_no");
                                &log("info", "Continuing to the next line");
                                next;
                        }
			my ($vmname,$text) = split('###',$line);
			my @linetext = split('==',$text);
			my $string = "";
			foreach(@linetext) {
				$_ =~ s/"//;
				$string .= $_ . "\n";
			}
			$vmlist{$vmname} = $string;
                }
        }
}

sub TrimSpaces {
        foreach (@_) {
        s/^\s+|\s*$//g
        }
}
