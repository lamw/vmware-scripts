#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10779

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
