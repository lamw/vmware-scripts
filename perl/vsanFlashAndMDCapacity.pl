#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2014/04/vsan-flashmd-capacity-reporting.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use JSON qw(decode_json);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::parse();
Opts::validate();
Util::connect();

my $clusters = Vim::find_entity_views(view_type => 'ComputeResource', properties => ['name','host','configurationEx']);
my ($totalSsdCapacity,$totalSsdCapacityReserved,$totalSsdCapacityUsed,$totalMdCapacity,$totalMdCapacityReserved,$totalMdCapacityUsed) = (0,0,0,0,0,0);

foreach my $cluster (@$clusters) {
    if($cluster->{'configurationEx'}->vsanConfigInfo->enabled) {
        my $hosts = Vim::get_views(mo_ref_array => $cluster->{'host'}, properties => ['name','configManager.vsanSystem','configManager.vsanInternalSystem','runtime.connectionState']);
        foreach my $host(@$hosts) {
            next if($host->{'runtime.connectionState'}->val ne 'connected');
            # VSAN Managers
           	my $vsanSys = Vim::get_view(mo_ref => $host->{'configManager.vsanSystem'});
            my $vsanIntSys = Vim::get_view(mo_ref => $host->{'configManager.vsanInternalSystem'});
            &get_vsan_disk_capacity($vsanSys,$vsanIntSys,$host);
        }
        my $totalSsdCapacityReservedPercent = ($totalSsdCapacityReserved / $totalSsdCapacity * 100);
        my $totalSsdCapacityUsedPercent = ($totalSsdCapacityUsed / $totalSsdCapacity * 100);
        my $totalMdCapacityReservedPercent = ($totalMdCapacityReserved / $totalMdCapacity * 100);
        my $totalMdCapacityUsedPercent = ($totalMdCapacityUsed / $totalMdCapacity * 100);

        print "VSAN Cluster: " . $cluster->{'name'} . "\n";
        print "\tTotal SSD Capacity: " . &prettyPrintData($totalSsdCapacity,'B') . "\n";
        print "\tTotal SSD Capacity Reserved: " . &prettyPrintData($totalSsdCapacityReserved,'B') . " (" . &restrict_num_decimal_digits($totalSsdCapacityReservedPercent,2) . "%)\n";
        print "\tTotal SSD Capacity Used: " . &prettyPrintData($totalSsdCapacityUsed,'B') . " (" . &restrict_num_decimal_digits($totalSsdCapacityUsedPercent,2) . "%)\n\n";
        print "\tTotal MD Capacity: " . &prettyPrintData($totalMdCapacity,'B') . "\n";
        print "\tTotal MD Capacity Reserved: " . &prettyPrintData($totalMdCapacityReserved,'B') . " (" . &restrict_num_decimal_digits($totalMdCapacityReservedPercent,2) . "%)\n";
        print "\tTotal MD Capacity Used: " . &prettyPrintData($totalMdCapacityUsed,'B') . " (" . &restrict_num_decimal_digits($totalMdCapacityUsedPercent,2) . "%)\n\n";

        # zero out the global vars
        ($totalSsdCapacity,$totalSsdCapacityReserved,$totalSsdCapacityUsed,$totalMdCapacity,$totalMdCapacityReserved,$totalMdCapacityUsed) = (0,0,0,0,0,0);
    }
}

Util::disconnect();

sub get_vsan_disk_capacity {
	my ($vsanSys,$vsanIntSys,$host) = @_;

	my $results = $vsanIntSys->QueryPhysicalVsanDisks(props => ["owner","uuid","isSsd","capacity","capacityUsed","capacityReserved"]);
	my $vsanStatus = $vsanSys->QueryHostStatus();

	# Decode JSON
	my %decoded = %{decode_json($results)};

	my $component_count = 0;
	foreach my $key (sort keys %decoded) {
		# ensure component is owned by ESXi host
		if($decoded{$key}{'owner'} eq $vsanStatus->nodeUuid) {
			if($decoded{$key}{'isSsd'}) {
				$totalSsdCapacity += $decoded{$key}{'capacity'};
				$totalSsdCapacityReserved += $decoded{$key}{'capacityReserved'}; 
				$totalSsdCapacityUsed += $decoded{$key}{'capacityUsed'};
			} else {
				$totalMdCapacity += $decoded{$key}{'capacity'};
				$totalMdCapacityReserved += $decoded{$key}{'capacityReserved'};
				$totalMdCapacityUsed += $decoded{$key}{'capacityUsed'};
			}
		}
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

# restrict the number of digits after the decimal point
#http://guymal.com/mycode/perl_restrict_digits.shtml
sub restrict_num_decimal_digits {
        my $num=shift;#the number to work on
        my $digs_to_cut=shift;# the number of digits after

        if ($num=~/\d+\.(\d){$digs_to_cut,}/) {
                $num=sprintf("%.".($digs_to_cut-1)."f", $num);
        }
        return $num;
}
