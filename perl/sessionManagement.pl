#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/12/identifying-idle-vcenter-sessions.html

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
