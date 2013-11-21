#!/usr/bin/perl -w
# Copyright (c) 2009-2010 William Lam All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author or contributors may not be used to endorse or
#    promote products derived from this software without specific prior
#    written permission.
# 4. Consent from original author prior to redistribution

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# William Lam 
# 06/15/09
# http://communities.vmware.com/docs/DOC-10807
# http://engineering.ucsb.edu/~duonglt/vmware
######################################################

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

#retrieve all DC's since that is the highest level object containing hosts/datastores
my $datacenter_views = Vim::find_entity_views(view_type => 'Datacenter');

if($datacenter_views) {
	my ($ds,$percFree,$vms,$numOfVMs,$dsFree,$dsCap,$dsType);
	format Infos =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<
$ds,             $percFree,           $numOfVMs,	$dsType
-----------------------------------------------------------------------------------------------------
.

	$~ = 'Infos';

	($ds,$percFree,$numOfVMs,$dsType) = ('Datastore','% Free','# of VMs','Datastore Type');
	write;

	# loop de loop
	foreach(@$datacenter_views) {
		my $datastores = Vim::get_views(mo_ref_array => $_->datastore);
		foreach(sort {$a->summary->name cmp $b->summary->name} @$datastores) {
			$ds = $_->summary->name;
			$dsType = $_->summary->type;
                	$dsFree = &restrict_num_decimal_digits(($_->summary->freeSpace/1024/1000),2);
	                $dsCap = &restrict_num_decimal_digits($_->summary->capacity/1024/1000,2);
        	        $percFree = &restrict_num_decimal_digits(( 100 * $dsFree / $dsCap),2); 

			$vms = Vim::get_views(mo_ref_array => $_->vm, properties => ['name']);
			$numOfVMs = scalar(@$vms);
			write;
		}
	}
	print "\n";
}
Util::disconnect();

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
