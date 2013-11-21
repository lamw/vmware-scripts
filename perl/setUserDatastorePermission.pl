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
# 10/07/09
# http://communities.vmware.com/docs/DOC-10866
# http://engineering.ucsb.edu/~duonglt/vmware
###################################################

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
