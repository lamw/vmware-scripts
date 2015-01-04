#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10777

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   format => {
      type => "=s",
      help => "Whether or not to format the output or leave output in bytes [0|1]",
      required => 0,
      default => 0,
   },
);

Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my ($vmname,$dsProvisioned,$dsUsed,$format,$perSaved);

my $change_format = Opts::get_option('format');
if($change_format eq '0') {
	$format = "DONT_FORMAT";
} else {
	$format = "FORMAT";
}

my $vm_view = Vim::find_entity_views(view_type => 'VirtualMachine');

format output =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<@<<<<<<<<<
$vmname,	$dsProvisioned,		$dsUsed,	$perSaved  
-------------------------------------------------------------------------------------------
.

$~ = 'output';
($vmname,$dsProvisioned,$dsUsed,$perSaved) = ('VM Name','Provisioned','Used','% Saved');
write;

foreach( sort {$a->summary->config->name cmp $b->summary->config->name}  @$vm_view) {
	$vmname = $_->summary->config->name;
	my $storageUsage = $_->storage->perDatastoreUsage;
	$dsUsed = 0;
	$dsProvisioned = 0;
	foreach(@$storageUsage) {
		$dsUsed += $_->committed;
		$dsProvisioned += ($_->committed + $_->uncommitted);
	}
	$perSaved = &restrict_num_decimal_digits((100 - (($dsUsed / $dsProvisioned)*100)),2) . ' %';
	$dsUsed = &prettyPrintData($dsUsed,$format);
	$dsProvisioned = &prettyPrintData($dsProvisioned,$format);
	write;
}

Util::disconnect();

#http://www.bryantmcgill.com/Shazam_Perl_Module/Subroutines/utils_convert_bytes_to_optimal_unit.html
sub prettyPrintData{
	my($bytes,$type) = @_;

  	return '' if ($bytes eq '' || $type eq '');
	return 0 if ($bytes <= 0);

  	my($size);

	if($type eq 'DONT_FORMAT') {
		$size = $bytes;
	} elsif($type eq 'FORMAT') {
		$size = $bytes . ' Bytes' if ($bytes < 1024);
                $size = sprintf("%.2f", ($bytes/1024)) . ' KB' if ($bytes >= 1024 && $bytes < 1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
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
