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
# 12/01/09
# http://communities.vmware.com/docs/DOC-11449
# http://engineering.ucsb.edu/~duonglt/vmware
###################################################

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
