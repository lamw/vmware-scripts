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

# William Lam 
# 01/15/09
# http://communities.vmware.com/docs/DOC-11776
# http://engineering.ucsb.edu/~duonglt/vmware
# http://communities.vmware.com/docs/DOC-9852

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   datastore => {
      type => "=s",
      help => "Name of specific datastore to rename",
      required => 0,
   },
   txtformat => {
      type => "=s",
      help => "New name for the datastore (e.g. LOCAL => LOCAL{1,2,3...}-SHORTHOSTNAME)",
      required => 0,
      default => 'LOCAL',
   },
   hostlist => {
      type => "=s",
      help => "Lists of ESX(i) hosts to perform operation _IF_ they're being managed by vCenter (default is ALL hosts in vCenter)",
      required => 0,
   },
   txtplacement => {
      type => "=s",
      help => "Format placement of the hostname string [append|prepend]",
      required => 1,
   },
   operation => { 
      type => "=s",
      help => "Operation to perform [rename|dryrun]",
      required => 0,
      default => 'dryrun',
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $txtformat = Opts::get_option('txtformat');
my $datastore = Opts::get_option('datastore');
my $hostlist = Opts::get_option('hostlist');
my $txtplacement = Opts::get_option('txtplacement');
my $operation = Opts::get_option('operation');

my (@hosts,$content,$host_view,$host_views,$hostname,$datastores,$new_dsname);

$content = Vim::get_service_content();

if($content->about->apiType eq 'HostAgent') {
	$host_view = Vim::find_entity_view(view_type => 'HostSystem');
	if(defined($host_view->summary->managementServerIp)) {
                Util::disconnect();
                print "ESX(i) host is currently being managed by a vCenter Server, to properly rename datastore, please connect to vCenter and specify --vihost param!\n";
                exit 1;
        }
	&getDatastores($host_view);
} else {
	if($hostlist) {
		&processFile($hostlist);
		foreach(@hosts) {
			$host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { 'name' => $_});
			print $host_view->name . "\n";
			&getDatastores($host_view);
		}
	} else {
		$host_views = Vim::find_entity_views(view_type => 'HostSystem');
		foreach(@$host_views) {
			&getDatastores($_);
		}	
	}
}


Util::disconnect();

####################################
#       HELPER FUNCTIONS
####################################

sub getDatastores {
	my ($host) = @_;

	$hostname = &getShortHostname($host);
        $datastores = Vim::get_views(mo_ref_array => $host->datastore);
        &searchDS($txtformat,$txtplacement,$hostname,$datastores);
}

sub renameDS {
        my ($ds,$new_name) = @_;

	if($operation ne 'dryrun') {
		print "\tRenaming \"" . $ds->name ."\" to \"$new_name\" ...\n";
        	my $task = $_->Rename_Task(newName => $new_name);
        	my $msg = "\tSucessfully renamed datastore!\n";
        	&getStatus($task,$msg);
	} else {
		print "\tDRYRUN - Renaming \"" . $ds->name ."\" to \"$new_name\" ...\n";
	}	
}

sub searchDS {
        my ($txt,$placement,$hostname,$datastores) = @_;
	my $datastoreCount = 1;

        foreach(@$datastores) {
		if($datastore) {
			if($_->name eq $datastore) {
				if($placement eq 'prepend') {
                                        $new_dsname = $txt . $datastoreCount . "-" . $hostname;
                                } else {
                                        $new_dsname = $hostname . "-" . $txt . $datastoreCount;
                                }
                                &renameDS($_,$new_dsname);
                                $datastoreCount++;
			}
		} else {
                	if($_->summary->type eq 'VMFS' && $_->name =~ m/^datastore/) {
                        	if($placement eq 'prepend') {
                                	$new_dsname = $txt . $datastoreCount . "-" . $hostname;
                        	} else {
					$new_dsname = $hostname . "-" . $txt . $datastoreCount;
				}
				&renameDS($_,$new_dsname);
				$datastoreCount++;
			}
                }
        }
}

sub getShortHostname {
	my ($host) = @_;
	my $shortname = $host->name;

	my $networkSys = Vim::get_view(mo_ref => $host->configManager->networkSystem);

	if($networkSys->dnsConfig->hostName) {
		$shortname = $networkSys->dnsConfig->hostName;
	}	

	return $shortname;
}

# Subroutine to process the input file
sub processFile {
        my ($list,$type) =  @_;
        my $HANDLE;
        open (HANDLE, $list) or die("ERROR: Can not locate or open \"$list\" input file!\n");
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
                        my $entry = $line;
                        &TrimSpaces($entry);
                        push @hosts,$entry;
                }
        }
}

sub TrimSpaces {
        foreach (@_) {
                s/^\s+|\s*$//g
        }
}

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
