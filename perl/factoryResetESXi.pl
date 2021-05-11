#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10651

use strict;
use warnings;
use VMware::VILib;
use VMware::VIFPLib;
use VMware::VIRuntime;
use VMware::VIExt;

my %opts = (
   vihost => {
      type => "=s",
      help => "Name of ESXi host",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vihost = Opts::get_option('vihost');

my ($host_view,$firmwareSystem,$service_content,$host_username,$host_password);

$service_content = Vim::get_service_content();

$host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $vihost});

unless($host_view) {
        die "Unable to locate ESXi host \"$vihost\"!";
}

eval {
        print "\"$vihost\" is entering maintenance mode ...\n";
        my $task_ref = $host_view->EnterMaintenanceMode_Task(timeout => 0, evacuatePoweredOffVms => 1);
        my $msg = "\t\"$vihost\" has successfully entered maintenance mode!";
        &getStatus($task_ref,$msg);
};
if($@) {
        die "Error: " . $@ . "\n";
}

# if ESXi host is attached to vCenter, we'll want to remove
if($service_content->about->apiType eq 'VirtualCenter') {
        eval {
                print "Removing \"$vihost\" from vCenter ...\n";
                my $task_ref = $host_view->Destroy_Task();
                my $msg = "\t\"$vihost\" has successfully been remove from vCenter!";
                &getStatus($task_ref,$msg);
        };
        if($@) {
                die "Error: " . $@ . "\n";
        }

        #requires vMA + ESXi host being managed by vMA
        my $viuser = vifplib_perl::CreateVIUserInfo();
        my $vifplib = vifplib_perl::CreateVIFPLib();
        eval { $vifplib->QueryTarget($vihost, $viuser); };
        if(!$@) {
                $host_username = $viuser->GetUsername();
                $host_password = $viuser->GetPassword();
        } else {
                print "Error: It does not seem like you're managing this ESXi host with vMA!.\n";
                exit 1;
        }

        Util::disconnect();

        my $url = "https://$vihost/sdk";
        Util::connect($url,$host_username,$host_password);

        $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $vihost});

}

$firmwareSystem = Vim::get_view(mo_ref => $host_view->configManager->firmwareSystem);

eval {
        print "Resetting factory settings on \"$vihost\"!\n";
        $firmwareSystem->ResetFirmwareToFactoryDefaults();
};
if($@) {
        die "Error: " . $@ . "\n";
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
