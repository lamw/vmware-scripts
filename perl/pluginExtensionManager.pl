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
# 10/03/2009
# http://communities.vmware.com/docs/DOC-10847
# http://engineering.ucsb.edu/~duonglt/vmware/

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
