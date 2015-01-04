#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/05/esxi-migration-worksheet-script.html

# import runtime libraries
use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'hostlist' => {
      type => "=s",
      help => "List of ESX(i) host to extract data",
      required => 0,
   },
   'output' => => {
      type => "=s",
      help => "Output to CSV [html|csv]",
      required => 1,
   },
);

# read and validate command-line parameters
Opts::add_options(%opts);
Opts::parse();
Opts::validate();

my $output = Opts::get_option("output");
my $hostlist = Opts::get_option("hostlist");
my $fileoutput;
my %hostlists = ();

# connect to the server and login
Util::connect();

my $service_content = Vim::get_service_content();

if($hostlist) {
	&processHostfile($hostlist);
}
&processHosts($service_content);

# close server connection
Util::disconnect();

sub processHosts {
        my ($sc) = @_;

	#vCenter
	if($sc->about->apiType eq "VirtualCenter") {
		#clusters
		my $ccr = Vim::find_entity_views(view_type => 'ClusterComputeResource');
		#standalone
		my $cr = Vim::find_entity_views(view_type => 'ComputeResource');

		my @list = (@$ccr,@$cr);
		my %seen = ();
		my @unique = grep { ! $seen{$_->name} ++ } @list;

		my $cluster_views = \@unique;

		foreach my $cluster(sort {$a->name cmp $b->name} @$cluster_views) {
			my $hosts = Vim::get_views(mo_ref_array => $cluster->host);
			foreach my $host(sort {$a->name cmp $b->name} @$hosts) {
				if($hostlist) {
					next if(!$hostlists{$host->name});
				}

				if($host->config->product->productLineId eq "esx") {
					print "Processing " . $host->name . "\n";
					my $host_version = $host->config->product->fullName;
	                                &getHostSettings($host,$cluster->name,$host_version);
					&getHostStorage($host);
					&getHostNetwork($host);
                                }
			}
		}
	} elsif($sc->about->productLineId eq "esx") {
		my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
		my $host_version = $sc->about->fullName;
		print "Processing " . $host_view->name . "\n";
                &getHostSettings($host_view,undef,$host_version);
                &getHostStorage($host_view);
		&getHostNetwork($host_view);
	} else {
		print "Unable to locate any classic ESX Servers\n";
	}
}

