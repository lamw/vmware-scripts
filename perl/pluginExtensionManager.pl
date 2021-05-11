#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2010/07/how-to-unregister-vcenter.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   operation => {
      type => "=s",
      help => "[list|remove]",
      required => 1,
   },
   key => {
      type => "=s",
      help => "Plugin key to remove, use 'list' to query key",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $key = Opts::get_option('key');
my $operation = Opts::get_option('operation');

Opts::parse();
Opts::validate();
Util::connect();

my $content = Vim::get_service_content();
my $extMgr = Vim::get_view(mo_ref => $content->extensionManager);
my $extList = $extMgr->extensionList;

if( Opts::get_option('operation') eq 'list') {
	foreach(@$extList) {
		print "\n------------------------------------------------------\n";
		print "Label: " . $_->description->label . "\n" if defined($_->description->label);
        	print "Summary: " . $_->description->summary . "\n" if defined($_->description->summary);
		print "Version: " . $_->version . "\n" if defined($_->version);
		print "Company: " . $_->company . "\n" if defined($_->company);
		print "Type: " . $_->type . "\n" if defined($_->type);
		print "Key: " . $_->key . "\n" if defined($_->key);
		my $server = $_->server;
		if( scalar($server) ) {
			print "Server info: \n";
			foreach(@$server) {
				my $email = $_->adminEmail;
				my $emailString;
				foreach(@$email) {
					$emailString .= $_ . " - ";
				}
				print "\tAdmin Email: " . $emailString . "\n" if defined($emailString);
				print "\tCompany: " . $_->company . "\n" if defined($_->company);
				print "\tDescription: " . "\n" if defined($_->description->label);
				print "\tType: " . $_->type . "\n" if defined($_->type);
				print "\tUrl: " . $_->url . "\n" if defined($_->url);
				print "\n";
			}
		}
	}
	print "\n";
} else {
	unless($key) {
		Util::disconnect();
		die "Please provide \"key\" when using 'remove' operation!\n";
	}
	print "Removing plugin key: \"" . $key . "\"\n";
	$extMgr->UnregisterExtension(extensionKey => $key);
}

Util::disconnect();
