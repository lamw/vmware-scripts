#!/usr/bin/perl -w
# Copyright (c) 2009-2011 William Lam All rights reserved.

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
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use HTTP::Date;

my %opts = (
        'operation' => {
        type => "=s",
        help => "Operation [list|disconnect]",
        required => 1,
        },
	'sessionkey' => {
        type => "=s",
        help => "Session key to disconnect",
        required => 0,
        },
);
# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option ('operation');
my $sessionkey = Opts::get_option ('sessionkey');

my $sessionMgr = Vim::get_view(mo_ref => Vim::get_service_content()->sessionManager);
my $sessionList = eval {$sessionMgr->sessionList || []};
my $currentSessionkey = $sessionMgr->currentSession->key;

if($operation eq "list") {
	foreach my $session (@$sessionList) {
		if($session->key eq $currentSessionkey) {
			print "Username           : " . $session->userName . " (CURRENT SESSION)\n";
		} else {
			print "Username           : " . $session->userName . "\n";
		}
		print "Fullname           : " . $session->fullName . "\n";
		print "Login Time         : " . time2str(str2time($session->loginTime)) . "\n";
		print "Last Active Time   : " . time2str(str2time($session->lastActiveTime)) . "\n";
		print "vCenter Ext Session: " . ($session->extensionSession ? "true"  : "false") . "\n"; 
		print "Sessionkey         : " . $session->key . "\n\n";
	}
} elsif($operation eq "disconnect") {
	print "Disconnecting sessionkey: " . $sessionkey . " ...\n";
	eval {
		$sessionMgr->TerminateSession(sessionId => [$sessionkey]);
	};
	if($@) {
		print "Error: " . $@ . "\n";
	}
} else {
	print "Invalid operation!\n";
}


Util::disconnect();