sub getHostSettings {
	my ($hostsystem,$cluster,$hostversion) = @_;

	my ($hostname,$cpu,$ht,$sc_gateway,$vmk_gateway) = ("N/A","N/A","N/A","N/A","N/A");
	my ($ipAddress,$netmask,$dnsString,$ntpString);

	$cpu = $hostsystem->summary->hardware->cpuModel;

	if(!defined($cluster)) {
		$cluster = "N/A";
	}

	if(defined($hostsystem->config->hyperThread)) {
		$ht = ($hostsystem->config->hyperThread->active ? "YES" : "NO");
	}

	if(defined($hostsystem->config->network->dnsConfig)) {
		$hostname = $hostsystem->config->network->dnsConfig->hostName . "." . $hostsystem->config->network->dnsConfig->domainName;
		if(defined($hostsystem->config->network->dnsConfig->address)) {
			my $dns = $hostsystem->config->network->dnsConfig->address;
			foreach(@$dns) {
				$dnsString .= $_ . "<br>";
			}
		} else {
			$dnsString = "N/A";
		}
	}

	$fileoutput = $hostname . "." . $output;
        print "Generating $fileoutput ...\n";
	
	if(defined($hostsystem->config->network->consoleVnic)) {
		my $cosVnics = $hostsystem->config->network->consoleVnic;
		foreach(@$cosVnics) {
			if(defined($_->spec->ip->ipAddress)) {
				$ipAddress .= $_->spec->ip->ipAddress . "<br>";
			}
			if(defined($_->spec->ip->subnetMask)) {
				$netmask .= $_->spec->ip->subnetMask . "<br>";
			}
		}
	} else { ($ipAddress,$netmask) = ("N/A","N/A"); }

	if(defined($hostsystem->config->network->consoleIpRouteConfig)) {
		$sc_gateway = (defined($hostsystem->config->network->consoleIpRouteConfig->defaultGateway) ? $hostsystem->config->network->consoleIpRouteConfig->defaultGateway : "N/A");
	}

	if(defined($hostsystem->config->network->ipRouteConfig)) {
		$vmk_gateway = (defined($hostsystem->config->network->ipRouteConfig->defaultGateway) ? $hostsystem->config->network->ipRouteConfig->defaultGateway : "N/A");
	}

	if(defined($hostsystem->config->dateTimeInfo->ntpConfig->server)) {
		my $ntp = $hostsystem->config->dateTimeInfo->ntpConfig->server;
		foreach(@$ntp) {
			$ntpString .= $_ . "<br>";
		}
	} else {
		$ntpString = "N/A";
	}

	if($output eq "html") {
		open(REPORT,">$fileoutput");

		my $out = <<HTML_HOST_SETTINGS;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta name="author" content="William Lam"/>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<title>Host Configuration Worksheet - $hostname </title>
</head>
<style type="text/css">
<!--
th { font-weight:bold; background-color:#CCCCCC; }
//-->
</style>
<body>
<h1>ESX Host Configuration Worksheet: $hostname<h1>

<h2>Host Settings</h2>
<table border=1>
<tr><th>Hostname</th><th>Version</th><th>IP Address</th><th>Netmask</th><th>CPU</th><th>Hyperthreading</th><th>Cluster</th></tr>
<tr><td>$hostname</td><td>$hostversion</td><td>$ipAddress</td><td>$netmask</td><td>$cpu</td><td>$ht</td><td>$cluster</td></tr>
<tr></tr>
<tr><th>Service Console GW</th><th>VMkernel GW</th><th>DNS</th><th>NTP Server</th><th colspan=3>Syslog Server</th></tr>
<tr><td>$sc_gateway</td><td>$vmk_gateway</td><td>$dnsString</td><td>$ntpString</td><td colspan=3><br\></td></tr>
</table>
<br>
HTML_HOST_SETTINGS

		print REPORT $out;
		close(REPORT);
	} else {
		open(REPORT,">$fileoutput");
		print REPORT "Hostname,IP Address,Netmask,CPU,Hyperthreading,Cluster\n";
		print REPORT "$hostname,$ipAddress,$netmask,$cpu,$ht,$cluster\n";
		print REPORT "Service Console GW,VMkernel GW,Pri DNS/Sec DNS,NTP Server,Syslog Server\n";
		print REPORT "$sc_gateway,$vmk_gateway,$dnsString,$ntpString,,\n";
		close(REPORT);
	}
}

sub getHostStorage {
	my ($hostsystem) = @_;

	my $storageSys = Vim::get_view(mo_ref => $hostsystem->configManager->storageSystem);
	my $hbas = $storageSys->storageDeviceInfo->hostBusAdapter;
	my $adapters = $storageSys->storageDeviceInfo->plugStoreTopology->adapter;
	my $scsiAdapters = $storageSys->storageDeviceInfo->scsiTopology->adapter;
	my $paths = $storageSys->storageDeviceInfo->plugStoreTopology->path;
	my $luns = $storageSys->storageDeviceInfo->multipathInfo->lun;
	my $fsInfo = $storageSys->fileSystemVolumeInfo->mountInfo;

	my ($csvstorageString,$csvstoragePathString,$csvstorageDeviceFCString,$csvstorageDeviceiSCSIString,$csvstorageDeviceLocalString) = ("","","","","");
	my %devices = ();
	foreach my $scsiAdapter (@$scsiAdapters) {
		my $adapter = $scsiAdapter->adapter;
		$adapter =~ s/.*-//g;
		my $targets = $scsiAdapter->target;
		foreach my $target (@$targets) {
			my $luns = $target->lun;
			foreach my $lun (@$luns) {
				$devices{$adapter . "=" . $lun->key} = "yes";
			}
		}
	}

	my %deviceCount = ();
	for my $key ( keys %devices) {
		my ($adpt,$lun) = split("=",$key);
		$deviceCount{$adpt} +=1;
	}

	my %pathCount = ();
	my $storageString;
	foreach my $hba(sort {$a->device cmp $b->device}@$hbas) {
		foreach my $adapter(@$adapters) {
			if($adapter->adapter eq $hba->key) {
				my $paths = $adapter->path;
				if($paths) {
					$pathCount{$hba->device} = @$paths;	
				} else {
					$pathCount{$hba->device} = 0;
				}
			}
		}
		my $type;
		if($hba->isa("HostBlockHba")) {
			$type = "Block";
		} elsif($hba->isa("HostFibreChannelHba")) {
			$type = "FC";
		} elsif($hba->isa("HostInternetScsiHba")) {
			$type = "iSCSI";
		} elsif($hba->isa("HostParallelScsiHba")) {
			$type = "Parallel";
		} else {
			$type = "Unknown";
		}
		$storageString .= "<tr><td>" . $hba->device . "</td><td>" . $type . "</td><td>" . $pathCount{$hba->device} . "</td><td>" . (defined($deviceCount{$hba->device}) ? $deviceCount{$hba->device} : 0) . "</td></tr>\n"; 
		$csvstorageString .= $hba->device . "," . $type . "," . $pathCount{$hba->device} . "," . (defined($deviceCount{$hba->device}) ? $deviceCount{$hba->device} : 0) . "\n";
	}

	my $storagePathString;
	foreach my $path (@$paths) {
		my $adapter = $path->adapter;
		$adapter =~ s/.*-//g;
		my $pathName = $path->name;
                $pathName =~ s/,/ /g;
		my $hba = $adapter . ":C" . $path->channelNumber . ":T" . $path->targetNumber . ":L" . $path->lunNumber;
		$storagePathString .= "<tr><td>" . $hba . "</td><td>" . $pathName . "</td></tr>\n";
		$csvstoragePathString .= $hba . "," . $pathName . "\n";
	}

	my ($storageDeviceLocalString,$storageDeviceFCString,$storageDeviceiSCSIString,$storageDeviceNasString,$csvstorageDeviceNasString) = ("","","","","");
	foreach my $lun (sort @$luns) {
		my $paths = $lun->path;
		foreach my $path (@$paths) {
			my $adapter = $path->adapter;
			$adapter =~ s/.*-//g;
			my $type = $path->adapter;
			$type =~ s/key-vim.host.//g;
			my $naa = $path->key;
			$naa =~ s/.*-//g;
			my $policy = $lun->policy->policy;
			my $prefer = "N/A";
			my $pathName = $path->name;
			$pathName =~ s/,/ /g;
			if($lun->policy->isa("HostMultipathInfoFixedLogicalUnitPolicy")) {
				$prefer = $lun->policy->prefer;
			}

			foreach my $fs (@$fsInfo) {
				next if($fs->volume->isa("HostNasVolume"));
 
				if($type =~ m/FibreChannelHba/ && $fs->volume->isa("HostVmfsVolume")) {
					if($fs->volume->extent->[0]->diskName eq $naa) {
						$storageDeviceFCString .= "<tr><td>" . $adapter . "</td><td>" . $pathName . "</td><td>" . $policy . "</td><td>" . $prefer . "</td><td>" . &prettyPrintData($fs->volume->capacity,'B') . "</td><td>" . $fs->volume->name . "</td><td>" . $fs->volume->version  ."</td></tr>\n";
						$csvstorageDeviceFCString .= $adapter . "," . $pathName . "," . $policy . "," . $prefer . "," . &prettyPrintData($fs->volume->capacity,'B') . "," . $fs->volume->name . "," . $fs->volume->version ."\n";
					}
				}elsif($type =~ m/InternetScsiHba/ && $fs->volume->isa("HostVmfsVolume")) {
					if($fs->volume->extent->[0]->diskName eq $naa) {
						$storageDeviceiSCSIString .= "<tr><td>" . $adapter . "</td><td>" . $pathName . "</td><td>" . $policy . "</td><td>" . $prefer . "</td><td>" . &prettyPrintData($fs->volume->capacity,'B') . "</td><td>" . $fs->volume->name . "</td><td>" . $fs->volume->version  ."</td></tr>\n";
						$csvstorageDeviceiSCSIString .= $adapter . "," . $pathName . "," . $policy . "," . $prefer . "," . &prettyPrintData($fs->volume->capacity,'B') . "," . $fs->volume->name . "," . $fs->volume->version ."\n";
					}
				}elsif($type =~ m/BlockHba/ || $type =~ m/ParallelScsiHba/) {
					if($fs->volume->extent->[0]->diskName eq $naa) {
						$storageDeviceLocalString .= "<tr><td>" . $adapter . "</td><td>" . $pathName . "</td><td>" . $policy . "</td><td>" . $prefer . "</td><td>" . &prettyPrintData($fs->volume->capacity,'B') . "</td><td>" . $fs->volume->name . "</td><td>" . $fs->volume->version  ."</td></tr>\n";
						$csvstorageDeviceLocalString .= $adapter . "," . $pathName . "," . $policy . "," . $prefer . "," . &prettyPrintData($fs->volume->capacity,'B') . "," . $fs->volume->name . "," . $fs->volume->version ."\n";
					}
				}
			}
		}
	}

	foreach my $fs (@$fsInfo) {
		if($fs->volume->isa("HostNasVolume")) {
			$storageDeviceNasString .= "<tr><td>" . $fs->volume->remoteHost . "</td><td>" . $fs->volume->remotePath . "</td><td>" . $fs->volume->name . "</td></tr>\n";
			$csvstorageDeviceNasString .= $fs->volume->remoteHost . "," . $fs->volume->remotePath . "," . $fs->volume->name . "\n";
		}
	}

	if($output eq "html") {
                open(REPORT,">>$fileoutput");

		my $out = <<HTML_HOST_STORAGE;
<h2>Storage</h2>
<table border=1>
<tr><th>Adapter</th><th>Block/FC/iSCSI</th><th># Devices</th><th># Paths</th></tr>
$storageString
</table>
<br>

<h2>Storage Paths</h2>
<table border=1>
<tr><th>Runtime Name</th><th>Path</th></tr>
$storagePathString
</table>
<br>

<h2>Storage Devices (Local Disk)</h2>
<table border=1>
<tr><th>Runtime Name</th><th>Path</th><th>Policy</th><th>Preferred Path</th><th>Size</th><th>Datastore</th><th>VMFS Version</th></tr>
$storageDeviceLocalString
</table>
<br>

<h2>Storage Devices (FC/iSCSI Disk)</h2>
<table border=1>
<tr><th>Runtime Name</th><th>Path</th><th>Policy</th><th>Preferred Path</th><th>Size</th><th>Datastore</th><th>VMFS Version</th></tr>
$storageDeviceFCString
$storageDeviceiSCSIString
</table>
<br>

<h2>Storage Devices (NFS)</h2>
<table border=1>
<tr><th>NFS Server</th><th>Share/Export Name</th><th>Datastore</th></tr>
$storageDeviceNasString
</table>
<br>
HTML_HOST_STORAGE
	
		print REPORT $out;
                close(REPORT);
        } else {
                open(REPORT,">>$fileoutput");
		print REPORT "Adapter,Block/FC/iSCSI,# Devices,# Paths\n";
		print REPORT $csvstorageString;
		print REPORT "Runtime Name,Path\n";
		print REPORT $csvstoragePathString;
		print REPORT "Runtime Name,Path,Policy,Preferred Path,Size,Datastore,VMFS Version\n";
		print REPORT $csvstorageDeviceLocalString;
		print REPORT $csvstorageDeviceFCString;
		print REPORT $csvstorageDeviceiSCSIString;
		print REPORT "NFS Server,Share/Export Name,Datastore\n";
		print REPORT $csvstorageDeviceNasString;
		close(REPORT);
	}
}

sub getHostNetwork {
	my ($hostsystem) = @_;

	my $networkSys = Vim::get_view(mo_ref => $hostsystem->configManager->networkSystem);
	my $pNics = $networkSys->networkInfo->pnic;
	my $vSwitches = $networkSys->networkInfo->vswitch;
	my $portgroups = $networkSys->networkInfo->portgroup;
	my $scs = $networkSys->networkInfo->consoleVnic;
	my $vmks = $networkSys->networkInfo->vnic;

	my %serviceConsoleMapping = ();
	my %vmkernelMapping = ();

	my ($csvpNicString,$csvportgroupString,$csvvSwitchString) = ("","","");

	foreach(@$scs) {
		my $scIp = "N/A";
		if(defined($_->spec->ip->ipAddress)) {
			$scIp = $_->spec->ip->ipAddress;
		}
		$serviceConsoleMapping{$_->portgroup} = $scIp;
	}
	foreach(@$vmks) {
		my $vmkIp = "N/A";
                if(defined($_->spec->ip->ipAddress)) {
                        $vmkIp = $_->spec->ip->ipAddress;
                }
		$vmkernelMapping{$_->portgroup} = $vmkIp;
	}

	my $pNicString;
	my %activepNics = ();
	foreach my $pnic (@$pNics) {
		$activepNics{$pnic->device} = "no";
		my $speed = "N/A";
		if($pnic->spec->linkSpeed) {
			$speed = $pnic->spec->linkSpeed->speedMb;
		}	
		$pNicString .= "<tr><td>" . $pnic->device . "</td><td>" . $speed . "</td><td>" . $pnic->mac . "</td></tr>\n";
		$csvpNicString .= $pnic->device . "," . $speed . "," . $pnic->mac . "\n";
	}

	my $portgroupString;
	foreach my $vSwitch (@$vSwitches) {
		foreach my $portgroup (@$portgroups) {
			if($portgroup->spec->vswitchName eq $vSwitch->name) {
				my $portgroupName = $portgroup->spec->name;
				my $portgroupType = "VM";
				my $portgroupIp = "N/A";
				if(defined($serviceConsoleMapping{$portgroupName})) {
					$portgroupType = "Service Console";
					$portgroupIp = $serviceConsoleMapping{$portgroupName};
				}elsif(defined($vmkernelMapping{$portgroupName})) {
                                        $portgroupType = "VMkernel";
					$portgroupIp = $vmkernelMapping{$portgroupName};
				}
				$portgroupString .= "<tr><td>" . $vSwitch->name . "</td><td>" . $portgroupName . "</td><td>" . $portgroup->spec->vlanId . "</td><td>" . $portgroupType . "</td><td>" . $portgroupIp . "</td></tr>\n";
				$csvportgroupString .= $vSwitch->name . "," . $portgroupName . "," . $portgroup->spec->vlanId . "," .  $portgroupType . "," . $portgroupIp . "\n";
			}
		}
		if(defined($vSwitch->spec->policy->nicTeaming->nicOrder->activeNic)) {
                        my $nics = $vSwitch->spec->policy->nicTeaming->nicOrder->activeNic;
                        foreach(@$nics) {
                                $activepNics{$_} = "yes";
                        }
                }
                if(defined($vSwitch->spec->policy->nicTeaming->nicOrder->standbyNic)) {
                        my $nics = $vSwitch->spec->policy->nicTeaming->nicOrder->standbyNic;
                        foreach(@$nics) {
                                $activepNics{$_} = "yes";
                        }
                }
	}

	my $vSwitchString;
	foreach my $vSwitch (sort {$a->name cmp $b->name}@$vSwitches) {
		my ($promMode,$macMode,$forgeMode,$avgBw,$peakBw,$burstBw,$lb,$failDetect,$notify,$failback) = ("N/A","N/A","N/A","N/A","N/A","N/A","N/A","N/A","N/A","N/A");
		my ($activeAdp,$standbyAdp);	
	
		if(defined($vSwitch->spec->policy->security->allowPromiscuous)) {
			$promMode = ($vSwitch->spec->policy->security->allowPromiscuous ? "YES" : "NO");
		}
		if(defined($vSwitch->spec->policy->security->macChanges)) {
                        $macMode = ($vSwitch->spec->policy->security->macChanges ? "YES" : "NO");
                }
		if(defined($vSwitch->spec->policy->security->forgedTransmits)) {
                        $forgeMode = ($vSwitch->spec->policy->security->forgedTransmits ? "YES" : "NO");
                }
		if(defined($vSwitch->spec->policy->shapingPolicy->averageBandwidth)) {
                        $avgBw = ($vSwitch->spec->policy->shapingPolicy->averageBandwidth ? $vSwitch->spec->policy->shapingPolicy->averageBandwidth : "N/A");
		}
		if(defined($vSwitch->spec->policy->shapingPolicy->peakBandwidth)) {
                        $peakBw = ($vSwitch->spec->policy->shapingPolicy->peakBandwidth ? $vSwitch->spec->policy->shapingPolicy->peakBandwidth : "N/A");
		}
		if(defined($vSwitch->spec->policy->shapingPolicy->burstSize)) {
                        $burstBw = ($vSwitch->spec->policy->shapingPolicy->burstSize ? $vSwitch->spec->policy->shapingPolicy->burstSize : "N/A");
		}
		if(defined($vSwitch->spec->policy->nicTeaming->policy)) {
			$lb = ($vSwitch->spec->policy->nicTeaming->policy ? $vSwitch->spec->policy->nicTeaming->policy : "N/A");
		}
		if(defined($vSwitch->spec->policy->nicTeaming->failureCriteria->checkBeacon)) {
                        $failDetect = ($vSwitch->spec->policy->nicTeaming->failureCriteria->checkBeacon ? "YES" :"NO");
		}
		if(defined($vSwitch->spec->policy->nicTeaming->notifySwitches)) {
                        $notify = ($vSwitch->spec->policy->nicTeaming->notifySwitches ? "YES" : "NO");
		}
		if(defined($vSwitch->spec->policy->nicTeaming->rollingOrder)) {
                        $failback = ($vSwitch->spec->policy->nicTeaming->rollingOrder ? "YES" : "NO");
		}
		if(defined($vSwitch->spec->policy->nicTeaming->nicOrder->activeNic)) {
                        my $nics = $vSwitch->spec->policy->nicTeaming->nicOrder->activeNic;
                        foreach(@$nics) {
                                $activeAdp .= $_ . "<br>";
                        }
                } else {
                        $activeAdp = "N/A";
                }
                if(defined($vSwitch->spec->policy->nicTeaming->nicOrder->standbyNic)) {
                        my $nics = $vSwitch->spec->policy->nicTeaming->nicOrder->standbyNic;
                        foreach(@$nics) {
                                $standbyAdp .= $_ . "<br>";
                        }
                } else {
                        $standbyAdp = "N/A";
                }

		my $unusedAdp = "";
		foreach my $key (keys %activepNics) {
			if($activepNics{$key} eq "no") {
				$unusedAdp .= $key . "<br>";
			}
		}

		$vSwitchString .= "<tr><td>" . $vSwitch->name . "</td><td>" . $promMode . "</td><td>" . $macMode . "</td><td>" . $forgeMode . "</td><td>" . $avgBw . "</td><td>" . $peakBw . "</td><td>" . $burstBw . "</td><td>" . $lb . "</td><td>" . $failDetect . "</td><td>" . $notify . "</td><td>" . $failback . "</td><td>" . $activeAdp . "</td><td>" . $standbyAdp . "</td><td>" . $unusedAdp . "</td><tr>\n";
		$csvvSwitchString .= $vSwitch->name . "," . $promMode . "," . $macMode . "," . $forgeMode . "," . $avgBw . "," . $peakBw . "," . $burstBw . "," . $lb . "," . $failDetect . "," . $notify . "," . $failback . "," . $activeAdp . "," . $standbyAdp . "," . $unusedAdp . "\n";
	}

	if($output eq "html") {
                open(REPORT,">>$fileoutput");

                my $out = <<HTML_HOST_NETWORK;
<h2>Network</h2>
<table border=1>
<tr><th>vNIC</th><th>Speed</th><th>MAC Address</th></tr>
$pNicString
</table>
<br>

<table border=1>
<tr><th>vSwitch</th><th>Port Group</th><th>VLAN</th><th>Type</th><th>IP</th></tr>
$portgroupString
</table>
<br>

<table border=1>
<tr><th>vSwitch</th><th>Promiscuous Mode</th><th>Mac Address Changes</th><th>Forged Transmits</th><th>Avg BW</th><th>Peak BW</th><th>Burst Size</th><th>Load Bal</th><th>Net Fail Detection</th><th>Notify Switches</th><th>Failback</th><th>Active Adapters</th><th>Standby Adapters</th><th>Unused Adapters</th></tr>
$vSwitchString
</table>
<br>
HTML_HOST_NETWORK

                print REPORT $out;
                close(REPORT);
        } else {
                open(REPORT,">>$fileoutput");
		print REPORT "vNIC,Speed,MAC Address\n";
		print REPORT $csvpNicString;
		print REPORT "vSwitch,Port Group,VLAN,Type,IP\n";
		print REPORT $csvportgroupString;
		print REPORT "vSwitch,Promiscuous Mode,Mac Address Changes,Forged Transmits,Avg BW,Peak BW,Burst Size,Load Bal,Net Fail Detection,Notify Switches,Failback,Active Adapters,Standby Adapters,Unused Adapters\n";
		print REPORT $csvvSwitchString;
                close(REPORT);
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

sub processHostfile {
        my ($config_input) = @_;

        open(CONFIG, "$config_input") || die "Error: Couldn't open the $config_input!";
        while (<CONFIG>) {
                chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;
                $hostlists{$_} = "yes";
        }
        close(CONFIG);
}
