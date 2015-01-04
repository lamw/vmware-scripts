#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/08/automating-search-for-lopsided.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

print "Querying for lopsided boot banks ...\n\n";
my $host_views = Vim::find_entity_views(view_type => 'HostSystem');

foreach my $host(@$host_views) {
	if($host->summary->config->product->productLineId eq "embeddedEsx") {
		my $diagMgr = Vim::get_view(mo_ref => $host->configManager->diagnosticSystem);
		my $storageMgr = Vim::get_view(mo_ref => $host->configManager->storageSystem);
		my $scsiLuns = $storageMgr->storageDeviceInfo->scsiLun;
		my ($deviceName,$bootbankPar1,$bootbankPar2);

		if($diagMgr->activePartition) {
			my $activePartition = $diagMgr->activePartition->id->diskName;
			foreach my $lun(@$scsiLuns) {
				if($lun->canonicalName eq $activePartition) {
					$deviceName = $lun->deviceName;
					last;
				}
			}
			my $diskPartitions = $storageMgr->RetrieveDiskPartitionInfo(devicePath => $deviceName);

			foreach(@$diskPartitions) {
				my $partitions = $_->spec->partition;
				$bootbankPar1 = @$partitions[4];
				$bootbankPar2 = @$partitions[5];

				my $bootbank1Size = ($bootbankPar1->endSector - $bootbankPar1->startSector)*512;
				my $bootbank2Size = ($bootbankPar2->endSector - $bootbankPar2->startSector)*512;

				if($bootbank1Size ne $bootbank2Size) {
					print $host->name . "\t" . "Bootbank1: " . prettyPrintData($bootbank1Size,'B') . "\t" . "Bootbank2: " . prettyPrintData($bootbank2Size,'B') . "\n";
				}
			}
		}
	}
}

Util::disconnect();

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

