#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10173

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   device => {
      type => "=s",
      help => "Name of disk device (e.g. /dev/cciss/c0d0 or /dev/sda)",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
my $storageSystem = Vim::get_view(mo_ref => $host_view->configManager->storageSystem);

my $diskPartitions = $storageSystem->RetrieveDiskPartitionInfo(devicePath => [Opts::get_option('device')]);

foreach(@$diskPartitions) {
	my $partitions = $_->spec->partition;

	foreach (sort {$a->partition cmp $b->partition} @$partitions) {
		print "partition: ", $_->partition,"\n";
		print "type: ", $_->type,"\n";
		print "startSector: ", $_->startSector,"\n";
		print "endSector: ", $_->endSector,"\n";
		my $logical = ($_->logical ? "YES" : "NO");
		print "isLogical: ", $logical, "\n";
		print "size: ", prettyPrintData(( ($_->endSector - $_->startSector)*512),'B'),"\n";
		print "\n";		
	}
	print "Total size: ", prettyPrintData(($_->spec->totalSectors * 512),'B'),"\n\n";
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

