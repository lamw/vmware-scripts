#!/usr/bin/perl
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2014/06/how-to-efficiently-transfer-files-to-datastore-in-vcenter-using-the-vsphere-api.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use URI::URL;
use URI::Escape;

my %opts = (
  sourcefile => {
    type => "=s",
    help => "Path to file to upload",
    required => 1,
  },
  destfile => {
    type => "=s",
    help => "Destination file",
    required => 1,
  },
  datastore => {
    type => "=s",
    help => "Name of vSphere Datastore to upload file to",
    required => 1,
	},
  datacenter => { 
    type => "=s",
    help => "Name of vSphere Datacenter",
    required => 1,
  },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $sourcefile = Opts::get_option('sourcefile');
my $destfile = Opts::get_option('destfile');
my $datastore = Opts::get_option('datastore');
my $datacenter = Opts::get_option('datacenter');

# retrieve vCenter/ESXi Web Service URL
my $service = Vim::get_vim_service();
my $service_url = URI::URL->new($service->{vim_soap}->{url});
my $user_agent = $service->{vim_soap}->{user_agent};

# build HTTP request URL
my $request = build_url($service_url,$sourcefile,$destfile,$datacenter,$datastore);

# upload content
&do_http_put_file($user_agent, $request, $sourcefile);

Util::disconnect();

sub build_url {
   my ($service_url, $source_file,$destination_file,$datacenter,$datastore) = @_;

   print "Generating upload request URL ...\n";
   #strip /sdk/webService
   $service_url =~ s/\/sdk\/webService//g;
   #build URL string
   my $url_string = $service_url . "/folder/" . $destination_file . "?dcPath=" . $datacenter . "&dsName=" . $datastore;

   utf8::downgrade($url_string);
   my $url = URI::URL->new($url_string);
   my $request = HTTP::Request->new("PUT", $url);

   print "Upload URL is: " . $url_string . "\n";
   return $request;
}

sub do_http_put_file {
   my ($user_agent, $request, $file_name) = @_;

   print "Uploading file " . $file_name . " ...\n";
   print `date` . "\n";
   $request->header('Content-Type', 'application/octet-stream');
   $request->header('Content-Length', -s $file_name);

   open(CONTENT, '< :raw', $file_name);
   sub content_source {
      my $buffer;
      my $num_read = read(CONTENT, $buffer, 102400);
      if ($num_read == 0) {
         return "";
      } else {
         return $buffer;
      }
   }
   $request->content(\&content_source);
   my $response = $user_agent->request($request);

   close(CONTENT);
   print `date` . "\n";
   return $response;
}
