#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2014/03/exploring-vsan-apis-part-4-vsan-disk-mappings.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'cluster' => {
      type => "=s",
      help => "Name of vSphere VSAN Cluster",
      required => 1,
   },
);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option("operation");
my $cluster = Opts::get_option("cluster");

my $cluster_view = Vim::find_entity_view(view_type => 'ComputeResource', filter => { 'name' => $cluster});
unless($cluster_view) {
       	Util::disconnect();
       	print "Error: Unable to find vSphere Cluster " . $cluster . "\n";
       	exit 1;
}

my $host_views = Vim::get_views(mo_ref_array => $cluster_view->host, properties => ['name','configManager.vsanSystem']);
my $cnt = 1;
foreach my $host_view (@$host_views) {
	&getVsanDiskInfo($host_view,$cnt);
	$cnt++;
}

Util::disconnect();

sub getVsanDiskInfo {
	my ($host,$n) = @_;

	my $vsanSys = Vim::get_view(mo_ref => $host->{'configManager.vsanSystem'});
	my $vsanDiskMappings = $vsanSys->config->storageInfo->diskMapping;

	if($vsanSys->config->enabled) {
		#print "Host: " . $host->name . "\n";
		print "Host: ESXi-" . $n . "\n";
		print "---------------------------\n";

		my $cnt = 1;	
		foreach my $diskMapping(@$vsanDiskMappings) {
			my $ssd = $diskMapping->ssd;
			my $hdds = $diskMapping->nonSsd;
			my $capacity = &getCapacity($ssd->capacity->block,$ssd->capacity->blockSize);
			print "DiskGroup " . $cnt . "\n";
			print "\tSSD: " . $ssd->devicePath . $capacity . "\n";
			foreach my $hdd(@$hdds) {
				my $capacity = &getCapacity($hdd->capacity->block,$hdd->capacity->blockSize);
				print "\tHDD: " . $hdd->devicePath . $capacity . "\n";
			}
			$cnt++;
		}
		print "\n";
	}
}

sub getCapacity {
	my ($block,$blockSize) = @_;

	return ' (' . &prettyPrintData(int($block * $blockSize / (1024*1024)),'M') . ')';
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
	elsif($type eq 'K') {
		$bytes = $bytes * (1024);
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
