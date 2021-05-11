#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10788

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;
use VMware::VIExt;

my %opts = (
   datastore => {
      type => "=s",
      help => "Name of ESX(i) datastore",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $datastore = Opts::get_option('datastore');

my $host_view = Vim::find_entity_view(view_type => 'HostSystem');

unless($host_view) {
	Util::disconnect();
        die "Unable to connect to ESX(i)!";
}

my $datastore_views = Vim::get_views(mo_ref_array => $host_view->datastore);

my ($path,$owner,$size,$type);

format = 
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<
$path,				$owner,			    			$size,			$type				
.

print "Name\t\t\t\t\tOwner\t\t\t\t\tSize\t\t\tType\n";

foreach(@$datastore_views) {
	if($datastore eq $_->info->name) {
		my $browser = Vim::get_view (mo_ref => $_->browser);
		my $ds_path = "[" . $_->info->name . "]";
		my $file_query = FileQueryFlags->new(fileOwner => 1, fileSize => 1,fileType => 1,modification => 1);
		my $searchSpec = HostDatastoreBrowserSearchSpec->new(details => $file_query);
		my $search_res = $browser->SearchDatastoreSubFolders(datastorePath => $ds_path,searchSpec => $searchSpec);
		foreach my $result (@$search_res) {
			my $files = $result->file;
			foreach my $file (@$files) {
				$path = $file->path;
				$owner = $file->owner;
				$size = $file->fileSize;
				$size = &prettyPrintData($size,'B');
				$type = ref($file);
				write;
			}
		}
	}
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
