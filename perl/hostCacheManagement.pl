#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/07/how-to-automate-host-cache.html

use strict;
use warnings;
use Term::ANSIColor;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
        operation => {
                type => "=s",
                help => "Operation to perform [list|enable|disable]",
                required => 1,
        },
	datastore => {
                type => "=s",
                help => "Name of SSD datastore",
		required => 0,
        },
	swapspace => {
                type => "=s",
                help => "Amount of space to allocate for swap performance (MB)",
	        required => 0,
        },
	vihost => {
                type => "=s",
                help => "ESX(i) host when connecting to vCenter",
		required => 0,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $datastore = Opts::get_option('datastore');
my $datastore_file = Opts::get_option('datastore_file');
my $swapspace = Opts::get_option('swapspace');
my $vihost = Opts::get_option('vihost');
my $hostsystem;
my @datastores = ();
my $productSupport = "both";
my @supportedVersion = qw(5.0.0);

&validateSystem(Vim::get_service_content()->about->version,Vim::get_service_content()->about->productLineId);

if(Vim::get_service_content()->about->productLineId eq "vpx") {
	unless($vihost) {
		Util::disconnect();
		&print("Please specify --vihost when connecting to vCenter","red");
	}
	$hostsystem = Vim::find_entity_view(view_type => 'HostSystem', filter => {name => $vihost});
	unless($hostsystem) {
		Util::disconnect();
                &print("Unable to locate \"$vihost\"\n\n","red");
	}
} else {
	$hostsystem = Vim::find_entity_view(view_type => 'HostSystem');
}

my $cacheMgr = Vim::get_view(mo_ref => $hostsystem->configManager->cacheConfigurationManager);

if($operation eq "list") {
	if(defined($cacheMgr->cacheConfigurationInfo)) {
		my $hostCacheConfigs = $cacheMgr->cacheConfigurationInfo;
		foreach(@$hostCacheConfigs) {
			my $ds_view = Vim::get_view(mo_ref => $_->key, properties => ['name','summary.freeSpace','summary.capacity']);
			my $swap = &prettyPrintData($_->swapSize,'M');
			if($swap eq 0) {
				&print("SSD Datastore: " . $ds_view->{'name'} . "\t SwapSize: " . $swap . "\t Freespace: " . &prettyPrintData($ds_view->{'summary.freeSpace'},'B') . " \t Capacity: " . &prettyPrintData($ds_view->{'summary.capacity'},'B') . " (Disabled)\n","red");
			} else {
				&print("SSD Datastore: " . $ds_view->{'name'} . "\t SwapSize: " . $swap . "\t Freespace: " . &prettyPrintData($ds_view->{'summary.freeSpace'},'B') . " \t Capacity: " . &prettyPrintData($ds_view->{'summary.capacity'},'B') . " (Enabled)\n","green");
			}
		}
	} else {
		&print("No SSD Datastores configured for Host Caching found!","yellow");
	}
} elsif($operation eq "enable") {
	unless($swapspace && $datastore) {
                Util::disconnect();
                &print("Operation \"enable\" requires \"swapspace\" and \"datastore\" variables to be defined\n\n","yellow");
                exit 1;
        }
	&addAndRemoveDatastoreToHostCache($cacheMgr,"enable");
} elsif($operation eq "disable") {
	unless($datastore) {
                Util::disconnect();
                &print("Operation \"disable\" requires \"datastore\" variables to be defined\n\n","yellow");
                exit 1;
        }
	&addAndRemoveDatastoreToHostCache($cacheMgr,"disable");
}

Util::disconnect();

sub addAndRemoveDatastoreToHostCache {
	my ($hostCacheMgr,$op) = @_;

	my $datastore_view = Vim::find_entity_view(view_type => 'Datastore', filter => {'name' => $datastore});
	unless($datastore_view) {
		Util::disconnect();
		&print("Unable to locate datastore: \"$datastore\"\n\n","red");
		exit 1;
	}

	unless($datastore_view->info->isa("VmfsDatastoreInfo")) {
		Util::disconnect();
                &print("Host Cache only supports VMFS \"$datastore\"!\n\n","red");
                exit 1;
	}

	unless($datastore_view->info->vmfs->ssd) {
		Util::disconnect();
                &print("\"$datastore\" is not SSD backed!\n\n","red");
                exit 1;
	}
	
	my ($task,$msg,$spec);
	if($op eq "disable") {
		&print("Disabling datastore ...\n","cyan");
		$spec = HostCacheConfigurationSpec->new(datastore => $datastore_view, swapSize => 0);
		$msg = "Successfully disabled \"$datastore\" for host caching!\n";
	} else {
		&print("Enabling datastore ...\n","cyan");
		$spec = HostCacheConfigurationSpec->new(datastore => $datastore_view, swapSize => $swapspace);
		$msg = "Successfully enabled \"$datastore\" for host caching!\n";
	}
	$task = $hostCacheMgr->ConfigureHostCache_Task(spec => $spec);
        &getStatus($task,$msg);

}

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print color("green") . $message . color("reset");
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
                        Util::disconnect();
                        die color("red") . $soap_fault . color("reset") . "\n";
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}

#http://www.bryantmcgill.com/Shazam_Perl_Module/Subroutines/utils_convert_bytes_to_optimal_unit.html
sub prettyPrintData{
        my($bytes,$type) = @_;

        return '' if ($bytes eq '' || $type eq '');
        return 0 if ($bytes <= 0);

        my($size);

        if($type eq 'B') {
                $size = $bytes . ' Bytes' if ($bytes < 1024);
                $size = sprintf("%.2f", ($bytes/1024)) . ' KB' if ($bytes >= 1024 && $bytes < 1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }
        elsif($type eq 'M') {
                $bytes = $bytes * (1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }

        elsif($type eq 'G') {
                $bytes = $bytes * (1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }
        elsif($type eq 'MHZ') {
                $size = sprintf("%.2f", ($bytes/1e-06)) . ' MHz' if ($bytes >= 1e-06 && $bytes < 0.001);
                $size = sprintf("%.2f", ($bytes*0.001)) . ' GHz' if ($bytes >= 0.001);
        }

        return $size;
}

sub validateSystem {
        my ($ver,$product) = @_;

        if(!grep(/$ver/,@supportedVersion)) {
                Util::disconnect();
                &print("Error: This script only supports vSphere \"@supportedVersion\" or greater!\n\n","red");
                exit 1;
        }

	if($product ne $productSupport && $productSupport ne "both") {
		Util::disconnect();
                &print("Error: This script only supports vSphere $productSupport!\n\n","red");
                exit 1;
	}
}

sub print {
	my ($msg,$color) = @_;

	print color($color) . $msg . color("reset");
}

=head1 NAME

hostCacheManagement.pl - Script to manage SSD host cache

=head1 Examples

=over 4

=item List available SSD datastores

=item 

./hostCacheManagement.pl --server [VCENTER_SERVER|ESXi] --username [USERNAME] --operation list

=item Enable SSD datastore for host cache

=item

./hostCacheManagement.pl --server [VCENTER_SERVER|ESXi] --username [USERNAME] --operation enable --datastore [DATASTORE] --swapspace [SWAP_SPACE_IN_MB]

=item Disable SSD datastore for host cache

=item

./hostCacheManagement.pl --server [VCENTER_SERVER|ESXi] --username [USERNAME] --operation disable --datastore [DATASTORE]

=back



=head1 SUPPORT

vSphere 5.0

=head1 AUTHORS

William Lam, http://www.virtuallyghetto.com/

=cut
