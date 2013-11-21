#!/usr/bin/perl -w
# William Lam 
# 01/15/09
# http://engineering.ucsb.edu/~duonglt/vmware
# http://communities.vmware.com/docs/DOC-9852

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;
use Term::ANSIColor;

my %opts = (
   hostlist => {
      type => "=s",
      help => "Lists of ESX(i) hosts to perform operation _IF_ they're being managed by vCenter (default is ALL hosts in vCenter)",
      required => 0,
   },
   operation => { 
      type => "=s",
      help => "Operation to perform [query|enable|disable]",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $hostlist = Opts::get_option('hostlist');
my $operation = Opts::get_option('operation');
my @supportedVersion = qw(4.1.0 4.5.0);
my @hardwareAccelerationConfigs = qw(VMFS3.HardwareAcceleratedLocking DataMover.HardwareAcceleratedMove DataMover.HardwareAcceleratedInit);
my ($HOST,$VHAL,$DMHAM,$DMHAI) = ("","","","");

my (@hosts,$content,$host_view);

$content = Vim::get_service_content();

if($content->about->apiType eq 'HostAgent') {
	$host_view = Vim::find_entity_view(view_type => 'HostSystem');
	&validateSystem($host_view);
	&checkOperation($host_view,$operation);
} else {
	if($hostlist) {
		&processFile($hostlist);
		if($operation eq 'query') {
                	&printHeader();
		}
		foreach(@hosts) {
			$host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { 'name' => $_});
			if($host_view) {
				&validateSystem($host_view);
				if($operation eq 'query') {
			                &queryHWAcceleration($host_view);
			        }elsif($operation eq 'enable') {
			                &configureHWAcceleration($host_view,1);
			        }elsif($operation eq 'disable') {
			                &configureHWAcceleration($host_view,0);
			        }
			}
		}
	}
}

Util::disconnect();

####################################
#       HELPER FUNCTIONS
####################################

sub printHeader {
        format Info =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$HOST,	$VHAL,	$DMHAM,	$DMHAI
---------------------------------------------------------------------------------------------------------------------------------------
.

$~ = 'Info';

($HOST,$VHAL,$DMHAM,$DMHAI) = ("HOST","VMFS3.HardwareAcceleratedLocking","DataMover.HardwareAcceleratedMove","DataMover.HardwareAcceleratedInit");
write;
}

sub validateSystem {
        my ($host) = @_;

	my $ver = $host->config->product->apiVersion;

        if(!grep(/$ver/,@supportedVersion)) {
                Util::disconnect();
                print color("red") . "Error: This script only supports vSphere ".@supportedVersion." or greater!\n\n" . color("reset");
                exit 1;
        }

	my $vStorage = $host->capability->vStorageCapable;
	if(!$vStorage) {
		Util::disconnect();
                print color("red") . "Error: vStorage Hardware Acceleration is not supported on this host!\n\n" . color("reset");
                exit 1;
	}
}

sub queryHWAcceleration {
	my ($host) = @_;

	my $advConfigurations = Vim::get_view(mo_ref => $host->configManager->advancedOption);	

	$HOST = $host->name;

	foreach(@hardwareAccelerationConfigs) {
		my $options = $advConfigurations->QueryOptions(name => $_);

		foreach(@$options) {
			if($_->key eq "VMFS3.HardwareAcceleratedLocking") {
				$VHAL = ($_->value ? "ENABLED" : "DISABLED");
			}
			if($_->key eq "DataMover.HardwareAcceleratedMove") {
				$DMHAM = ($_->value ? "ENABLED" : "DISABLED");
			}
			if($_->key eq "DataMover.HardwareAcceleratedInit") {
				$DMHAI = ($_->value ? "ENABLED" : "DISABLED");
			}
		}
	}
	write;	
}

sub configureHWAcceleration {
        my ($host,$val) = @_;

        my $advConfigurations = Vim::get_view(mo_ref => $host->configManager->advancedOption);

        my $change = ($val ? "Enabling" : "Disabling");

        print color("cyan") . $change . " VAAI Advanced Configurations for " . $host->name . " ...\n" . color("reset");

        my @options = ();
        foreach(@hardwareAccelerationConfigs) {
                my $value = new PrimType($val,"long");
                my $option = OptionValue->new(key => $_, value => $value);
                push @options,$option;
        }
	if(@options) {
	        eval {
			$advConfigurations->UpdateOptions(changedValue => \@options);
			print color("green") . "\tSuccessfully updated VAAI Advanced Configurations!\n" . color("reset");
	        };
        	if($@) {
        		print color("red") . "ERROR in " . $change . " " . $_ . " - " . $@ . "\n" . color("reset");
        	}
	} else {
		print color("red") . "ERROR unable to create advanced options to update\n" . color("reset");
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
                push @hosts,$_;
        }
        close(CONFIG);
}
