#!/usr/bin/perl -w
# Author: William Lam
# Site: www.virtuallyghetto.com
# Description: Script leveraging the new API for VDS Backup/Export feature
# Reference: https://blogs.vmware.com/vsphere/2013/01/automate-backups-of-vds-distributed-portgroup-configurations-in-vsphere-5-1.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use MIME::Base64;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Path;
use XML::LibXML;

my %opts = (
   vds => {
      type => "=s",
      help => "Name of VDS",
      required => 0,
   },
   operation => {
      type => "=s",
      help => "[list-vds|backup-vds|backup-dvpg|view-backup]",
      required => 1,
   },
   dvpg => {
      type => "=s",
      help => "Name of Distributed Port Group",
      required => 0,
   },
   backupname => {
      type => "=s",
      help => "Name of backup file",
      required => 0,
   },
   note => {
      type => "=s",
      help => "Custom note",
      required => 0,
   },
   schema => {
      type => "=s",
      help => "XML schema file",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();

my $vds = Opts::get_option('vds');
my $dvpg = Opts::get_option('dvpg');
my $operation = Opts::get_option('operation');
my $backupname = Opts::get_option('backupname');
my $note = Opts::get_option('note');
my $schema = Opts::get_option('schema');
my ($vdsMgr,$dvPortgroups);

if($operation ne "view-backup") {
	Util::connect();
	$vdsMgr = Vim::get_view(mo_ref => Vim::get_service_content()->dvSwitchManager);
}


if($operation eq "list-vds") {
        my $dvSwitches = Vim::find_entity_views(view_type => 'DistributedVirtualSwitch', properties => ['name','summary.productInfo.vendor','capability.featuresSupported','portgroup']);
	foreach my $dvSwitch(@$dvSwitches) {
		if($dvSwitch->{'summary.productInfo.vendor'} eq "VMware" && defined($dvSwitch->{'capability.featuresSupported'}->backupRestoreCapability)) {
			if($dvSwitch->{'capability.featuresSupported'}->backupRestoreCapability->backupRestoreSupported) {
				print "VDS: " . $dvSwitch->{'name'} . "\n";
				my $dvPortgroups = eval {$dvSwitch->{portgroup} || []};
				foreach my $dvPortgroup(@$dvPortgroups) {
					my $dvPortgroup_view = Vim::get_view(mo_ref => $dvPortgroup, properties => ['name','tag']);
					if(!$dvPortgroup_view->{tag}) {
						print $dvPortgroup_view->{'name'} . "\n";
					}
				}
				print "\n";
			}
		}
	}
} elsif($operation eq "backup-vds" || $operation eq "backup-dvpg") {
	my %fileMapping =();
	my $fileCount = 0;

	if($operation eq "backup-vds") {
		unless($backupname && $vds) {
			print "\n\"backup-vds\" option requires \"backupname\" and \"vds\" parameter!\n";
			Util::disconnect();
        	        exit 1;
		}
	} else {
		unless($backupname && $vds && $dvpg) {
                        print "\n\"backup-dvpg\" option requires \"backupname\", \"vds\" and \"dvpg\" parameter!\n";
                        Util::disconnect();
                        exit 1;
                }
	}

	# get VDS
	my $dvSwitch = &findVDS($vds);
	# Map file0 to dvSwitch UUID
	$fileMapping{$dvSwitch->{'uuid'}} = "file" . $fileCount;

	# folders for backup
	my $backupFolderName = "vds-backup-" . time;
        my $zipFileName = $backupname . "-" . &giveMeDate("other") . ".zip";
        my $dataFolderName = "$backupFolderName/data";
        my $metaFolderName = "$backupFolderName/META-INF";
        my $metaDataFileName = "$metaFolderName/data.xml";
        mkdir $backupFolderName;

        print "\nCreating temp folder " . $backupFolderName . "\n";
        if(! -e $backupFolderName) {
                print "\nUnable to create temp backup folder " . $backupFolderName . "!\n";
                Util::disconnect();
                exit 1;
        } else {
                mkdir $dataFolderName;
                mkdir $metaFolderName;
        }

	# get DvPg
	$dvPortgroups = $dvSwitch->portgroup;
	# backup of individual dvportgroup
	if($dvpg) {
		$dvPortgroups = &findDvpg($dvpg);
	}

	# get DvPg keys
	my @dvPgKeys = ();
	foreach my $dvPg(@$dvPortgroups) {
		my $dvPg_view = Vim::get_view(mo_ref => $dvPg);
		$fileCount++;
		$fileMapping{$dvPg_view->key} = "file" . $fileCount;
		push @dvPgKeys,$dvPg_view->key;
	}

	my $VDSSelectionSet = DVSSelection->new(dvsUuid => $dvSwitch->{'uuid'});
	my $DvPgSelectionSet = DVPortgroupSelection->new(dvsUuid => $dvSwitch->{'uuid'}, portgroupKey => \@dvPgKeys);
	my ($task,$msg);
	eval {
		print "Backing up VDS " . $vds . " ...\n";
		$msg = "Successfully backed up VDS configuration!";
		$task = $vdsMgr->DVSManagerExportEntity_Task(selectionSet => [$VDSSelectionSet,$DvPgSelectionSet]);
		my $results = &getStatus($task,$msg);
		if(defined($results)) {
			foreach my $result(@$results) {
				if($result->entityType eq "distributedVirtualSwitch") {
					my $decoded = decode_base64($result->configBlob);
					open(BLOBFILE,">" . $dataFolderName . "/" . $dvSwitch->{'uuid'} . ".bak");
					binmode(BLOBFILE);
					print BLOBFILE $decoded;
					close(BLOBFILE);
				} elsif($result->entityType eq "distributedVirtualPortgroup") {
					my $decoded = decode_base64($result->configBlob);
                                        open(BLOBFILE,">" . $dataFolderName . "/" . $result->key . ".bak");
                                        binmode(BLOBFILE);
                                        print BLOBFILE $decoded;
                                        close(BLOBFILE);
				}
			}
			print "Building XML file ...\n";
			&buildAndSaveXML($dvSwitch,$dvPortgroups,$metaDataFileName,%fileMapping);
		} else {
			print "No results from backup, something went wrong!\n";
			exit 1;
		}
	};
	if($@) {
		print "ERROR: Unable to backup VDS " . $@ . "\n";
		exit 1;
	}

	# zip backup files
	my $zipObj = Archive::Zip->new();
	$zipObj->addTree($dataFolderName,'data');
	$zipObj->addTree($metaFolderName,'META-INF');
	print "Creating " . $zipFileName . " ...\n";
	unless ($zipObj->writeToFileNamed($zipFileName) == AZ_OK) {
		print "Unable to write " . $zipFileName . "!\n";
		Util::disconnect();
		rmtree($backupFolderName);
		exit 1;
	}
	print "Succesfully completed VDS backup!\n";
	print "Removing temp folder " . $backupFolderName . "\n\n";
	rmtree($backupFolderName);
} elsif($operation eq "backup-dvpg") {
	 my $dvSwitch = &findVDS($vds);
} elsif($operation eq "view-backup") {
	unless($backupname) {
                print "\n\"view-backup\" option requires \"backupname\" parameter!\n";
                Util::disconnect();
        	exit 1;
        }

	my $file = IO::File->new($backupname,'r');
	my $zip = Archive::Zip->new();
	my $zip_err = $zip->readFromFileHandle($file);
	unless ($zip_err == AZ_OK ) {
    		print "Unable to open " . $backupname . ": " . $zip_err . "\n";
		Util::disconnect();
		exit 1;
  	}
	foreach my $member ($zip->members()) {
    		my $fileName = $member->fileName();
    		if($fileName eq "META-INF/data.xml") {
    			my $content = $member->contents();
			print Dumper($content);
		}
	}
	exit 0;
} else {
	print "Invalid operation!\n";
}

Util::disconnect();

sub findVDS {
	my ($vdsName) = @_;

	my $dvSwitch = Vim::find_entity_view(view_type => 'DistributedVirtualSwitch', filter => {'name' => $vds});

	unless($dvSwitch) {
		print "Unable to locate VDS " . $vdsName . "\n";
		Util::disconnect();
		exit 1;
	}

	if(!$dvSwitch->capability->featuresSupported->backupRestoreCapability->backupRestoreSupported) {
		print "VDS " . $vdsName . " does not support backup and restore capabilities!\n";
                Util::disconnect();
                exit 1;
	}

	return $dvSwitch;
}

sub findDvpg {
	my ($dvportgroup) = @_;

	my @tmp_arr = ();
	foreach my $dv (@$dvPortgroups) {
		my $dv_view = Vim::get_view(mo_ref => $dv, properties => ['name']);
		if($dv_view->name eq $dvportgroup) {
			push @tmp_arr, $dv;
			last;
		}
	}
	return \@tmp_arr;
}

sub buildAndSaveXML {
	my ($vds,$dvpgs,$fileName,%fileMap) = @_;

	my $createTime = &giveMeDate("zula");
	my $vdsVersion = $vds->summary->productInfo->version;
        my $numRPs = eval { scalar @{$vds->networkResourcePool} || 0};
        my $numUplinks = eval { scalar @{$vds->config->uplinkPortgroup} || 0};
        my $vdsConfigVersion = $vds->config->configVersion;
        my $vdsName = $vds->name;
	my $vdsUuid = $vds->{uuid};
        my $vdsFileRef = $fileMap{$vdsUuid};
        my $vdsMoRef = $vds->{'mo_ref'}->value;
	my %pvlanMapping = ();

	# map all PVLAN primary/secondary
	if($vds->config->isa("VMwareDVSConfigInfo")) {
		if(defined($vds->config->pvlanConfig)) {
			my $pvlans = $vds->config->pvlanConfig;
			foreach my $pvlan(@$pvlans) {
				$pvlanMapping{$pvlan->secondaryVlanId} = $pvlan;
			}
		}
	}

	my $xml = <<XML_START;
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns1:Envelope xmlns:ns1="http://vmware.com/vds/envelope/1">
  <ns1:References>
    <ns1:File ns1:href="data/$vdsUuid.bak" ns1:id="$vdsFileRef"/>
XML_START

	my ($vlanSection,$vlanTrunkSection,$pvlanSection,$dvpgSection) = ("","","","");
	my (%uniqueVlanSection,%uniqueVlanTrunkSection) = ();

	# References
	foreach my $dvpg (@$dvpgs) {
		my $dvpg_view = Vim::get_view(mo_ref => $dvpg);
		my ($trunkPorts,$trunkRanges,$vlanRef,$type,$allocation) = ("","","","standard","elastic");
		my %bindings = ('lateBinding','dynamic','earlyBinding','static','ephemeral','ephemeral');

		if(!$dvpg_view->config->autoExpand) {
                        $allocation = "fixed";
                }
                my $binding = $bindings{$dvpg_view->config->type};
                my $file = $fileMap{$dvpg_view->key};
		my $dvpgConfigVersion = $dvpg_view->config->configVersion;

		$xml .= "    <ns1:File ns1:href=\"data/" . $dvpg_view->key . ".bak\" ns1:id=\"" . $fileMap{$dvpg_view->key} . "\"/>\n";

		# handle uplinks
		if(defined($dvpg_view->tag)) {
			my $tags = $dvpg_view->tag;
			foreach my $tag (@$tags) {
				if($tag->key eq "SYSTEM/DVS.UPLINKPG") {
					$type = "uplink";
					$trunkPorts = "";
					my $vlans = $dvpg_view->config->defaultPortConfig->vlan->vlanId;
					foreach my $vlan (@$vlans) {
						$trunkPorts .= $vlan->start . "-" . $vlan->end . "_";
						$trunkRanges .= "    <ns1:VlanTrunkRange ns1:end=\"". $vlan->end . "\" ns1:start=\"" . $vlan->start . "\"/>\n";
					}
				}
			}
			if($trunkPorts ne "") {
				my $vlanTrunkSec = "  <ns1:VlanTrunk ns1:id=\"trunk_" . $trunkPorts . "\">\n" . $trunkRanges . "  </ns1:VlanTrunk>\n";;

				if(!$uniqueVlanTrunkSection{$vlanTrunkSec}) {
					$uniqueVlanTrunkSection{$vlanTrunkSec} = "yes";
					$vlanTrunkSection .= $vlanTrunkSec;
				}
				$dvpgSection .= &sectionNode("trunk_" . $trunkPorts,$allocation,$binding,$type,$file,$dvpgConfigVersion,$dvpg_view->name,$dvpg_view->{'mo_ref'}->value);
			}
		# dvpgs
		} else {
			$type = "standard";
			# trunk
			if($dvpg_view->config->defaultPortConfig->vlan->isa("VmwareDistributedVirtualSwitchTrunkVlanSpec")) {
				my $vlans = $dvpg_view->config->defaultPortConfig->vlan->vlanId;
                                foreach my $vlan (@$vlans) {
                                	$trunkPorts .= $vlan->start . "-" . $vlan->end . "_";
                                        $trunkRanges .= "    <ns1:VlanTrunkRange ns1:end=\"". $vlan->end . "\" ns1:start=\"" . $vlan->start . "\"/>\n";
                                }
				if($trunkPorts ne "") {
					my $vlanTrunkSec = "  <ns1:VlanTrunk ns1:id=\"trunk_" . $trunkPorts . "\">\n" . $trunkRanges . "  </ns1:VlanTrunk>\n";;

	                                if(!$uniqueVlanTrunkSection{$vlanTrunkSec}) {
        	                                $uniqueVlanTrunkSection{$vlanTrunkSec} = "yes";
                	                        $vlanTrunkSection .= $vlanTrunkSec;
                        	        }
					$dvpgSection .= &sectionNode("trunk_" . $trunkPorts,$allocation,$binding,$type,$file,$dvpgConfigVersion,$dvpg_view->name,$dvpg_view->{'mo_ref'}->value);
				}
			# pvlan
			} elsif($dvpg_view->config->defaultPortConfig->vlan->isa("VmwareDistributedVirtualSwitchPvlanSpec")) {
				my $pvlan = $pvlanMapping{$dvpg_view->config->defaultPortConfig->vlan->pvlanId};
				my $primaryVlanRef = $pvlan->primaryVlanId;
				my $secondaryVlanRef = $pvlan->secondaryVlanId;
				my $pvlanType = $pvlan->pvlanType;
				my $pvlanId = "private_" . $primaryVlanRef . "_" . $secondaryVlanRef;
				$pvlanSection .= "    <ns1:PrivateVlan ns1:pvlanType=\"" . $pvlanType . "\" ns1:secondary=\"" . $secondaryVlanRef . "\" ns1:primary=\"" . $primaryVlanRef . "\" ns1:id=\"" . $pvlanId . "\"/>\n";
				$dvpgSection .= &sectionNode($pvlanId,$allocation,$binding,$type,$file,$dvpgConfigVersion,$dvpg_view->name,$dvpg_view->{'mo_ref'}->value);
			# vlan
			} elsif($dvpg_view->config->defaultPortConfig->vlan->isa("VmwareDistributedVirtualSwitchVlanIdSpec")) {
				$vlanRef = $dvpg_view->config->defaultPortConfig->vlan->vlanId;

				my $vlanSec = "    <ns1:VlanAccess ns1:vlan=\"" . $vlanRef . "\" ns1:id=\"access_" . $vlanRef . "\"/>\n";

				# capture only unique vlan section
				if(!$uniqueVlanSection{$vlanSec}) {
					$uniqueVlanSection{$vlanSec} = "yes";
					$vlanSection .= $vlanSec;
				}
				$dvpgSection .= &sectionNode("access_" . $vlanRef,$allocation,$binding,$type,$file,$dvpgConfigVersion,$dvpg_view->name,$dvpg_view->{'mo_ref'}->value);
			}
		}
	}

	$xml .= "</ns1:References>\n";
	$xml .= "  <ns1:AnnotationSection>\n";
	if(!defined($note)) {
		$note = "Backup created with vdsBackupMgr.pl on " . &giveMeDate("other");
	}
        $xml .= "    <ns1:Annotation>" . $note . "</ns1:Annotation>\n";
        $xml .= "    <ns1:CreateTime>" . $createTime . "</ns1:CreateTime>\n";
	$xml .= "  </ns1:AnnotationSection>\n";
	$xml .= "  <ns1:DistributedSwitchSection>\n";
	$xml .= "    <ns1:DistributedSwitch ns1:version=\"" . $vdsVersion . "\" ns1:numberOfResourcePools=\"" . $numRPs . "\" ns1:numberOfUplinks=\"" . $numUplinks . "\" ns1:configVersion=\"" . $vdsConfigVersion . "\" ns1:uuid=\"" . $vdsUuid . "\" ns1:name=\"" . $vdsName . "\" ns1:fileRef=\"" . $vdsFileRef . "\" ns1:id=\"" . $vdsMoRef . "\" />\n";
	$xml .= "  </ns1:DistributedSwitchSection>\n";
	$xml .= "  <ns1:VlanSection>\n";
	$xml .= $vlanSection;
	$xml .= $vlanTrunkSection;
	$xml .= $pvlanSection;
	$xml .= "  </ns1:VlanSection>\n";
	$xml .= "  <ns1:DistributedPortGroupSection>\n";
	$xml .= $dvpgSection;
	$xml .= "  </ns1:DistributedPortGroupSection>\n";

	$xml .= <<XML_END;
</ns1:Envelope>
XML_END

	# create data.xml file
	open(VDS_XML,">" . $fileName);
	print VDS_XML $xml;
	close(VDS_XML);

	if(defined($schema)) {
		print "Validating XML against " . $schema . " ...\n";
		my $doc = XML::LibXML->new->parse_file($fileName);
		my $xmlschema = XML::LibXML::Schema->new(location => $schema);
		eval { $xmlschema->validate( $doc ); };
		if($@) {
			print "Error: XML validation failed " . $@ . "\n";
			Util::disconnect();
			exit 1;
		}
	}
}

sub sectionNode {
	my ($arg1,$arg2,$arg3,$arg4,$arg5,$arg6,$arg7,$arg8,$arg9) = @_;

	return "    <ns1:DistributedPortGroup ns1:vlanRef=\"" . $arg1 . "\" ns1:allocation=\"" . $arg2 . "\" ns1:binding=\"" . $arg3 . "\" ns1:type=\"" . $arg4 . "\" ns1:fileRef=\"" . $arg5 . "\" ns1:configVersion=\"" . $arg6 . "\" ns1:name=\"" . $arg7 . "\" ns1:id=\"" . $arg8 . "\" />\n";
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

sub giveMeDate {
	my ($format) = @_;

        my %dttime = ();
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

        ### begin_: initialize DateTime number formats
        $dttime{year }  = sprintf "%04d",($year + 1900);  ## four digits to specify the year
        $dttime{mon  }  = sprintf "%02d",($mon + 1);      ## zeropad months
        $dttime{mday }  = sprintf "%02d",$mday;           ## zeropad day of the month
        $dttime{wday }  = sprintf "%02d",$wday + 1;       ## zeropad day of week; sunday = 1;
        $dttime{yday }  = sprintf "%02d",$yday;           ## zeropad nth day of the year
        $dttime{hour }  = sprintf "%02d",$hour;           ## zeropad hour
        $dttime{min  }  = sprintf "%02d",$min;            ## zeropad minutes
        $dttime{sec  }  = sprintf "%02d",$sec;            ## zeropad seconds
        $dttime{isdst}  = $isdst;

	if($format eq "zula") {
		return "$dttime{year}-$dttime{mon}-$dttime{mday}T$dttime{hour}:$dttime{min}:$dttime{sec}Z";
	} else {
		return "$dttime{year}-$dttime{mon}-$dttime{mday}_$dttime{hour}-$dttime{min}-$dttime{sec}";
	}
}
