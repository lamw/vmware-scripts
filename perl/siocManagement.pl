#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2010/07/script-automate-storage-io-control-in.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;
use Term::ANSIColor;

my %opts = (
   operation => {
      type => "=s",
      help => "Operation to perform [query|enable|disable|update]",
      required => 1,
   },
   vihost => {
      type => "=s",
      help => "Name of ESX(i) to perform operation on",
      required => 1,
   },
   datastore_inputfile => {
      type => "=s",
      help => "Name of input file for bulk datastore updates",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $vihost = Opts::get_option('vihost');
my $datastore_inputfile  = Opts::get_option('datastore_inputfile');

my ($host_view,$DS_NAME,$SIOC_ENABLED,$LATENCY_VAL);
my $content = Vim::get_service_content();
my %datastoreInput = ();

if($content->about->apiType eq 'VirtualCenter') {
	$host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { 'name' => $vihost});
} else {
	print color("red") . "SIOC operations are only supported when connecting to vCenter\n\n" . color("reset");
	Util::disconnect();
	exit 1;
}

if($operation eq 'query') {
	&querySIOC($host_view);
}elsif($operation eq 'enable') {
	unless($datastore_inputfile) {
		print "Operation \"enable\" requires param \"datastore_inputfile\" to be defined!\n";
		Util::disconnect();
	        exit 1;
	}
	&processFile($datastore_inputfile);
	&enableSIOC($host_view,1);
}elsif($operation eq 'disable') {
        unless($datastore_inputfile) {
                print "Operation \"disable\" requires param \"datastore_inputfile\" to be defined!\n";
                Util::disconnect();
                exit 1;
        }
	&processFile($datastore_inputfile);
        &disableSIOC($host_view);
}elsif($operation eq 'update') {
        unless($datastore_inputfile) {
                print "Operation \"update\" requires param \"datastore_inputfile\" to be defined!\n";
                Util::disconnect();
                exit 1;
        }
	&processFile($datastore_inputfile);
        &enableSIOC($host_view,2);
}


Util::disconnect();

##########################
#### HELPER FUNCTIONS ####
##########################

sub disableSIOC {
        my ($host) = @_;

	foreach my $ds (sort keys %datastoreInput) {
		my $datastore = &find_datastore($ds,$host);
		my $latency = $datastoreInput{$ds};
		if($datastore && ($latency >= 10 && $latency <= 100)) {
	                my $iormSpec = StorageIORMConfigSpec->new(enabled => 'false');
                	my $storageMgr = &getStorageMgr();
	                eval {
        	                print color("cyan") . "Disabling SIOC on \"$ds\"\n" . color("reset");
                	        my $task = $storageMgr->ConfigureDatastoreIORM_Task(datastore => $datastore, spec => $iormSpec);
                        	my $msg = color("green") . "\tSucessfully disabled SIOC on datastore!\n" . color("reset");
	                        &getStatus($task,$msg);
        	        };
                	if($@) {
                        	print color("red") . "ERROR in disabling SIOC for \"$ds\" - " . $@ . "\n" . color("reset");
                	}
		} else {
			if(!$datastore) {
                                print color("red") . "Unable to locate datastore \"$ds\"!\n" . color("reset");
                        } else {
                                print color("red") . "Unable to configure SIOC for datastore \"$ds\", congestion latency must be between 10-100ms!\n" . color("reset");
                        }
		}
        }
}

sub enableSIOC {
	my ($host,$type) = @_;

	my ($string1,$string2) = ("","");
	if($type eq 1) {
		($string1,$string2) = ("Enabling","enabled");
	} else {
		($string1,$string2) = ("Upating","updated");
	}

	foreach my $ds (sort keys %datastoreInput) {
		my $datastore = &find_datastore($ds,$host);
		my $latency = $datastoreInput{$ds};
                if($datastore && ($latency >= 10 && $latency <= 100)) {
			my $iormSpec = StorageIORMConfigSpec->new(enabled => 'true', congestionThreshold => $latency);
			my $storageMgr = &getStorageMgr();
			eval {
				print color("cyan") . "$string1 SIOC on \"$ds\" with congestion latency set to $latency ms\n" . color("reset");
				my $task = $storageMgr->ConfigureDatastoreIORM_Task(datastore => $datastore, spec => $iormSpec);
				my $msg = color("green") . "\tSucessfully $string2 SIOC on datastore!\n" . color("reset");
	        	        &getStatus($task,$msg);
			};
			if($@) {
				print color("red") . "ERROR in $string1 SIOC for \"$ds\" - " . $@ . "\n" . color("reset");
			}
		} else {
			if(!$datastore) {
				print color("red") . "Unable to locate datastore \"$ds\"!\n" . color("reset");
			} else {
				print color("red") . "Unable to configure SIOC for datastore \"$ds\", congestion latency must be between 10-100ms!\n" . color("reset");
			}
		}
	}
}

sub querySIOC {
	my ($host) = @_;
	format Info =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<
$DS_NAME,       $SIOC_ENABLED,  $LATENCY_VAL
----------------------------------------------------------------------------------
.

$~ = 'Info';
($DS_NAME,$SIOC_ENABLED,$LATENCY_VAL) = ('DATASTORE','SIOC ENABLED','CONGESTION LATENCY');
write;

        my $datastores = Vim::get_views(mo_ref_array => $host->datastore);
        foreach(@$datastores) {
                if($_->iormConfiguration & $_->capability->storageIORMSupported) {
                        $DS_NAME = $_->name;
                        $SIOC_ENABLED = ($_->iormConfiguration->enabled ? "YES" : "NO");
                        $LATENCY_VAL = $_->iormConfiguration->congestionThreshold;
                        write;
                }
        }
}

sub getStorageMgr {
	return Vim::get_view(mo_ref => $content->storageResourceManager);
}

sub find_datastore {
	my ($dsname,$host) = @_;
   	my $datastores = Vim::get_views(mo_ref_array => $host->datastore);
	foreach my $datastore (@$datastores) {
      		return $datastore if ($datastore->summary->name eq $dsname);
   	}
   	return undef;
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
		my ($DS,$LAT) = split(';',$_,2);
		chomp($DS);
		$LAT =~ s/^\s+//;
		chomp($LAT);
		$datastoreInput{$DS} = $LAT;
        }
        close(CONFIG);
}
