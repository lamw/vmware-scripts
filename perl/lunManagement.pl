#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use Term::ANSIColor;

my %opts = (
        'operation' => {
        type => "=s",
        help => "Operation [list|unmount|mount|detach|attach]",
        required => 1,
        },
        'datastore' => {
        type => "=s",
        help => "Name of Datastore to perform on",
        required => 0,
        },
);
Opts::add_options(%opts);

Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $datastore = Opts::get_option('datastore');
my $datastores = "";

if(Vim::get_service_content()->about->version ne "5.0.0") {
	print color("red") . "\nThis script is only supported on vSphere 5.0 or greater\n\n" . color("reset");
	Util::disconnect();
	exit 1;
}

if($operation eq "list") {
	&getDatastores($datastore);

	foreach my $ds (@$datastores) {
		if($ds->info->isa("VmfsDatastoreInfo")) {
			my $hostViewDSDiskName = $ds->info->vmfs->extent->[0]->diskName;
			print color("cyan") . "Datastore: " . $ds->name . " LUN: " . $hostViewDSDiskName . "\n" . color("reset");
			if($ds->host) {
				my $attachedHosts = $ds->host;

				foreach my $host (@$attachedHosts) {
					my $hostView = Vim::get_view(mo_ref => $host->key, properties => ['name','configManager.storageSystem']);
					my $hostViewName = $hostView->{'name'};
					my $hostViewDSState = (defined($host->mountInfo->mounted) ? ($host->mountInfo->mounted ?  color("green") . "MOUNTED  " . color("reset") : color("red") . "UNMOUNTED" .  color("reset")) : "MOUNT_STATE_UNKNOWN");
					my $storageSys = Vim::get_view(mo_ref => $hostView->{'configManager.storageSystem'});
					my $devices = eval{$storageSys->storageDeviceInfo->scsiLun || []};
					foreach my $device (@$devices) {
						if($device->canonicalName eq $hostViewDSDiskName) {
							my $hostViewDSAttachState = "";
							if($device->operationalState->[0] eq "ok") {
								$hostViewDSAttachState = color("green") . "ATTACHED" . color("reset");
							} elsif($device->operationalState->[0] eq "off") {
								$hostViewDSAttachState = color("red") . "DETACHED" . color("reset");
							} else {
								$hostViewDSAttachState = color("yellow") . $device->operationalState->[0] . color("reset");
							}
							print "\t" .  $hostViewName . "\t" . $hostViewDSState . " " . $hostViewDSAttachState . "\n";
							last;
						}
					}
				}
			}
		}
	}
} elsif($operation eq "unmount") {
	unless($datastore) {
		print color("red") . "\n\"umount\" operation requires \"datastore\" option!\n\n" . color("reset");
		Util::disconnect();
		exit 1;
	}
	&getDatastores($datastore);

	my $response = &promptUser("Are you sure you want to unmount \"$datastore\" hosts? [yes|no]");
	if($response =~ m/yes/) {
		foreach my $ds (@$datastores) {
			my $hostViewDSDiskName = $ds->info->vmfs->extent->[0]->diskName;
			if($ds->host) {
                	        my $attachedHosts = $ds->host;

                        	foreach my $host (@$attachedHosts) {
                                	my $hostView = Vim::get_view(mo_ref => $host->key, properties => ['name','configManager.storageSystem']);
					my $storageSys = Vim::get_view(mo_ref => $hostView->{'configManager.storageSystem'});
					print "Unmounting VMFS Datastore \"$datastore\" from Host \"" . $hostView->{'name'}  . "\" ...\n";
					eval {
						$storageSys->UnmountVmfsVolume(vmfsUuid => $ds->info->vmfs->uuid);
					};
					if($@) {
						print color("red") . "\nERROR: Unable to unmount VMFS datastore " . $@ . "\n" . color("reset");
						Util::disconnect();
						exit 1;
					} else {
						print color("green") . "\tSuccessfully unmounted VMFS datastore!\n" . color("reset");
					}
					print "\n";
                	        }
                	}
		}
	} else {
		print "Exiting ...\n";
	}
} elsif($operation eq "mount") {
	unless($datastore) {
                print color("red") . "\n\"mount\" operation requires \"datastore\" option!\n\n" . color("reset");
                Util::disconnect();
                exit 1;
        }
        &getDatastores($datastore);

        my $response = &promptUser("Are you sure you want to mount \"$datastore\" hosts? [yes|no]");
        if($response =~ m/yes/) {
                foreach my $ds (@$datastores) {
                        my $hostViewDSDiskName = $ds->info->vmfs->extent->[0]->diskName;
                        if($ds->host) {
                                my $attachedHosts = $ds->host;

                                foreach my $host (@$attachedHosts) {
                                        my $hostView = Vim::get_view(mo_ref => $host->key, properties => ['name','configManager.storageSystem']);
                                        my $storageSys = Vim::get_view(mo_ref => $hostView->{'configManager.storageSystem'});
                                        print "Mounting VMFS Datastore \"$datastore\" to Host \"" . $hostView->{'name'}  . "\" ...\n";
                                        eval {
                                                $storageSys->MountVmfsVolume(vmfsUuid => $ds->info->vmfs->uuid);
                                        };
                                        if($@) {
                                                print color("red") . "\nERROR: Unable to mount VMFS datastore " . $@ . "\n" . color("reset");
                                                Util::disconnect();
                                                exit 1;
                                        } else {
                                                print color("green") . "\tSuccessfully mounted VMFS datastore!\n" . color("reset");
                                        }
                                        print "\n";
                                }
                        }
                }
        } else {
                print "Exiting ...\n";
        }
} elsif($operation eq "detach") {
	unless($datastore) {
                print color("red") . "\n\"detach\" operation requires \"datastore\" option!\n\n" . color("reset");
                Util::disconnect();
                exit 1;
        }
	&getDatastores($datastore);

        my $response = &promptUser("Are you sure you want to detach \"$datastore\" from all hosts? [yes|no]");
        if($response =~ m/yes/) {
                foreach my $ds (@$datastores) {
                        my $hostViewDSDiskName = $ds->info->vmfs->extent->[0]->diskName;
                        if($ds->host) {
                                my $attachedHosts = $ds->host;

                                foreach my $host (@$attachedHosts) {
                                        my $hostView = Vim::get_view(mo_ref => $host->key, properties => ['name','configManager.storageSystem']);
                                        my $storageSys = Vim::get_view(mo_ref => $hostView->{'configManager.storageSystem'});
					my $devices = eval{$storageSys->storageDeviceInfo->scsiLun || []};
                                        foreach my $device (@$devices) {
                                                if($device->canonicalName eq $hostViewDSDiskName) {
							my $lunUuid = $device->uuid;
							print "Detaching LUN \"$lunUuid\" from Host \"" . $hostView->{'name'}  . "\" ...\n";
	                	                        eval {
        	                	                        $storageSys->DetachScsiLun(lunUuid => $lunUuid);
                	                	        };
                        	                	if($@) {
                                	                	print color("red") . "\nERROR: Unable to detach LUN " . $@ . "\n" . color("reset");
          	        	                      	        Util::disconnect();
                	                                	exit 1;
	                        	                } else {
        	                                	        print color("green") . "\tSuccessfully detached LUN!\n" . color("reset");
                	                	        }
							last;
						}
					}
                                        print "\n";
                                }
                        }
                }
        } else {
                print "Exiting ...\n";
        }
} elsif($operation eq "attach") {
	unless($datastore) {
                print color("red") . "\n\"attach\" operation requires \"datastore\" option!\n\n" . color("reset");
                Util::disconnect();
                exit 1;
        }
        &getDatastores($datastore);

        my $response = &promptUser("Are you sure you want to attach \"$datastore\" from all hosts? [yes|no]");
        if($response =~ m/yes/) {
                foreach my $ds (@$datastores) {
                        my $hostViewDSDiskName = $ds->info->vmfs->extent->[0]->diskName;
                        if($ds->host) {
                                my $attachedHosts = $ds->host;

                                foreach my $host (@$attachedHosts) {
                                        my $hostView = Vim::get_view(mo_ref => $host->key, properties => ['name','configManager.storageSystem']);
                                        my $storageSys = Vim::get_view(mo_ref => $hostView->{'configManager.storageSystem'});
                                        my $devices = eval{$storageSys->storageDeviceInfo->scsiLun || []};
                                        foreach my $device (@$devices) {
                                                if($device->canonicalName eq $hostViewDSDiskName) {
                                                        my $lunUuid = $device->uuid;
                                                        print "Attaching LUN \"$lunUuid\" from Host \"" . $hostView->{'name'}  . "\" ...\n";
                                                        eval {
                                                                $storageSys->AttachScsiLun(lunUuid => $lunUuid);
                                                        };
                                                        if($@) {
                                                                print color("red") . "\nERROR: Unable to attach LUN " . $@ . "\n" . color("reset");
                                                                Util::disconnect();
                                                                exit 1;
                                                        } else {
                                                                print color("green") . "\tSuccessfully attached LUN!\n" . color("reset");
                                                        }
							last;
                                                }
                                        }
                                        print "\n";
                                }
                        }
                }
        } else {
                print "Exiting ...\n";
        }
}

Util::disconnect();

sub getDatastores {
	my ($datastore) = @_;

	if($datastore) {
                $datastores = Vim::find_entity_views(view_type => 'Datastore', filter => {'name' => $datastore});
        } else {
                $datastores = Vim::find_entity_views(view_type => 'Datastore');
        }

	if(scalar(@$datastores) eq 0) {
		print color("red") . "\nUnable to locate any datastores!\n\n" . color("reset");
		Util::disconnect();
		exit 1;
	}
}

# prompt user taken from http://devdaily.com/perl/edu/articles/pl010005#comment-159
sub promptUser {
        my($prompt) = @_;
        print color("black","on_yellow") . "\t$prompt:" . color("reset") . " ";
        chomp(my $input = <STDIN>);
        return $input;
}
