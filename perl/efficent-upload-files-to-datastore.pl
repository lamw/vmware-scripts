#!/usr/bin/perl
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2014/06/how-to-efficiently-transfer-files-to-datastore-in-vcenter-using-the-vsphere-api.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use URI::URL;
use URI::Escape;
use Socket;

my %opts = (
  sourcefile => {
    type => "=s",
    help => "Path to source file to upload",
    required => 1,
  },
  destfile => {
    type => "=s",
    help => "path to destination file on datastore",
    required => 1,
  },
  datastore => {
    type => "=s",
    help => "Name of vSphere Datastore to upload file to",
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

# retrieve vCenter/ESXi Web Service details
my $service = Vim::get_vim_service();
my $service_url = URI::URL->new($service->{vim_soap}->{url});
my $user_agent = $service->{vim_soap}->{user_agent};

# randomly select ESXi host with access to datastore
my $selectedESXi = &get_upload_host($datastore);

# build HTTP request URL
my $request = build_url($selectedESXi,$sourcefile,$destfile,$datastore);

# request service ticket
my $ticket = &acquire_service_ticket($request->url);

# upload content
&do_http_put_file($user_agent, $request, $sourcefile, $ticket);

Util::disconnect();

sub get_upload_host {
  my ($datastore) = @_;

  my $datastore_view = Vim::find_entity_view(view_type => 'Datastore', filter => {'name' => $datastore}, properties => ['name','host']);

  my $hostMounts = $datastore_view->host;
  foreach my $hostMount (@$hostMounts) {
    if($hostMount->mountInfo->accessible && $hostMount->mountInfo->mounted) {
      my $host_view = Vim::get_view(mo_ref => $hostMount->key, properties => ['name']);
      return $host_view->{'name'};
    }
  }
}

sub build_url {
   my ($host, $source_file,$destination_file,$datastore) = @_;

   print "Generating upload request URL ...\n";

	 #my $ip;
	 #my $packed_ip = gethostbyname($host);
	 #if(defined($packed_ip)) {
	 #   $ip = inet_ntoa($packed_ip);
	 # } else {
	 #   print "Unable to resolve " . $host . "\n";
	 #   Util::disconnect();
	 #   exit 1;
	 # }

   #build URL string
   my $url_string = "https://" . $host . "/folder/" . $destination_file . "?dcPath=ha-datacenter" . "&dsName=" . $datastore;

   utf8::downgrade($url_string);
   my $url = URI::URL->new($url_string);
   my $request = HTTP::Request->new("PUT", $url);

   print "Upload URL is: " . $url_string . "\n";
   return $request;
}

sub acquire_service_ticket {
  my ($url) = @_;

  my $sessionMgr = Vim::get_view(mo_ref => Vim::get_service_content()->sessionManager);
  my $spec = SessionManagerHttpServiceRequestSpec->new(method => 'httpPut', url => $url);

  my $ticket;
  eval {
    $ticket= $sessionMgr->AcquireGenericServiceTicket(spec => $spec);
  };
  if($@) {
    print "Error: " . $@ . "\n";
  }

  return $ticket; 
}

sub do_http_put_file {
   my ($user_agent, $request, $file_name, $ticket) = @_;

   print "Uploading file " . $file_name . " ...\n";
   print `date` . "\n";
   $request->header('Content-Type', 'application/octet-stream');
   $request->header('Content-Length', -s $file_name);
   $request->header('Cookie', 'vmware_cgi_ticket=' . $ticket->id);

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
