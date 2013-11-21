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

###################################################
# William Lam
# 12/04/09
# http://communities.vmware.com/docs/DOC-11610
# http://engineering.ucsb.edu/~duonglt/vmware
###################################################

use strict;
use warnings;
use Term::ANSIColor;
use VMware::VIExt;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   datacenter => {
      type => "=s",
      help => "Datacenter to search for COS VMDK(s)",
      required => 0,
   },
   cluster => {
      type => "=s",
      help => "Cluster to search for COS VMDK(s)",
      required => 0,
   },
   datastore => {
      type => "=s",
      help => "Datastore(s) to search for COS VMDK(s) [e.g. "ds1,ds2,ds3"]",
      required => 0,
      default => undef,
   },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my ($content,$main_cos_log_dir,$hostType,$fm,$vim,$host_view,$datastores,$datacenter,$cluster,$datastore,$searchSpecificDatastores,$dcname);
my ($dc_view,$dc_views,$cluster_view);
my %uniqueds = ();
$content = Vim::get_service_content();
$hostType = $content->about->apiType;
$fm = VIExt::get_file_manager();
$vim = Vim->get_vim();

$datacenter = Opts::get_option('datacenter');
$cluster = Opts::get_option('cluster');
$datastore = Opts::get_option('datastore');
$searchSpecificDatastores = "false";

my @datastore_search;
if($datastore) {
	@datastore_search = split(',',$datastore);
	if(@datastore_search) {
        	$searchSpecificDatastores = "yes";
	}
}

$main_cos_log_dir = "cos_logs";

if(! -d $main_cos_log_dir) {
        mkdir($main_cos_log_dir, 0755)|| print $!;
}

if($hostType eq 'VirtualCenter') {
	if($datacenter) {
                $dc_view = Vim::find_entity_view(view_type => 'Datacenter', filter => {'name' => $datacenter});
                unless($dc_view) {
                        Util::disconnect();
                        die "Unable to locate Datacenter: \"$datacenter\"!\n";
                }
		$dcname = $dc_view->name;
                $datastores = Vim::get_views(mo_ref_array => $dc_view->datastore);
		&findCOSVMDKS($datastores,$dcname);
        } elsif($cluster) {
                $cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => {'name' => $cluster});
                unless($cluster_view) {
                        Util::disconnect();
                        die "Unable to locate Cluster: \"$cluster\"!\n";
                }
                $datastores = Vim::get_views(mo_ref_array => $cluster_view->datastore);
		&findCOSVMDKS($datastores,'cluster--input');
        } else {
		$dc_views = Vim::find_entity_views(view_type => 'Datacenter');
		foreach my $dc_view(@$dc_views) {
			$datastores = Vim::get_views(mo_ref_array => $dc_view->datastore);
			$dcname = $dc_view->name;
			&findCOSVMDKS($datastores,$dcname);
		}
	}
} else {
        $host_view = Vim::find_entity_view(view_type => 'HostSystem');
	$datastores = Vim::get_views(mo_ref_array => $host_view->datastore);
	&findCOSVMDKS($datastores,'local--input');
}

if( -d $main_cos_log_dir) {
        rmdir($main_cos_log_dir)|| print $!;
}


Util::disconnect();

sub findCOSVMDKS {
	my ($datastores,$datacenter) = @_;
        foreach( sort {$a->name cmp $b->name} @$datastores) {
        	if($_->summary->accessible && $_->summary->type eq 'VMFS') {
			my $datastoreName = $_->name;
			my $good = &verifyDatastore($_);
                        if($good eq 'yes') {
				if($datacenter eq 'cluster--input') {
					my $dc = &getParentDC($_);
					$datacenter = $dc->name;
				}
                        	#search ds
        	                my $ds_path = "[" . $datastoreName . "]";
				my $file_query = FileQueryFlags->new(fileOwner => 0, fileSize => 1,fileType => 1,modification => 0);
	                        my $searchSpec = HostDatastoreBrowserSearchSpec->new(details => $file_query, matchPattern => ["*-cos.vmdk","*vmkernel-late.log"]);
        	                my $browser = Vim::get_view(mo_ref => $_->browser);
                	        my $search_res = $browser->SearchDatastoreSubFolders(datastorePath => $ds_path,searchSpec => $searchSpec);

	                       	if($search_res) {
        	               		foreach my $result (@$search_res) {
                	               		my $folderPath = $result->folderPath;
                        	       		my $files = $result->file;
                                	       	if($files) {
                                       			foreach my $file (@$files) {
								my ($filename,$filepath,$filesize);
								$filename = $file->path;
								$filepath = $folderPath . $filename;
								$filesize = $file->fileSize;
								if($filename =~ m/.log/ && $datacenter ne 'local--input') {
									my $cos_log_path = "$main_cos_log_dir/$filename.$$";
									&do_get($filepath,$cos_log_path,$datacenter);
									my $hostname = `grep -ia 'HostName' $cos_log_path`;
									$hostname =~ s/.*"HostName" = "//;
									$hostname =~ s/".*//;
									if($hostname) {
										print color("yellow") . $hostname . color("reset") .  "\n";
									} else {
										print color("yellow") . "No hostname found" . color("reset") .  "\n\n";
									}
									unlink $cos_log_path;
									$uniqueds{$datastoreName} = "yes";
								} elsif($filename =~ m/.vmdk/ || $datacenter ne 'local--input') {
									print &prettyPrintData($filesize,'B') . "\t" . $filepath . "\n";
								}
                                	        	}
                                		}
                        		}
                		}
			}
		}
         }
}

sub do_get {
   my ($remote_source, $local_target,$datacenter) = @_;
   my ($mode, $dc, $ds, $filepath) = VIExt::parse_remote_path($remote_source);
   if (defined $local_target and -d $local_target) {
      my $local_filename = $filepath;
      $local_filename =~ s@^.*/([^/]*)$@$1@;
      $local_target .= "/" . $local_filename;
   }
   my $resp = VIExt::http_get_file($mode, $filepath, $ds, $datacenter, $local_target);
   # bug 301206, 266936
   if (!defined $resp and $resp->is_success) {
      VIExt::fail("Error: File can not be downloaded to $local_target.");
   }
}

sub getParentDC {
	my ($entity) = @_;
	my $entity_view = Vim::get_view(mo_ref => $entity->parent);

	if($entity_view->isa('Datacenter')) {
		return $entity_view;
	}
	&getParentDC($entity_view);
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

sub verifyDatastore {
        my ($ds) = @_;
        my $dsname = $ds->name;
        my $ret = "yes";
        if($searchSpecificDatastores eq "yes") {
                if (! grep( /^$dsname/,@datastore_search ) ) {
                        $ret = "no";
                }
        }
        return $ret;
}
