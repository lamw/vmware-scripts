#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-11449

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   privileges  => {
      type => "=s",
      help => "List of privledges for the the role to be created",
      required => 1,
   },
   rolename => {
      type => "=s",
      help => "Name of the role to apply to user",
      required => 1,
   },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $priv  = Opts::get_option('privileges');
my $rolename = Opts::get_option('rolename');

my @privileges = split(' ',$priv);

my $host_view = Vim::find_entity_view(view_type => 'HostSystem'); 
my $content = Vim::get_service_content();
my $authMgr = Vim::get_view(mo_ref => $content->authorizationManager);

#my @roleprivIds = qw(Datastore.Browse Global.ManageCustomFields System.Anonymous System.Read System.View);
#my @roleprivIds = ('Datastore.Browse','Global.ManageCustomFields');

eval {
	print "Creating new role: \"$rolename\" with the following privileges:\n";
	foreach(@privileges) {
        	print $_ . "\n";
	}
	print "\n";
	$authMgr->AddAuthorizationRole(name => $rolename, privIds => \@privileges);
	print "Successfully created new role!\n";
};
if($@) { print "Error: " . $@ . "\n"; }

Util::disconnect();
