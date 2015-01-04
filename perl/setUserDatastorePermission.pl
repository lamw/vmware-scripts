#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10866

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   datastore => {
      type => "=s",
      help => "Name of Datastore",
      required => 1,
   },
   rolename => {
      type => "=s",
      help => "Name of the role to apply to user",
      required => 1,
   },
   user =>{
      type => "=s",
      help => "Valid user name to apply permisison to",
      required => 1,
   },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $datastore = Opts::get_option('datastore');
my $rolename = Opts::get_option('rolename');
my $user = Opts::get_option('user');

my $datacenter_views = Vim::find_entity_views(view_type => 'Datacenter'); 
my $content = Vim::get_service_content();
my $authMgr = Vim::get_view(mo_ref => $content->authorizationManager);

my $roleid;

$roleid = &findRoleId($rolename,$authMgr);

unless($roleid) {
	Util::disconnect();
	die "Unable to locate role name \"$rolename\"!\n";
}

foreach(@$datacenter_views) {
	my $datastore_views = Vim::get_views( mo_ref_array => $_->datastore ); 

	foreach(@$datastore_views) {
		if( ($_->summary->name eq $datastore) && ($_->summary->accessible) ) {
			my $permissions = Permission->new(group => 'false', principal => $user, propagate => 'true', roleId => $roleid); 
			eval {
				print "Applying role: \"$rolename\" to user: \"$user\" on datastore: \"$datastore\"\n";
				$authMgr->SetEntityPermissions(entity => $_, permission => [$permissions]);
			};
			if($@) { print "Error: " . $@ . "\n"; }
		}
	}
}	

Util::disconnect();

sub findRoleId {
	my ($roleName,$authManager) = @_;
	print "Searching for rolename: " . $roleName . "... \n";

	my $roleList = $authMgr->roleList;
	foreach(@$roleList) {
		if($roleName eq $_->name) {
        		return $_->roleId;
		}
	}
}
