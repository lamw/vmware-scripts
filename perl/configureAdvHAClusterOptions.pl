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
# 11/11/2009
# http://communities.vmware.com/docs/DOC-11221
# http://engr.ucsb.edu/~duonglt/vmware/
##########################################

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
	cluster => {
	type => "=s",
        help => "Name of the vCenter cluster",
	required => 1,
	},
	file => {
        type => "=s",
        help => "Name of the file containing the keys and value",
        required => 1,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my ($cluster_view);
my %config;
my $cluster = Opts::get_option('cluster');
my $file = Opts::get_option('file');

&processConfigurationFile($file);

$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster });
unless ($cluster_view){
	Util::disconnect();
	die "No cluster found with name $cluster\n";	
}

&addAdvOptions($cluster_view);

Util::disconnect();

sub addAdvOptions {
	my ($cluster) = @_;
	
	eval {
		print "Reconfiguring cluster: \"" . $cluster->name . "\" with the following HA advanced configurations ...\n";
		my @options;
		for my $key ( keys %config ) {
        		my $value = $config{$key};
			my $option = OptionValue->new(key => $key, value => $value);
			print "\t" . $key . " => " . $value . "\n"; 
			push @options,$option;
		}
		my $dasConfigSpec = ClusterDasConfigInfo->new(option => \@options);
		my $clusterConfigSpec = ClusterConfigSpecEx->new(dasConfig => $dasConfigSpec);
		my $taskRef = $cluster->ReconfigureComputeResource_Task(spec => $clusterConfigSpec, modify => 'true');
		my $msg = "\nSuccessfully added advanced HA configurations to cluster: \"" . $cluster->name . "\"\n";
		&getStatus($taskRef,$msg);
	};
	if($@) {
		print "Error: " . $@ . "\n";
	}
}

sub processConfigurationFile {
        my ($local_conf) = @_;
        my $CONF_HANDLE;

        open(CONF_HANDLE, "$local_conf") || die "Couldn't open file \"$local_conf\"!\n";
        while (<CONF_HANDLE>) {
                chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;

                my ($key, $value) = split(/\s*=\s*/, $_, 2);
                $value =~ s/"//g;
                $config{$key} = $value;
        }
        close(CONF_HANDLE);
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
